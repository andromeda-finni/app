import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_storage.dart';

/// Override at build/run time: `flutter run --dart-define=API_BASE_URL=http://192.168.1.23:3000`
/// (needed for a physical device, which can't reach the dev machine via
/// 10.0.2.2 — that address only exists inside the Android emulator's NAT).
const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

String _defaultBaseUrl() {
  if (kIsWeb) return 'http://127.0.0.1:3000';
  // 10.0.2.2 is the Android emulator's alias for the host machine's
  // localhost — plain 127.0.0.1 from inside the emulator means the
  // emulator itself, not the dev machine running the backend.
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://127.0.0.1:3000';
}

/// Thrown for both transport failures (statusCode 0) and non-2xx API
/// responses, so callers can branch on one type for "show an error state".
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, [this.details]);

  final int statusCode;
  final String code;
  final Object? details;

  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => 'ApiException($statusCode, $code)';
}

/// Hosts allowed to be reached over plain HTTP: the loopback addresses and the
/// Android emulator's alias for the host machine. This traffic never leaves
/// the developer's machine.
bool _isLocalDevHost(String host) =>
    host == 'localhost' ||
    host == '127.0.0.1' ||
    host == '::1' ||
    host == '10.0.2.2';

/// Refuses to let a release binary talk to a remote host over plain HTTP.
///
/// Android's `usesCleartextTraffic` / Network Security Config does not cover
/// this. Flutter's dart:io HttpClient opens its own sockets and never consults
/// `NetworkSecurityPolicy` — confirmed on a release APK with targetSdk 36 and
/// no config present, which reached an http:// backend without complaint. The
/// platform will not stop a cleartext production build, so this check is the
/// only thing that does.
void _assertTransportIsSafe(String baseUrl) {
  if (kDebugMode) return;
  final uri = Uri.parse(baseUrl);
  if (uri.scheme == 'https' || _isLocalDevHost(uri.host)) return;
  throw ArgumentError.value(
    baseUrl,
    'baseUrl',
    'Refusing to send API traffic to a remote host over plain HTTP in a '
        'release build — the bearer token would be readable on the wire. '
        'Use https, or point API_BASE_URL at a local dev address.',
  );
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    AuthStorage? authStorage,
    String? baseUrl,
  }) : _http = httpClient ?? http.Client(),
       _authStorage = authStorage ?? AuthStorage(),
       baseUrl =
           baseUrl ??
           (_baseUrlOverride.isNotEmpty
               ? _baseUrlOverride
               : _defaultBaseUrl()) {
    _assertTransportIsSafe(this.baseUrl);
  }

  final http.Client _http;
  final AuthStorage _authStorage;
  final String baseUrl;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async => _asObject(await _send('POST', path, body: body, auth: auth));

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async => _asObject(await _send('PUT', path, body: body, auth: auth));

  /// For a route that must answer with a JSON object.
  Future<Map<String, dynamic>> get(String path, {bool auth = true}) async =>
      _asObject(await _send('GET', path, auth: auth));

  /// For a route where `null` is a valid resource state, such as "no active
  /// period". Keeping this separate from [get] preserves non-nullable types at
  /// every ordinary call site.
  Future<Map<String, dynamic>?> getOptional(
    String path, {
    bool auth = true,
  }) async {
    final decoded = await _send('GET', path, auth: auth);
    return decoded == null ? null : _asObject(decoded);
  }

  /// For a route that answers with a JSON array.
  Future<List<dynamic>> getList(String path, {bool auth = true}) async {
    final decoded = await _send('GET', path, auth: auth);
    if (decoded is! List) {
      throw ApiException(0, 'unexpected_response_shape');
    }
    return decoded;
  }

  Map<String, dynamic> _asObject(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(0, 'unexpected_response_shape');
    }
    return decoded;
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required bool auth,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _authStorage.readToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    // A route with a Fastify body schema validates against `{}` fine but
    // rejects a genuinely missing body (undefined fails `type: object`
    // even when every property is optional) — always send a real JSON
    // object, even an empty one, for any POST/PUT so a no-argument call
    // like child registration doesn't 400 before reaching the handler.
    final effectiveBody = (method == 'POST' || method == 'PUT')
        ? (body ?? const {})
        : body;

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (effectiveBody != null) request.body = jsonEncode(effectiveBody);
      response = await (() async {
        final streamed = await _http.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Covers timeouts, DNS/connection refused, and any other transport
      // failure — surfaced uniformly so the UI can show one retry state.
      throw ApiException(0, 'network_error');
    }

    Object? decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      // A proxy error page or a truncated response is still an API failure,
      // not an uncaught parsing exception that can tear down the current UI.
      throw ApiException(response.statusCode, 'invalid_json_response');
    }

    if (response.statusCode >= 400) {
      // An error body is always an object; anything else means the failure
      // came from somewhere that doesn't speak this API's error shape.
      final error = decoded is Map<String, dynamic> ? decoded : const {};
      throw ApiException(
        response.statusCode,
        error['error'] as String? ?? 'unknown_error',
        error['details'],
      );
    }
    return decoded;
  }
}
