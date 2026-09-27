import 'dart:convert';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/insurance/insurance_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_auth_storage.dart';
import 'support/economy_fixture.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _state({
  bool insured = false,
  int wallet = 30,
  int plannedNeed = 10,
  int actualNeed = 10,
}) => {
  'rules': testEconomyRules,
  'pet': {'pet_name': 'Мурзик', 'energy_level': 100, 'joy_level': 100},
  'wallets': {'SPENDABLE': wallet, 'SAVINGS': 0, 'FROZEN': 0},
  'activeDay': {
    'id': 'day-1',
    'sequence_no': 1,
    'budget_plan_status': 'CONFIRMED',
    'available_amount': 30,
    'required_need_amount': 10,
    'need_amount': plannedNeed,
    'want_amount': 20,
    'savings_amount': 0,
    'actual_need_amount': actualNeed,
    'remaining_reserve': 0,
  },
  'activeEvent': null,
  'activeInsurance': insured
      ? {
          'id': 'policy-1',
          'coverage_sequence_no': 2,
          'premium_amount': 5,
          'status': 'ACTIVE',
        }
      : null,
  'activeGoal': null,
  'activeFrostChest': null,
  'shopItems': <Object>[],
  'artifacts': <Object>[],
  'inventory': <Object>[],
  'quests': <Object>[],
  'parentTasks': <Object>[],
  'recentTransactions': <Object>[],
  'recentDays': <Object>[],
};

Future<void> _pump(WidgetTester tester, MockClient client) async {
  tester.view.physicalSize = const Size(390, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: InsuranceScreen(
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

void main() {
  testWidgets('shows price, comparison, balance and accessible status', (
    tester,
  ) async {
    await _pump(tester, MockClient((_) async => _json(_state())));

    expect(find.text('Стол подорожника'), findsOneWidget);
    expect(find.text('Цена: 5 🪙'), findsOneWidget);
    expect(find.text('Останется\n25 🪙'), findsOneWidget);
    expect(
      find.textContaining('если Мурзик завтра простудится'),
      findsOneWidget,
    );
    expect(find.textContaining('если Финни завтра простудится'), findsNothing);
    expect(
      find.textContaining('придётся экстренно потратить 10–15'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('На завтра защиты нет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warns on NEED plan overrun and purchases only after consent', (
    tester,
  ) async {
    var insured = false;
    var purchaseCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return _json(_state(insured: insured));
      expect(request.url.path, '/insurance/purchase');
      purchaseCalls++;
      insured = true;
      return _json({'policyId': 'policy-1', 'balanceAfter': 25}, 201);
    });
    await _pump(tester, client);

    await tester.scrollUntilVisible(
      find.byKey(const Key('insurance-purchase')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('insurance-purchase')));
    await tester.pumpAndSettle();
    expect(purchaseCalls, 0);
    expect(
      find.text(
        'Это превысит запланированные траты на «Надо». Всё равно купить?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Всё равно купить'));
    await tester.pumpAndSettle();
    expect(purchaseCalls, 1);
    expect(find.text('Защита на завтра уже действует'), findsOneWidget);
  });

  testWidgets('an active policy blocks a duplicate purchase', (tester) async {
    var postCalls = 0;
    await _pump(
      tester,
      MockClient((request) async {
        if (request.method == 'POST') postCalls++;
        return _json(_state(insured: true));
      }),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('insurance-purchase')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('insurance-purchase')),
    );
    expect(button.onPressed, isNull);
    expect(postCalls, 0);
    expect(find.bySemanticsLabel('Защита активна на завтра'), findsOneWidget);
  });
}
