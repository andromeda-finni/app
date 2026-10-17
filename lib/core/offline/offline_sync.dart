import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api_client.dart';
import 'offline_economy.dart';
import 'offline_storage.dart';

/// Sends one request to the real server; supplied by [ApiClient].
typedef OfflineNetworkSend = Future<Object?> Function(
  String method,
  String path,
  Map<String, dynamic>? body,
);

/// Offline-first layer of the child app.
///
/// * Every successful GET is remembered on the device, so the app opens and
///   shows the last known state without a connection.
/// * Core-loop actions done offline are previewed locally by
///   [OfflineEconomy] and queued.
/// * When the server is reachable again the queue is replayed in order with
///   the original idempotency keys, then fresh server state replaces the
///   preview. The server stays authoritative: an action it refuses is
///   dropped and the child is told what did not go through.
///
/// Data is kept per signed-in child (scoped by a hash of the token), so a
/// queue can never be replayed with another account's session.
class OfflineSync extends ChangeNotifier {
  OfflineSync({
    OfflineStorage? storage,
    this.retryInterval = const Duration(seconds: 15),
    this.autoRetry = true,
    DateTime Function()? clock,
  }) : _storage = storage ?? DeviceOfflineStorage(),
       _clock = clock ?? DateTime.now {
    _economy = OfflineEconomy(nextId: _nextId, clock: _clock);
  }

  static const _storageKeyPrefix = 'offline.v1.';
  static const _currentScopeKey = 'offline.v1.scope';

  /// After a failed attempt, requests skip the network for this long instead
  /// of each waiting for its own timeout.
  static const _offlineGrace = Duration(seconds: 5);
  static const _maxServerErrorAttempts = 3;
  static final _offlineIdPattern = RegExp('$kOfflineIdPrefix[a-z]+-[0-9]+');

  /// Refusals meaning "this already happened" — e.g. a mini-game re-sending
  /// an answer it had already saved. Nothing was lost, so nothing is shown.
  static const _alreadyDoneCodes = {
    'assignment_not_in_progress',
    'quest_already_completed',
  };

  final OfflineStorage _storage;
  final DateTime Function() _clock;
  final Duration retryInterval;
  final bool autoRetry;
  late final OfflineEconomy _economy;

  String? _scope;
  Map<String, Object?> _cache = {};
  List<Map<String, dynamic>> _queue = [];
  Map<String, String> _ids = {};
  int _sequence = 0;

  bool _offline = false;
  DateTime? _lastFailure;
  int _revision = 0;
  final List<String> _notices = [];
  Future<bool>? _flushing;
  Timer? _retryTimer;

  /// Set by [ApiClient]: checks the server and replays the queue.
  Future<void> Function()? probe;

  bool get isOffline => _offline;
  int get pendingCount => _queue.length;
  bool get hasPending => _queue.isNotEmpty;

  /// Grows each time queued actions reach the server; screens reload on it.
  int get syncRevision => _revision;

  /// Child-facing messages about actions the server refused after a sync.
  List<String> takeNotices() {
    final notices = List<String>.of(_notices);
    _notices.clear();
    return notices;
  }

  bool get shouldSkipNetwork {
    final failure = _lastFailure;
    return _offline &&
        failure != null &&
        _clock().difference(failure) < _offlineGrace;
  }

  /// Loads the data of the child signed in with [token].
  Future<void> useToken(String token) async {
    final scope = _hash(token);
    if (scope == _scope) return;
    final previous = await _storage.read(_currentScopeKey);
    if (previous != null && previous != scope) {
      // Another child signed in on this device: the old session's cache and
      // queue can no longer be sent with a valid token.
      await _storage.delete('$_storageKeyPrefix$previous');
    }
    _scope = scope;
    _cache = {};
    _queue = [];
    _ids = {};
    _sequence = 0;
    final raw = await _storage.read('$_storageKeyPrefix$scope');
    if (raw != null) {
      try {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        _cache = Map<String, Object?>.from(saved['cache'] as Map? ?? {});
        _queue = [
          for (final item in saved['queue'] as List? ?? const [])
            Map<String, dynamic>.from(item as Map),
        ];
        _ids = Map<String, String>.from(saved['ids'] as Map? ?? {});
        _sequence = (saved['sequence'] as num?)?.toInt() ?? 0;
      } on Object {
        // A damaged cache is worth less than a working app: start clean.
      }
    }
    await _storage.write(_currentScopeKey, scope);
    _scheduleRetry();
  }

  Object? cached(String path) => _cache[path];

  Future<void> remember(String path, Object? value) async {
    _cache[path] = value;
    await _persist();
  }

  void markOnline() {
    _lastFailure = null;
    if (!_offline) return;
    _offline = false;
    _scheduleRetry();
    notifyListeners();
  }

  void markOffline() {
    _lastFailure = _clock();
    if (_offline) return;
    _offline = true;
    _scheduleRetry();
    notifyListeners();
  }

  /// Serves a request the network could not: a remembered GET, or a
  /// core-loop action applied locally and queued. Rethrows [networkError]
  /// for anything that really needs the server.
  Future<Object?> fallback(
    String method,
    String path,
    Map<String, dynamic>? body,
    ApiException networkError,
  ) async {
    if (method == 'GET') {
      final economy = _cache['/economy/state'];
      if (path == '/park-project' && _cache['/park-project'] is Map) {
        return OfflineEconomy.refreshPark(
          Map<String, dynamic>.from(_cache['/park-project'] as Map),
          economy is Map ? Map<String, dynamic>.from(economy) : null,
        );
      }
      if (_cache.containsKey(path)) return _cache[path];
      if (path == '/pet') {
        final state = _cache['/economy/state'];
        if (state is Map && state['pet'] is Map) return state['pet'];
      }
      throw networkError;
    }
    if (!OfflineEconomy.supports(method, path)) throw networkError;

    final state = _cache['/economy/state'];
    final park = _cache['/park-project'];
    final outcome = _economy.apply(
      method,
      path,
      body,
      state is Map ? Map<String, dynamic>.from(state) : null,
      cachedPark: park is Map ? Map<String, dynamic>.from(park) : null,
    );
    if (outcome.park != null) _cache['/park-project'] = outcome.park;
    final nextState = outcome.state;
    if (nextState != null) {
      _cache['/economy/state'] = nextState;
      if (_cache['/pet'] is Map && nextState['pet'] is Map) {
        _cache['/pet'] = {...(_cache['/pet'] as Map), ...nextState['pet']};
      }
    }
    if (outcome.queue) {
      _queue.add({
        'method': method,
        'path': path,
        'body': ?body,
        'createdId': ?outcome.createdId,
        'label': outcome.label,
      });
    }
    await _persist();
    notifyListeners();
    if (outcome.saveOnly) throw ApiException(0, kSavedOfflineCode);
    return outcome.response;
  }

  /// Replays the queue in order. Returns false when the server is still
  /// unavailable; the remaining actions stay queued.
  ///
  /// [serverHealthy] tells an outage (database down: every request fails
  /// with 5xx) from one request the server cannot process. Only the latter
  /// counts towards dropping the action.
  Future<bool> flush(
    OfflineNetworkSend send, {
    Future<bool> Function()? serverHealthy,
  }) {
    return _flushing ??= _flush(
      send,
      serverHealthy,
    ).whenComplete(() => _flushing = null);
  }

  Future<bool> _flush(
    OfflineNetworkSend send,
    Future<bool> Function()? serverHealthy,
  ) async {
    var delivered = false;
    while (_queue.isNotEmpty) {
      final item = _queue.first;
      final method = item['method'] as String;
      final path = _resolve(item['path'] as String);
      final body = item['body'] == null
          ? null
          : jsonDecode(_resolve(jsonEncode(item['body'])))
                as Map<String, dynamic>;

      // The action depends on one the server refused (e.g. a day that was
      // never opened): it cannot be sent meaningfully.
      if (_offlineIdPattern.hasMatch(path) ||
          (body != null && _offlineIdPattern.hasMatch(jsonEncode(body)))) {
        _queue.removeAt(0);
        await _persist();
        continue;
      }

      try {
        final result = await send(method, path, body);
        _recordCreatedId(item, result);
        _queue.removeAt(0);
        delivered = true;
        await _persist();
      } on ApiException catch (error) {
        if (error.isNetworkError) {
          markOffline();
          await _persist();
          if (delivered) _delivered();
          return false;
        }
        if (error.statusCode >= 500) {
          final healthy = serverHealthy == null || await serverHealthy();
          if (!healthy) {
            markOffline();
            await _persist();
            if (delivered) _delivered();
            return false;
          }
          final attempts = ((item['attempts'] as num?)?.toInt() ?? 0) + 1;
          if (attempts < _maxServerErrorAttempts) {
            item['attempts'] = attempts;
            await _persist();
            if (delivered) _delivered();
            return false;
          }
        }
        if (path == '/periods' && error.code == 'period_already_active') {
          // Sent before, the answer was lost: adopt the day the server has.
          await _adoptActiveDay(item, send);
        } else if (!_alreadyDoneCodes.contains(error.code)) {
          _notices.add(
            '${item['label'] ?? 'Действие'}: сервер не принял то, '
            'что было сделано без сети.',
          );
        }
        _queue.removeAt(0);
        await _persist();
      }
    }
    markOnline();
    if (delivered || _notices.isNotEmpty) _delivered();
    return true;
  }

  void _delivered() {
    _revision++;
    notifyListeners();
  }

  void _recordCreatedId(Map<String, dynamic> item, Object? result) {
    final created = item['createdId'];
    if (created is! String || result is! Map) return;
    final real =
        result['periodId'] ??
        result['assignmentId'] ??
        result['inventoryItemId'] ??
        result['policyId'] ??
        result['id'];
    if (real is String) _ids[created] = real;
  }

  Future<void> _adoptActiveDay(
    Map<String, dynamic> item,
    OfflineNetworkSend send,
  ) async {
    final created = item['createdId'];
    if (created is! String) return;
    try {
      final active = await send('GET', '/periods/active', null);
      if (active is Map && active['id'] is String) {
        _ids[created] = active['id'] as String;
      }
    } on ApiException {
      // Unknown: dependent actions are dropped by the unresolved-id check.
    }
  }

  String _resolve(String text) => text.replaceAllMapped(
    _offlineIdPattern,
    (match) => _ids[match.group(0)] ?? match.group(0)!,
  );

  String _nextId(String kind) => '$kOfflineIdPrefix$kind-${++_sequence}';

  void _scheduleRetry() {
    if (!autoRetry) return;
    final needed = _offline || _queue.isNotEmpty;
    if (!needed) {
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    _retryTimer ??= Timer.periodic(retryInterval, (_) {
      final check = probe;
      if (check != null) unawaited(check());
    });
  }

  Future<void> _persist() async {
    final scope = _scope;
    if (scope == null) return;
    await _storage.write(
      '$_storageKeyPrefix$scope',
      jsonEncode({
        'cache': _cache,
        'queue': _queue,
        'ids': _ids,
        'sequence': _sequence,
      }),
    );
    _scheduleRetry();
  }

  /// FNV-1a: a stable, non-reversible key for the token. Dart's own
  /// String.hashCode is not guaranteed to be stable across runs.
  static String _hash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(value)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
