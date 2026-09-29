import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/economy/savings_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';

import 'support/economy_fixture.dart';
import 'support/fake_auth_storage.dart';

Map<String, dynamic> _state({
  int wallet = 20,
  int savings = 10,
  int frozen = 0,
  bool goal = true,
  bool dayReady = true,
  int reserve = 10,
  List<Map<String, dynamic>> history = const [],
  Map<String, dynamic>? frost,
}) => {
  'rules': testEconomyRules,
  'pet': {'pet_name': 'Копейка'},
  'wallets': {'SPENDABLE': wallet, 'SAVINGS': savings, 'FROZEN': frozen},
  'activeDay': dayReady
      ? {
          'id': 'day-1',
          'sequence_no': 1,
          'budget_plan_status': 'CONFIRMED',
          'required_need_amount': 10,
          'remaining_reserve': reserve,
        }
      : null,
  'activeGoal': goal
      ? {
          'id': 'goal-1',
          'target_item_id': 'saucer',
          'target_amount': 80,
          'status': 'ACTIVE',
          'name': 'Серебряное блюдечко',
        }
      : null,
  'activeFrostChest': frost,
  'artifacts': <Object>[],
  'savingsHistory': history,
};

Widget _screen(Map<String, dynamic> state, {VoidCallback? onChooseGoal}) {
  final client = MockClient(
    (request) async => http.Response(
      jsonEncode(state),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  );
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SavingsScreen(
        apiClient: ApiClient(
          httpClient: client,
          authStorage: FakeAuthStorage(initialToken: 'tok'),
          baseUrl: 'http://test',
        ),
        onBack: () {},
        onChooseGoal: onChooseGoal ?? () {},
        onBrowseGoals: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('savings balance leads the screen, wallet and chest beside it', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_state(savings: 15, frozen: 10)));
    await tester.pumpAndSettle();

    expect(find.text('В копилке'), findsOneWidget);
    expect(find.text('15 монет'), findsOneWidget);
    expect(
      find.textContaining('Кошелёк: 20 монет', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('В сундуке: 10 монет', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('goal progress shows coins, percent and what is left', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_state(savings: 20)));
    await tester.pumpAndSettle();

    expect(find.text('Моя цель'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('Осталось накопить 60 монет'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Накоплено 20 из 80 монет, 25 процентов цели'),
      findsOneWidget,
    );
    expect(find.text('Получить артефакт'), findsNothing);
  });

  testWidgets('a reached goal offers the artifact', (tester) async {
    await tester.pumpWidget(_screen(_state(savings: 80)));
    await tester.pumpAndSettle();

    expect(find.text('100%'), findsOneWidget);
    expect(
      find.text('Цель накоплена! Можно забрать артефакт.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Получить артефакт'));
    expect(find.text('Получить артефакт'), findsOneWidget);
  });

  testWidgets('without a goal the child is led to choose one', (tester) async {
    var chose = false;
    await tester.pumpWidget(
      _screen(
        _state(goal: false, dayReady: false),
        onChooseGoal: () => chose = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Сначала выбери мечту'), findsOneWidget);
    final deposit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Пополнить'),
    );
    expect(deposit.onPressed, isNull);

    await tester.tap(find.text('Выбрать мечту'));
    expect(chose, isTrue);
  });

  testWidgets('before the day starts transfers explain why they are closed', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_state(dayReady: false)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Переводы откроются'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Пополнить'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('history explains every savings movement', (tester) async {
    await tester.pumpWidget(
      _screen(
        _state(
          savings: 10,
          history: [
            {
              'event_type': 'SAVINGS_WITHDRAWAL',
              'delta_amount': -5,
              'balance_after': 10,
              'occurred_at': '2026-09-28T15:00:00Z',
              'from_plan': false,
            },
            {
              'event_type': 'SAVINGS_DEPOSIT',
              'delta_amount': 5,
              'balance_after': 15,
              'occurred_at': '2026-09-28T14:59:00Z',
              'from_plan': false,
            },
            {
              'event_type': 'SAVINGS_DEPOSIT',
              'delta_amount': 10,
              'balance_after': 10,
              'occurred_at': '2026-09-28T14:54:00Z',
              'from_plan': true,
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Возвращено в кошелёк'), findsOneWidget);
    expect(find.text('Пополнение копилки'), findsOneWidget);
    expect(find.text('Отложено по плану дня'), findsOneWidget);
    expect(find.text('−5'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('итого 15'), findsOneWidget);
  });

  testWidgets('deposit sheet shows the food reserve and locks what it covers', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_state(wallet: 15, reserve: 10)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Пополнить'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'В кошельке 15 монет, из них 10 — на еду питомцу. Отложить можно до 5 монет.',
      ),
      findsOneWidget,
    );
    OutlinedButton choice(String label) => tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(choice('5 монет').onPressed, isNotNull);
    expect(choice('10 монет').onPressed, isNull);
  });

  testWidgets('an open chest shows its days and payout', (tester) async {
    await tester.pumpWidget(
      _screen(
        _state(
          frozen: 20,
          frost: {
            'id': 'chest-1',
            'principal_amount': 20,
            'bonus_amount': 2,
            'completed_days': 2,
            'days_remaining': 3,
            'maturity_days': 5,
            'matured': false,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Внутри 20 монет'), findsOneWidget);
    expect(find.text('Осталось 3 игровых дня'), findsOneWidget);
    expect(find.text('В конце вернётся 22 монеты'), findsOneWidget);
    expect(find.bySemanticsLabel('Прошло 2 из 5 игровых дней'), findsOneWidget);
  });

  for (final (width, scale) in [(320.0, 1.0), (360.0, 1.3), (412.0, 1.6)]) {
    testWidgets('no overflow at ${width.toInt()}dp, text x$scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(scale),
          ),
          child: _screen(
            _state(
              savings: 80,
              frozen: 20,
              frost: {
                'id': 'chest-1',
                'principal_amount': 20,
                'bonus_amount': 2,
                'completed_days': 5,
                'days_remaining': 0,
                'maturity_days': 5,
                'matured': true,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
