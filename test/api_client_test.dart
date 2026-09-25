import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';

void main() {
  test(
    'a bodyless POST still sends a valid JSON object, not an empty body',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final api = ApiClient(httpClient: client, baseUrl: 'http://test');
      await api.post('/auth/child/register', auth: false);

      // A Fastify route with a body schema (even one where every field is
      // optional) 400s on a truly missing body — `{}` passes, `''` doesn't.
      // Caught on a real device: registration silently failed with
      // "Body cannot be empty when content-type is set to 'application/json'".
      expect(captured.headers['content-type'], contains('application/json'));
      expect(captured.body, '{}');
    },
  );

  test('GET requests never carry a body', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    final api = ApiClient(httpClient: client, baseUrl: 'http://test');
    await api.get('/pet', auth: false);

    expect(captured.body, isEmpty);
  });

  test('optional GET preserves a null resource response', () async {
    final client = MockClient((_) async => http.Response('null', 200));

    final api = ApiClient(httpClient: client, baseUrl: 'http://test');

    expect(await api.getOptional('/periods/active', auth: false), isNull);
    await expectLater(
      api.get('/periods/active', auth: false),
      throwsA(isA<ApiException>()),
    );
  });

  test('PUT sends the replacement body with the expected method', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    final api = ApiClient(httpClient: client, baseUrl: 'http://test');
    await api.put(
      '/pet',
      auth: false,
      body: {'petName': 'Мурзик', 'furOptionId': 'FUR_GRAY'},
    );

    expect(captured.method, 'PUT');
    expect(jsonDecode(captured.body), {
      'petName': 'Мурзик',
      'furOptionId': 'FUR_GRAY',
    });
  });
}
