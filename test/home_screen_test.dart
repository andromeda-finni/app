import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/core/pet_assets.dart';
import 'package:andromeda_app/home/home_screen.dart';
import 'package:andromeda_app/home/models/pet.dart';

import 'support/fake_auth_storage.dart';

http.Response _json(Object? body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _pet({
  int satiety = 60,
  int joy = 55,
  int health = 100,
  int stage = 1,
}) => {
  'pet_name': 'Грошик',
  'fur_option_id': 'FUR_GRAY',
  'energy_level': satiety,
  'joy_level': joy,
  'health_level': health,
  'evolution_stage': stage,
};

/// Builds the screen over a stub backend. [period] is what
/// `GET /periods/active` answers; [onRequest] observes every call.
Widget _screen({
  Map<String, dynamic>? pet,
  Object? period,
  int spendable = 40,
  int savings = 10,
  void Function(http.BaseRequest request, String body)? onRequest,
}) {
  final client = MockClient((request) async {
    onRequest?.call(request, request.body);
    return switch (request.url.path) {
      '/pet' => _json(pet ?? _pet()),
      '/wallets' => _json([
        {'kind': 'SPENDABLE', 'balance': spendable},
        {'kind': 'SAVINGS', 'balance': savings},
      ]),
      '/periods/active' => _json(period),
      _ => _json({'ok': true}),
    };
  });

  return MaterialApp(
    home: Scaffold(
      body: HomeScreen(
        apiClient: ApiClient(
          httpClient: client,
          authStorage: FakeAuthStorage(initialToken: 'tok'),
          baseUrl: 'http://test',
        ),
      ),
    ),
  );
}

Map<String, dynamic> _draftPeriod({
  int available = 100,
  int requiredNeed = 10,
  int need = 0,
  int want = 0,
  int savings = 0,
}) => {
  'id': '11111111-1111-1111-1111-111111111111',
  'required_need_amount': requiredNeed,
  'budget_plan_id': 'plan-1',
  'budget_plan_status': 'DRAFT',
  'available_amount': available,
  'need_amount': need,
  'want_amount': want,
  'savings_amount': savings,
};

/// The screen is a tall scrolling page and a ListView does not build what is
/// off-screen, so the default 800x600 test viewport hides the plan card from
/// every finder. A tall viewport keeps the whole page mounted instead.
Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(screen);
  await tester.pumpAndSettle();
}

void main() {
  group('pet mood', () {
    test('rejects a pet response without the chosen name', () {
      expect(
        () => Pet.fromJson({..._pet(), 'pet_name': ''}),
        throwsFormatException,
      );
    });

    test('an unpaid illness makes the pet visibly sad', () {
      // A pet event takes 45 health off, so the "unwell" threshold has to sit
      // above 55 or an unpaid bill would leave the pet looking fine.
      expect(moodFor(satiety: 80, joy: 80, health: 55), PetMood.sad);
      expect(moodFor(satiety: 80, joy: 80, health: 100), PetMood.happy);
    });

    test('bad news wins over good news', () {
      // Stuffed but miserable still reads as sad, so a problem is never
      // hidden behind a happy face.
      expect(moodFor(satiety: 100, joy: 10, health: 100), PetMood.sad);
    });

    test('maps the remaining stats onto the other drawings', () {
      expect(moodFor(satiety: 10, joy: 60, health: 100), PetMood.sleep);
      expect(moodFor(satiety: 95, joy: 65, health: 100), PetMood.fully);
      expect(moodFor(satiety: 60, joy: 50, health: 100), PetMood.base);
      // A brand-new pet (satiety 100, joy 50) must not already look like a
      // food coma, or the stuffed pose stops meaning anything.
      expect(moodFor(satiety: 100, joy: 50, health: 100), PetMood.base);
    });

    test('each mood resolves to art that exists for every fur colour', () {
      for (final fur in ['FUR_GRAY', 'FUR_ORANGE', 'FUR_WHITE']) {
        for (final mood in PetMood.values) {
          expect(
            catAsset(furOptionId: fur, mood: mood),
            matches(
              RegExp(r'^assets/Cat/Red_collar/\w+/(striped|red|white)\.png$'),
            ),
          );
        }
      }
    });
  });

  testWidgets('shows the pet, its stats and both coin balances', (
    tester,
  ) async {
    await _pump(
      tester,
      _screen(pet: _pet(satiety: 30, joy: 40, health: 100), spendable: 42),
    );

    expect(find.text('Грошик'), findsOneWidget);
    expect(find.textContaining('Стадия 1 из 3'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('draws the pet art matching its current state', (tester) async {
    await _pump(tester, _screen(pet: _pet(satiety: 80, joy: 90, health: 100)));

    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);
    expect(images, contains('assets/Cat/Red_collar/happy/striped.png'));
  });

  testWidgets('offers to start a period when none is running', (tester) async {
    await _pump(tester, _screen(period: null));

    expect(find.text('Начать период'), findsOneWidget);
    expect(find.text('Утвердить план'), findsNothing);
  });

  testWidgets('blocks approval until the coins add up and needs are covered', (
    tester,
  ) async {
    await _pump(
      tester,
      _screen(period: _draftPeriod(available: 12, requiredNeed: 5)),
    );

    ElevatedButton approveButton() => tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Утвердить план'),
        matching: find.byType(ElevatedButton),
      ),
    );

    // Nothing allocated yet.
    expect(approveButton().onPressed, isNull);
    expect(find.textContaining('Осталось разложить 12'), findsOneWidget);

    // Put all 12 into wants: the total matches but the must-haves floor does
    // not, which is the rule the server would otherwise reject.
    for (var i = 0; i < 12; i++) {
      await tester.tap(
        find.bySemanticsLabel('Добавить монету: Необязательное'),
      );
      await tester.pump();
    }
    expect(approveButton().onPressed, isNull);
    expect(find.textContaining('хотя бы 5'), findsOneWidget);
  });

  testWidgets('approving sends the split and then confirms it', (tester) async {
    final calls = <String>[];
    String? planBody;

    await _pump(
      tester,
      _screen(
        period: _draftPeriod(available: 3, requiredNeed: 1),
        onRequest: (request, body) {
          calls.add('${request.method} ${request.url.path}');
          if (request.url.path.endsWith('/budget-plan')) planBody = body;
        },
      ),
    );

    await tester.tap(find.bySemanticsLabel('Добавить монету: Обязательное'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Добавить монету: Необязательное'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Добавить монету: В копилку'));
    await tester.pump();

    await tester.tap(find.text('Утвердить план'));
    await tester.pumpAndSettle();

    expect(planBody, contains('"needAmount":1'));
    expect(planBody, contains('"savingsAmount":1'));
    // The split has to be saved before it is approved, or the server would
    // confirm whatever the previous draft happened to hold.
    final putIndex = calls.indexOf('PUT /periods/$_periodId/budget-plan');
    final confirmIndex = calls.indexOf(
      'POST /periods/$_periodId/budget-plan/confirm',
    );
    expect(putIndex, isNonNegative);
    expect(confirmIndex, greaterThan(putIndex));
  });

  testWidgets('an approved plan becomes a read-only summary', (tester) async {
    final confirmed = _draftPeriod(need: 40, want: 30, savings: 30)
      ..['budget_plan_status'] = 'CONFIRMED';

    await _pump(tester, _screen(period: confirmed));

    expect(find.text('План утверждён'), findsOneWidget);
    expect(find.text('Утвердить план'), findsNothing);
    expect(find.bySemanticsLabel('Добавить монету: В копилку'), findsNothing);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    var attempt = 0;
    final client = MockClient((request) async {
      attempt++;
      if (attempt <= 3) return http.Response('', 500);
      return switch (request.url.path) {
        '/pet' => _json(_pet()),
        '/wallets' => _json(const []),
        _ => _json(null),
      };
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            apiClient: ApiClient(
              httpClient: client,
              authStorage: FakeAuthStorage(initialToken: 'tok'),
              baseUrl: 'http://test',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Грошик'), findsOneWidget);
  });
}

const _periodId = '11111111-1111-1111-1111-111111111111';
