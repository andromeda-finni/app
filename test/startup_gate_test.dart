import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/home/main_shell.dart';
import 'package:andromeda_app/main.dart';
import 'package:andromeda_app/onboarding/onboarding_step1_screen.dart';

import 'support/fake_auth_storage.dart';

/// http.Response(String, int)'s default encoding is Latin1, which throws on
/// non-ASCII bytes like Cyrillic — always encode mock JSON bodies as UTF-8.
http.Response _jsonResponse(Object body, int statusCode) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets('no saved token -> shows onboarding', (tester) async {
    final authStorage = FakeAuthStorage();
    final client = MockClient((request) async {
      return _jsonResponse({'userId': 'u1', 'token': 'tok'}, 201);
    });

    await tester.pumpWidget(
      GroshikApp(
        authStorage: authStorage,
        apiClient: ApiClient(
          httpClient: client,
          authStorage: authStorage,
          baseUrl: 'http://test',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingStep1Screen), findsOneWidget);
  });

  testWidgets(
    'saved token + GET /pet 200 -> shows the home placeholder, not onboarding',
    (tester) async {
      final authStorage = FakeAuthStorage(initialToken: 'tok');
      final client = MockClient((request) async {
        expect(request.url.path, '/pet');
        return _jsonResponse({'id': 'p1', 'pet_name': 'Грошик'}, 200);
      });

      await tester.pumpWidget(
        GroshikApp(
          authStorage: authStorage,
          apiClient: ApiClient(
            httpClient: client,
            authStorage: authStorage,
            baseUrl: 'http://test',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingStep1Screen), findsNothing);
      expect(find.byType(MainShell), findsOneWidget);
    },
  );

  testWidgets(
    'saved token + GET /pet 404 -> resumes onboarding without re-registering',
    (tester) async {
      final authStorage = FakeAuthStorage(initialToken: 'tok');
      var registerCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/pet') {
          return _jsonResponse({'error': 'pet_not_created'}, 404);
        }
        registerCalls++;
        return _jsonResponse({'userId': 'u1', 'token': 'tok'}, 201);
      });

      await tester.pumpWidget(
        GroshikApp(
          authStorage: authStorage,
          apiClient: ApiClient(
            httpClient: client,
            authStorage: authStorage,
            baseUrl: 'http://test',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingStep1Screen), findsOneWidget);
      // The account already exists (we had a token) — onboarding must not
      // silently create a second, orphaned account on top of it.
      expect(registerCalls, 0);
    },
  );

  testWidgets(
    'saved token + GET /pet 401 -> drops the dead token and re-registers',
    (tester) async {
      final authStorage = FakeAuthStorage(initialToken: 'revoked-token');
      final sentAuthHeaders = <String, String?>{};
      var registerCalls = 0;

      final client = MockClient((request) async {
        final auth = request.headers['Authorization'];
        if (request.url.path == '/pet' && request.method == 'GET') {
          sentAuthHeaders['GET /pet'] = auth;
          return _jsonResponse({'error': 'unauthorized'}, 401);
        }
        if (request.url.path == '/auth/child/register') {
          registerCalls++;
          return _jsonResponse({'userId': 'u2', 'token': 'fresh-token'}, 201);
        }
        sentAuthHeaders[request.method] = auth;
        return _jsonResponse({'ok': true}, 200);
      });

      await tester.pumpWidget(
        GroshikApp(
          authStorage: authStorage,
          apiClient: ApiClient(
            httpClient: client,
            authStorage: authStorage,
            baseUrl: 'http://test',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingStep1Screen), findsOneWidget);
      // A revoked token must be discarded, not reused: without clearing it,
      // onboarding skips registration and keeps authenticating with the dead
      // token, so the child can never recover.
      expect(registerCalls, 1);
      expect(await authStorage.readToken(), 'fresh-token');
      expect(sentAuthHeaders['GET /pet'], 'Bearer revoked-token');
    },
  );

  testWidgets('transport failure -> retry-capable error state', (tester) async {
    final authStorage = FakeAuthStorage(initialToken: 'tok');
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) return http.Response('', 500);
      return _jsonResponse({'id': 'p1'}, 200);
    });

    await tester.pumpWidget(
      GroshikApp(
        authStorage: authStorage,
        apiClient: ApiClient(
          httpClient: client,
          authStorage: authStorage,
          baseUrl: 'http://test',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);
  });
}
