import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/home/main_shell.dart';

import 'support/fake_auth_storage.dart';

http.Response _jsonResponse(Object body, [int statusCode = 200]) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _state({required bool withGoal}) => {
  'pet': {
    'pet_name': 'Грошик',
    'fur_option_id': 'FUR_GRAY',
    'energy_level': 100,
    'joy_level': 50,
    'evolution_stage': 1,
  },
  'wallets': {'SPENDABLE': 30, 'SAVINGS': 0, 'FROZEN': 0},
  'activeDay': {
    'id': 'day-1',
    'sequence_no': 1,
    'budget_plan_status': 'CONFIRMED',
    'available_amount': 30,
    'required_need_amount': 10,
    'remaining_reserve': 10,
    'need_amount': 10,
    'want_amount': 10,
    'savings_amount': 10,
  },
  'activeEvent': null,
  'activeGoal': withGoal
      ? {
          'id': 'goal-1',
          'target_item_id': 'boots',
          'name': 'Сапоги-скороходы',
          'target_amount': 100,
          'status': 'ACTIVE',
        }
      : null,
  'activeFrostChest': null,
  'shopItems': [
    {'id': 'food', 'name': 'Полезный обед', 'kind': 'NEED', 'price': 6},
    {'id': 'ball', 'name': 'Мячик', 'kind': 'WANT', 'price': 8},
  ],
  'artifacts': [
    {'id': 'boots', 'name': 'Сапоги-скороходы', 'price': 100},
    {'id': 'shield', 'name': 'Богатырский щит', 'price': 130},
  ],
  'inventory': <Object>[],
  'quests': <Object>[],
  'parentTasks': <Object>[],
  'recentTransactions': <Object>[],
  'recentDays': <Object>[],
};

Future<void> _pumpShell(WidgetTester tester, MockClient client) async {
  final auth = FakeAuthStorage(initialToken: 'token');
  await tester.pumpWidget(
    MaterialApp(
      home: MainShell(
        apiClient: ApiClient(
          httpClient: client,
          authStorage: auth,
          baseUrl: 'http://test',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('store has no overflow on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = _state(withGoal: true);
    await _pumpShell(
      tester,
      MockClient((request) async => _jsonResponse(data)),
    );

    await tester.tap(find.text('Магазин'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Надо'), findsOneWidget);
  });

  testWidgets('savings art and Frost status fit a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = _state(withGoal: true);
    (data['artifacts'] as List<dynamic>).first['image_asset'] =
        'assets/images/morozko_chest.png';
    data['activeFrostChest'] = {
      'id': 'frost-1',
      'principal_amount': 10,
      'bonus_amount': 1,
      'completed_days': 1,
      'days_remaining': 4,
      'matured': false,
    };
    await _pumpShell(
      tester,
      MockClient((request) async => _jsonResponse(data)),
    );

    await tester.tap(find.text('Копилка'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Сапоги-скороходы'), findsOneWidget);
    expect(find.text('Сундук закрыт'), findsOneWidget);
    expect(find.text('Осталось 4 игровых дня'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/morozko_chest.png',
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('starting the first day routes to goal selection in the store', (
    tester,
  ) async {
    final data = _state(withGoal: false)..['activeDay'] = null;
    var mutationCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return _jsonResponse(data);
      mutationCalls++;
      return _jsonResponse({});
    });
    await _pumpShell(tester, client);

    await tester.scrollUntilVisible(
      find.text('Начать период'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Начать период'));
    await tester.pumpAndSettle();

    expect(mutationCalls, 0);
    expect(find.text('Выбор мечты'), findsOneWidget);
    expect(find.text('Сначала выбери мечту'), findsOneWidget);
    expect(find.text('Полезный обед'), findsNothing);
  });

  testWidgets('goal selection goes through the store and returns to savings', (
    tester,
  ) async {
    var data = _state(withGoal: false);
    var goalCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return _jsonResponse(data);
      expect(request.url.path, '/goals');
      goalCalls++;
      data = _state(withGoal: true);
      return _jsonResponse({'id': 'goal-1', 'targetAmount': 100}, 201);
    });
    await _pumpShell(tester, client);

    await tester.tap(find.text('Копилка'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Выбрать'));
    await tester.pumpAndSettle();

    expect(find.text('Выбор мечты'), findsOneWidget);
    expect(
      find.text(
        'Покупки временно скрыты. Выбери артефакт, на который будешь копить.',
      ),
      findsOneWidget,
    );
    expect(find.text('Полезный обед'), findsNothing);
    expect(find.text('Мячик'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(Row, 'Сапоги-скороходы'),
        matching: find.widgetWithText(OutlinedButton, 'Выбрать'),
      ),
    );
    await tester.pumpAndSettle();
    expect(goalCalls, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Выбрать'));
    await tester.pumpAndSettle();

    expect(goalCalls, 1);
    expect(find.text('Моя цель'), findsOneWidget);
    expect(find.text('Сапоги-скороходы'), findsOneWidget);
  });

  testWidgets('ordinary store purchase requires explicit confirmation', (
    tester,
  ) async {
    final data = _state(withGoal: true);
    var purchaseCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return _jsonResponse(data);
      expect(request.url.path, '/purchases');
      purchaseCalls++;
      return _jsonResponse({'balanceAfter': 22}, 201);
    });
    await _pumpShell(tester, client);

    await tester.tap(find.text('Магазин'));
    await tester.pumpAndSettle();
    expect(find.text('Надо'), findsOneWidget);
    expect(find.text('Хочу'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '8 монет'));
    await tester.pumpAndSettle();
    expect(purchaseCalls, 0);
    expect(find.text('Купить Мячик?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(purchaseCalls, 0);

    await tester.tap(find.widgetWithText(OutlinedButton, '8 монет'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Купить'));
    await tester.pumpAndSettle();
    expect(purchaseCalls, 1);
  });
}
