import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/onboarding/onboarding_flow.dart';
import 'package:andromeda_app/onboarding/onboarding_step1_screen.dart';
import 'package:andromeda_app/onboarding/widgets/story_button.dart';

import 'support/fake_auth_storage.dart';

void main() {
  testWidgets('finishing step 4 leaves onboarding instead of staying on it', (
    tester,
  ) async {
    final authStorage = FakeAuthStorage(initialToken: 'tok');
    var finished = false;
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'ok': true}),
        request.method == 'POST' ? 201 : 200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          onFinished: () => finished = true,
          authStorage: authStorage,
          apiClient: ApiClient(
            httpClient: client,
            authStorage: authStorage,
            baseUrl: 'http://test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Мурзик');
    await tester.tap(find.text('серый'));
    await tester.pump();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp('Убрать монету')).first);
    await tester.pump();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать игру'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
    // Steps 2-4 are pushed routes: if they are not popped, the home screen
    // is swapped in underneath them and the child never sees it.
    expect(find.text('Начать игру'), findsNothing);
  });

  testWidgets(
    'registers the child and shows step 1 once the network call succeeds',
    (tester) async {
      final client = MockClient((request) async {
        expect(request.url.path, '/auth/child/register');
        return http.Response(jsonEncode({'userId': 'u1', 'token': 'tok'}), 201);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingFlow(
            onFinished: () {},
            apiClient: ApiClient(httpClient: client, baseUrl: 'http://test'),
            authStorage: FakeAuthStorage(),
          ),
        ),
      );

      // Loading state first, then step 1 once registration resolves.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingStep1Screen), findsOneWidget);
    },
  );

  testWidgets('shows a retry-capable error state when registration fails', (
    tester,
  ) async {
    var attempts = 0;
    final client = MockClient((request) async {
      attempts++;
      if (attempts == 1) return http.Response('{"error":"network_error"}', 500);
      return http.Response(jsonEncode({'userId': 'u1', 'token': 'tok'}), 201);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          onFinished: () {},
          apiClient: ApiClient(httpClient: client, baseUrl: 'http://test'),
          authStorage: FakeAuthStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // First attempt failed: an error message and a retry button, not a
    // silently stuck spinner or a crash.
    expect(find.byType(OnboardingStep1Screen), findsNothing);
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.byType(StoryButton));
    await tester.pumpAndSettle();

    // Retry succeeds (2nd mocked response) and reaches step 1.
    expect(find.byType(OnboardingStep1Screen), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('reuses an existing saved token instead of registering again', (
    tester,
  ) async {
    var registerCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/auth/child/register') registerCalls++;
      return http.Response(jsonEncode({'userId': 'u1', 'token': 'tok'}), 201);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          onFinished: () {},
          apiClient: ApiClient(httpClient: client, baseUrl: 'http://test'),
          authStorage: FakeAuthStorage(initialToken: 'already-have-one'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingStep1Screen), findsOneWidget);
    expect(registerCalls, 0);
  });
}
