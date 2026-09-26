import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/economy/economy_action_ui.dart';
import 'package:andromeda_app/economy/economy_screen.dart';
import 'package:andromeda_app/economy/economy_actions.dart';
import 'package:andromeda_app/economy/economy_state.dart';
import 'package:andromeda_app/theme/app_theme.dart';

import 'support/fake_auth_storage.dart';
import 'support/economy_fixture.dart';

http.Response _jsonResponse(Object body, [int statusCode = 200]) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _economyState({int wallet = 30, int savings = 0}) => {
  'rules': testEconomyRules,
  'pet': {'pet_name': 'Грошик', 'energy_level': 100, 'joy_level': 100},
  'wallets': {'SPENDABLE': wallet, 'SAVINGS': savings, 'FROZEN': 0},
  'activeDay': {
    'id': 'day-1',
    'sequence_no': 1,
    'week': 1,
    'day_of_week': 1,
    'budget_plan_status': 'CONFIRMED',
    'available_amount': 30,
    'required_need_amount': 10,
    'need_amount': 10,
    'want_amount': 10,
    'savings_amount': 10,
  },
  'activeEvent': null,
  'activeGoal': {
    'id': 'goal-1',
    'target_item_id': 'boots',
    'name': 'Сапоги',
    'target_amount': 150,
    'status': 'ACTIVE',
  },
  'activeFrostChest': null,
  'shopItems': <Object>[],
  'artifacts': <Object>[],
  'inventory': <Object>[],
  'quests': <Object>[],
  'parentTasks': <Object>[],
  'recentTransactions': <Object>[],
  'recentDays': <Object>[],
};

void main() {
  testWidgets('confirmation is scrollable on a narrow phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'PTSerif',
    )..addFont(rootBundle.load('assets/fonts/PTSerif-Regular.ttf'))).load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEconomyConfirmation(
                context,
                EconomyActions.purchase(
                  EconomyState.fromJson(_economyState()),
                  const EconomyItem(
                    id: 'ball',
                    name: 'Мячик для Грошика',
                    price: 8,
                    kind: 'WANT',
                  ),
                ).confirmation,
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.widgetWithText(FilledButton, 'Купить').hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  Future<void> pumpEconomy(WidgetTester tester, MockClient client) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EconomyScreen(
          apiClient: ApiClient(
            httpClient: client,
            authStorage: FakeAuthStorage(initialToken: 'token'),
            baseUrl: 'http://test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first day requires confirmed goal before the income request', (
    tester,
  ) async {
    final calls = <String>[];
    final data = _economyState(wallet: 0)..['activeDay'] = null;
    data['activeGoal'] = null;
    data['artifacts'] = [
      {'id': 'boots', 'name': 'Сапоги', 'price': 150},
    ];
    await pumpEconomy(
      tester,
      MockClient((request) async {
        if (request.method == 'GET') return _jsonResponse(data);
        calls.add(request.url.path);
        if (request.url.path == '/goals') {
          data['activeGoal'] = _economyState()['activeGoal'];
        }
        return _jsonResponse({});
      }),
    );
    await tester.ensureVisible(find.text('Начать день'));
    await tester.tap(find.text('Начать день'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.text('На главный экран'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.text('Начать день'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Сапоги'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Цель нельзя сменить до получения артефакта.'),
      findsOneWidget,
    );
    expect(calls, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Выбрать'));
    await tester.pumpAndSettle();
    expect(calls, ['/goals', '/periods', '/pet-events/roll']);
  });

  for (final purchase in [true, false]) {
    testWidgets(
      '${purchase ? 'purchase' : 'withdrawal'} can be cancelled and requires explicit confirmation',
      (tester) async {
        var sent = 0;
        final data = _economyState(savings: 20);
        data['shopItems'] = [
          {'id': 'TOY_BALL', 'name': 'Мячик', 'kind': 'WANT', 'price': 8},
        ];
        await pumpEconomy(
          tester,
          MockClient((request) async {
            if (request.method == 'GET') return _jsonResponse(data);
            sent++;
            expect(
              request.url.path,
              purchase ? '/purchases' : '/savings/withdraw',
            );
            return _jsonResponse({});
          }),
        );
        final button = find.widgetWithText(
          purchase ? OutlinedButton : TextButton,
          purchase ? '8 монет' : 'Вернуть 5',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(sent, 0);
        expect(
          find.text(purchase ? 'Кошелёк: 30 → 22' : 'Копилка: 20 → 15'),
          findsOneWidget,
        );
        if (!purchase) {
          expect(find.text('Цель отдалится на 5 монет.'), findsOneWidget);
        }
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(sent, 0);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, purchase ? 'Купить' : 'Вернуть 5'),
        );
        await tester.pumpAndSettle();
        expect(sent, 1);
      },
    );
  }

  testWidgets(
    'redemption immediately opens the next dream selection and preserves overflow',
    (tester) async {
      final data = _economyState(savings: 155);
      data['artifacts'] = [
        {'id': 'shield', 'name': 'Щит', 'price': 130},
      ];
      await pumpEconomy(
        tester,
        MockClient((request) async {
          if (request.method == 'GET') return _jsonResponse(data);
          expect(request.url.path, '/goals/goal-1/redeem');
          data['activeGoal'] = null;
          data['wallets'] = {'SPENDABLE': 30, 'SAVINGS': 5, 'FROZEN': 0};
          return _jsonResponse({});
        }),
      );
      await tester.ensureVisible(find.text('Получить артефакт'));
      await tester.tap(find.text('Получить артефакт'));
      await tester.pumpAndSettle();
      expect(find.text('Копилка: 155 → 5'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Получить'));
      await tester.pumpAndSettle();
      expect(find.text('Выбери мечту'), findsOneWidget);
      expect(
        find.text('В Копилке уже 5 монет. Они сохранятся для новой цели.'),
        findsOneWidget,
      );
    },
  );

  test(
    'action guard blocks duplicate execution while waiting for confirmation',
    () async {
      var sent = 0;
      final actions = EconomyActions(
        ApiClient(
          baseUrl: 'http://test',
          authStorage: FakeAuthStorage(initialToken: 'token'),
          httpClient: MockClient((_) async {
            sent++;
            return _jsonResponse({});
          }),
        ),
      );
      final confirmation = Completer<bool>();
      final operation = EconomyActions.savings(
        EconomyState.fromJson(_economyState()),
        5,
        deposit: true,
      );
      final first = actions.execute(operation, (_) => confirmation.future);
      expect(await actions.execute(operation, (_) async => true), isFalse);
      expect(sent, 0);
      confirmation.complete(true);
      expect(await first, isTrue);
      expect(sent, 1);
    },
  );

  testWidgets('protected purchase is disabled with a useful hint', (
    tester,
  ) async {
    final data = _economyState(wallet: 12);
    data['shopItems'] = [
      {'id': 'TOY_BALL', 'name': 'Мячик', 'kind': 'WANT', 'price': 8},
    ];
    await pumpEconomy(
      tester,
      MockClient((request) async {
        expect(request.method, 'GET');
        return _jsonResponse(data);
      }),
    );
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '8 монет'),
    );
    expect(button.onPressed, isNull);
    expect(
      find.textContaining('10 монет нужны на обязательные траты.'),
      findsWidgets,
    );
  });

  testWidgets('server economy rules drive income and available actions', (
    tester,
  ) async {
    final data = _economyState();
    data['rules'] = {
      ...testEconomyRules,
      'dailyIncome': 41,
      'savingsTransferAmounts': [7],
      'frostMinimum': 12,
      'frostMaximum': 24,
      'frostStep': 12,
      'frostDays': 6,
      'frostBonusPercent': 17,
    };
    data['activeDay'] = null;
    await pumpEconomy(
      tester,
      MockClient((request) async => _jsonResponse(data)),
    );

    expect(
      find.text('Утром в Кошелёк поступят 41 монет. Затем составь план дня.'),
      findsOneWidget,
    );

    data['activeDay'] = _economyState()['activeDay'];
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpEconomy(
      tester,
      MockClient((request) async => _jsonResponse(data)),
    );
    await tester.scrollUntilVisible(find.text('Отложить 7'), 250);
    expect(find.text('Отложить 7'), findsOneWidget);
    expect(find.text('Отложить 5'), findsNothing);
    await tester.scrollUntilVisible(find.text('12 → 15'), 250);
    expect(find.textContaining('6 завершённых дней'), findsOneWidget);
    expect(find.text('12 → 15'), findsOneWidget);
    expect(find.text('24 → 29'), findsOneWidget);
  });

  testWidgets('invalid economy contract is a retryable error, not a crash', (
    tester,
  ) async {
    final data = _economyState()..remove('rules');
    await pumpEconomy(
      tester,
      MockClient((request) async => _jsonResponse(data)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(economyContractErrorMessage), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets(
    'deposit requires confirmation and refreshes balances on success',
    (tester) async {
      var postCalls = 0;
      var deposited = false;
      final authStorage = FakeAuthStorage(initialToken: 'token');
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/economy/state') {
          return _jsonResponse(
            _economyState(
              wallet: deposited ? 25 : 30,
              savings: deposited ? 5 : 0,
            ),
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/savings/deposit') {
          postCalls++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['amount'], 5);
          expect(body['idempotencyKey'], isNotEmpty);
          deposited = true;
          return _jsonResponse({'ok': true});
        }
        fail('Unexpected request: ${request.method} ${request.url.path}');
      });

      await tester.pumpWidget(
        MaterialApp(
          home: EconomyScreen(
            apiClient: ApiClient(
              httpClient: client,
              authStorage: authStorage,
              baseUrl: 'http://test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final depositButton = find.text('Отложить 5');
      await tester.scrollUntilVisible(depositButton, 250);
      await tester.tap(depositButton);
      await tester.pumpAndSettle();

      expect(find.text('Пополнить копилку?'), findsOneWidget);
      expect(find.text('Кошелёк: 30 → 25'), findsOneWidget);
      expect(find.text('Копилка: 0 → 5'), findsOneWidget);
      expect(postCalls, 0);

      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(postCalls, 0);

      await tester.tap(depositButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Отложить 5'));
      await tester.pumpAndSettle();

      expect(postCalls, 1);
      expect(find.text('5 монет добавлено в Копилку.'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      expect(find.text('25'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    },
  );

  test('economy errors have a shared user-facing message', () {
    expect(
      economyErrorMessage(
        ApiException(409, 'food_reserve_is_unavailable_for_savings'),
      ),
      'Эти монеты пока нужны для обязательных трат.',
    );
    expect(
      economyErrorMessage(ApiException(0, 'network_error')),
      'Нет связи с сервером. Проверь подключение и обнови баланс перед повтором операции.',
    );
  });
}
