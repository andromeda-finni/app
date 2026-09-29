import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/onboarding/difficulty_choice_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_data.dart';
import 'package:andromeda_app/onboarding/onboarding_flow.dart';
import 'package:andromeda_app/onboarding/onboarding_collar_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_step1_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_step2_screen.dart';
import 'package:andromeda_app/onboarding/widgets/back_circle_button.dart';
import 'package:andromeda_app/onboarding/widgets/story_button.dart';

import 'support/fake_auth_storage.dart';

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _allocateAllCoins(WidgetTester tester) async {
  final addCandy = find.bySemanticsLabel(
    'Добавить монету в категорию «Конфеты»',
  );
  await tester.ensureVisible(addCandy);
  for (var i = 0; i < kTutorialBudgetTotal; i++) {
    await tester.tap(addCandy);
    await tester.pump();
  }
}

void main() {
  testWidgets('finishing step 4 persists every step before completing', (
    tester,
  ) async {
    final authStorage = FakeAuthStorage(initialToken: 'tok');
    var finished = false;
    final progressSteps = <int>[];
    final petWrites = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path == '/onboarding/progress') {
        progressSteps.add(
          (jsonDecode(request.body) as Map<String, dynamic>)['completedStep']
              as int,
        );
      }
      if (request.url.path == '/pet') {
        petWrites.add(jsonDecode(request.body) as Map<String, dynamic>);
      }
      return http.Response(
        jsonEncode({'ok': true}),
        request.method == 'POST' ? 201 : 200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          onFinished: (_) => finished = true,
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
    await _tapVisible(tester, find.text('серый'));
    await _tapVisible(tester, find.text('Далее'));

    expect(find.byType(OnboardingCollarScreen), findsOneWidget);
    await _tapVisible(tester, find.text('синий'));
    await _tapVisible(tester, find.text('Далее'));

    expect(find.textContaining('Иногда Мурзик тратил'), findsOneWidget);
    expect(find.textContaining('Грошик'), findsNothing);
    await _tapVisible(tester, find.text('Далее'));

    expect(find.textContaining('Мурзик получил 10 монет'), findsOneWidget);
    await _allocateAllCoins(tester);
    await _tapVisible(tester, find.text('Готово'));

    expect(find.textContaining('еперь Мурзик знает'), findsOneWidget);
    await _tapVisible(tester, find.text('Начать игру'));

    expect(finished, isTrue);
    expect(progressSteps, [2, 3, 4]);
    expect(petWrites.last['accessoryOptionId'], 'ACC_COLLAR_BLUE');
  });

  testWidgets('restores an interrupted flow at step 2 with the saved pet', (
    tester,
  ) async {
    final authStorage = FakeAuthStorage(initialToken: 'tok');
    var networkCalls = 0;
    final client = MockClient((request) async {
      networkCalls++;
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          onFinished: (_) {},
          initialStep: 2,
          initialData: OnboardingData(
            petName: 'Мурзик',
            furColorId: 'FUR_GRAY',
            collarColorId: 'ACC_COLLAR_GREEN',
          ),
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

    expect(find.byType(OnboardingStep2Screen), findsOneWidget);
    expect(find.textContaining('Иногда Мурзик тратил'), findsOneWidget);
    expect(find.textContaining('Грошик'), findsNothing);
    expect(networkCalls, 0);

    await _tapVisible(tester, find.byType(BackCircleButton));
    expect(find.byType(OnboardingCollarScreen), findsOneWidget);
    await _tapVisible(tester, find.byType(BackCircleButton));
    expect(find.byType(OnboardingStep1Screen), findsOneWidget);
    expect(find.text('Мурзик'), findsOneWidget);
  });

  testWidgets('resumes at collar choice when step 1 has no saved collar', (
    tester,
  ) async {
    final authStorage = FakeAuthStorage(initialToken: 'tok');
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          onFinished: (_) {},
          initialStep: 2,
          initialData: OnboardingData(
            petName: 'Мурзик',
            furColorId: 'FUR_GRAY',
          ),
          authStorage: authStorage,
          apiClient: ApiClient(
            httpClient: MockClient((_) async => http.Response('{}', 200)),
            authStorage: authStorage,
            baseUrl: 'http://test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingCollarScreen), findsOneWidget);
    expect(find.text('Выбери ошейник'), findsOneWidget);
  });

  testWidgets(
    'asks for difficulty before registration and persists the choice',
    (tester) async {
      Map<String, dynamic>? registrationBody;
      final client = MockClient((request) async {
        expect(request.url.path, '/auth/child/register');
        registrationBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'userId': 'u1', 'token': 'tok'}), 201);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingFlow(
            onFinished: (_) {},
            apiClient: ApiClient(httpClient: client, baseUrl: 'http://test'),
            authStorage: FakeAuthStorage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(DifficultyChoiceScreen), findsOneWidget);
      expect(find.byType(OnboardingStep1Screen), findsNothing);

      await tester.tap(find.text('Самостоятельно'));
      await tester.pump();
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingStep1Screen), findsOneWidget);
      expect(registrationBody, {'difficulty': 'ADVANCED'});
    },
  );

  testWidgets('difficulty choice fits a small phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: DifficultyChoiceScreen(
              selected: null,
              onSelected: (_) {},
              onContinue: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Как тебе удобнее играть?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
          onFinished: (_) {},
          apiClient: ApiClient(httpClient: client, baseUrl: 'http://test'),
          authStorage: FakeAuthStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DifficultyChoiceScreen), findsOneWidget);
    await tester.tap(find.text('С подсказками'));
    await tester.pump();
    await tester.tap(find.text('Продолжить'));
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
          onFinished: (_) {},
          apiClient: ApiClient(httpClient: client, baseUrl: 'http://test'),
          authStorage: FakeAuthStorage(initialToken: 'already-have-one'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingStep1Screen), findsOneWidget);
    expect(registerCalls, 0);
  });

  testWidgets(
    'going back updates the existing pet instead of creating another one',
    (tester) async {
      final requests = <http.Request>[];
      final authStorage = FakeAuthStorage(initialToken: 'tok');
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'id': 'pet-1', 'petNameStatus': 'APPROVED'}),
          200,
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingFlow(
            onFinished: (_) {},
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
      await _tapVisible(tester, find.text('серый'));
      await _tapVisible(tester, find.text('Далее'));

      await _tapVisible(tester, find.byType(BackCircleButton));
      await tester.enterText(find.byType(TextField), 'Рыжик');
      await _tapVisible(tester, find.text('рыжий'));
      await _tapVisible(tester, find.text('Далее'));

      expect(requests, hasLength(2));
      expect(requests.every((request) => request.method == 'PUT'), isTrue);
      expect(jsonDecode(requests.last.body), {
        'petName': 'Рыжик',
        'furOptionId': 'FUR_ORANGE',
        'accessoryOptionId': null,
      });
    },
  );
}
