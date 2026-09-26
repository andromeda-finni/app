import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/day_summary/day_end_action.dart';
import 'package:andromeda_app/day_summary/day_summary.dart';
import 'package:andromeda_app/day_summary/day_summary_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';

import 'support/fake_auth_storage.dart';

const _summaryJson = <String, dynamic>{
  'periodId': '11111111-1111-1111-1111-111111111111',
  'sequenceNo': 4,
  'earnedAmount': 42,
  'plan': {'need': 10, 'want': 5, 'savings': 15},
  'actual': {'need': 0, 'want': 15, 'savings': 15},
  'needCovered': false,
  'planFollowed': false,
  'feedback': 'Сегодня план и действия немного разошлись. Мурзик ждёт заботы, а завтра попробуем ещё раз.',
  'recommendations': ['Сначала закрой обязательные траты на питомца.'],
};

void main() {
  test('parses the stable nested plan/fact contract', () {
    final summary = DaySummary.fromJson(_summaryJson);

    expect(summary.sequenceNo, 4);
    expect(summary.earnedAmount, 42);
    expect(summary.plan.need, 10);
    expect(summary.actual.want, 15);
    expect(summary.recommendations, hasLength(1));
  });

  testWidgets('shows one clouded mirror with plan, fact and advice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DaySummaryScreen(
          summary: DaySummary.fromJson(_summaryJson),
          onContinue: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Свет мой, зеркальце, скажи…'), findsOneWidget);
    expect(find.text('Заработано'), findsOneWidget);
    expect(find.text('Планировали'), findsOneWidget);
    expect(find.text('Получилось'), findsOneWidget);
    expect(find.text('Надо'), findsNWidgets(2));
    expect(find.text('Продолжить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('close action posts once, opens the result and refreshes home', (
    tester,
  ) async {
    var closeCalls = 0;
    var refreshCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/close')) {
        closeCalls++;
        return http.Response(
          jsonEncode(_summaryJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DayEndAction(
            apiClient: ApiClient(
              httpClient: client,
              authStorage: FakeAuthStorage(initialToken: 'token'),
              baseUrl: 'http://test',
            ),
            periodId: _summaryJson['periodId']! as String,
            onCompleted: () async => refreshCalls++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Завершить день'));
    await tester.pumpAndSettle();
    expect(closeCalls, 1);
    expect(find.text('Свет мой, зеркальце, скажи…'), findsOneWidget);

    await tester.ensureVisible(find.text('Продолжить'));
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(refreshCalls, 1);
    expect(find.text('Завершить день'), findsOneWidget);
  });
}
