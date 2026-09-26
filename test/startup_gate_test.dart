import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/home/main_shell.dart';
import 'package:andromeda_app/main.dart';
import 'package:andromeda_app/onboarding/onboarding_step1_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_step2_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_step3_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_step4_screen.dart';

import 'support/fake_auth_storage.dart';
import 'support/economy_fixture.dart';

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
        initialAudience: AppAudience.child,
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

  testWidgets('saved token + completed onboarding -> shows main shell', (
    tester,
  ) async {
    final authStorage = FakeAuthStorage(initialToken: 'tok');
    final client = MockClient((request) async {
      if (request.url.path == '/economy/state') {
        return _jsonResponse({
          'rules': testEconomyRules,
          'pet': {'pet_name': 'Рыжик'},
        }, 200);
      }
      expect(request.url.path, '/onboarding/status');
      return _jsonResponse({
        'currentStep': 4,
        'completed': true,
        'pet': {'petName': 'Рыжик', 'furOptionId': 'FUR_GRAY'},
      }, 200);
    });

    await tester.pumpWidget(
      GroshikApp(
        initialAudience: AppAudience.child,
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
    expect(find.text('Дом'), findsOneWidget);
    expect(find.text('Копилка'), findsOneWidget);

    await tester.tap(find.text('Копилка'));
    await tester.pumpAndSettle();

    expect(find.text('Моя цель'), findsOneWidget);
    expect(find.text('Сундук Морозко'), findsOneWidget);
  });

  for (final resumeCase in <({int step, Type screen})>[
    (step: 1, screen: OnboardingStep1Screen),
    (step: 3, screen: OnboardingStep3Screen),
    (step: 4, screen: OnboardingStep4Screen),
  ]) {
    testWidgets(
      'saved token resumes interrupted onboarding at step ${resumeCase.step}',
      (tester) async {
        final authStorage = FakeAuthStorage(initialToken: 'tok');
        var registerCalls = 0;
        final client = MockClient((request) async {
          if (request.url.path == '/auth/child/register') registerCalls++;
          return _jsonResponse({
            'currentStep': resumeCase.step,
            'completed': false,
            'pet': resumeCase.step == 1
                ? null
                : {'petName': 'Мурзик', 'furOptionId': 'FUR_GRAY'},
          }, 200);
        });

        await tester.pumpWidget(
          GroshikApp(
            initialAudience: AppAudience.child,
            authStorage: authStorage,
            apiClient: ApiClient(
              httpClient: client,
              authStorage: authStorage,
              baseUrl: 'http://test',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(resumeCase.screen), findsOneWidget);
        expect(registerCalls, 0);
      },
    );
  }

  testWidgets(
    'pet saved at step 1 -> resumes at step 2 without re-registering',
    (tester) async {
      final authStorage = FakeAuthStorage(initialToken: 'tok');
      var registerCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/onboarding/status') {
          return _jsonResponse({
            'currentStep': 2,
            'completed': false,
            'pet': {'petName': 'Мурзик', 'furOptionId': 'FUR_GRAY'},
          }, 200);
        }
        registerCalls++;
        return _jsonResponse({'userId': 'u1', 'token': 'tok'}, 201);
      });

      await tester.pumpWidget(
        GroshikApp(
          initialAudience: AppAudience.child,
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
      expect(find.byType(OnboardingStep2Screen), findsOneWidget);
      // The account already exists (we had a token) — onboarding must not
      // silently create a second, orphaned account on top of it.
      expect(registerCalls, 0);
    },
  );

  testWidgets(
    'saved token + onboarding status 401 -> drops token and re-registers',
    (tester) async {
      final authStorage = FakeAuthStorage(initialToken: 'revoked-token');
      final sentAuthHeaders = <String, String?>{};
      var registerCalls = 0;

      final client = MockClient((request) async {
        final auth = request.headers['Authorization'];
        if (request.url.path == '/onboarding/status' &&
            request.method == 'GET') {
          sentAuthHeaders['GET /onboarding/status'] = auth;
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
          initialAudience: AppAudience.child,
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
      expect(sentAuthHeaders['GET /onboarding/status'], 'Bearer revoked-token');
    },
  );

  testWidgets('transport failure -> retry-capable error state', (tester) async {
    final authStorage = FakeAuthStorage(initialToken: 'tok');
    var calls = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/economy/state') {
        return _jsonResponse({
          'rules': testEconomyRules,
          'pet': {'pet_name': 'Грошик'},
        }, 200);
      }
      calls++;
      if (calls == 1) return http.Response('', 500);
      return _jsonResponse({
        'currentStep': 4,
        'completed': true,
        'pet': {'petName': 'Грошик', 'furOptionId': 'FUR_GRAY'},
      }, 200);
    });

    await tester.pumpWidget(
      GroshikApp(
        initialAudience: AppAudience.child,
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
    expect(find.text('Дом'), findsOneWidget);
  });
}
