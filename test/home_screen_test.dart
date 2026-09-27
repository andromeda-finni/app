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

// Deliberately not "Грошик": the screen must show the name the child chose,
// and a default name in the fixture would hide a hardcoded fallback.
const _petName = 'Мурзик';

Map<String, dynamic> _pet({
  int satiety = 60,
  int joy = 55,
  int health = 100,
  int stage = 1,
}) => {
  'pet_name': _petName,
  'fur_option_id': 'FUR_GRAY',
  'energy_level': satiety,
  'joy_level': joy,
  'health_level': health,
  'evolution_stage': stage,
};

const _goal = {'id': 'goal-1', 'name': 'Сундучок', 'target_amount': 80};

/// The single read model the screen loads, shaped like `GET /economy/state`.
Map<String, dynamic> _economyState({
  Map<String, dynamic>? pet,
  Object? period,
  Object? goal = _goal,
  int spendable = 40,
  int savings = 10,
}) => {
  'pet': pet ?? _pet(),
  'wallets': {'SPENDABLE': spendable, 'SAVINGS': savings, 'FROZEN': 0},
  'activeDay': period,
  'activeGoal': goal,
};

/// Builds the screen over a stub backend. [onRequest] observes every call.
Widget _screen({
  Map<String, dynamic>? pet,
  Object? period,
  Map<String, dynamic>? activeEvent,
  Object? goal = _goal,
  int spendable = 40,
  int savings = 10,
  VoidCallback? onChooseGoal,
  VoidCallback? onOpenQuests,
  void Function(http.BaseRequest request, String body)? onRequest,
}) {
  final client = MockClient((request) async {
    onRequest?.call(request, request.body);
    return switch (request.url.path) {
      '/economy/state' => _json(
        _economyState(
          pet: pet,
          period: period,
          goal: goal,
          spendable: spendable,
          savings: savings,
        ),
      ),
      '/pet-events/active' => _json(activeEvent),
      '/pet-events/roll' => _json({'triggered': false}),
      final path
          when path.startsWith('/pet-events/') && path.endsWith('/resolve') =>
        _json({
          'ok': true,
          'spendableBalance':
              spendable - (activeEvent?['amount_due'] as int? ?? 0),
          'healthLevel': 100,
        }),
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
        onChooseGoal: onChooseGoal ?? () {},
        onOpenQuests: onOpenQuests,
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

Map<String, dynamic> _activeEvent({String id = 'POOR_PAW'}) {
  const catalog = {
    'POOR_PAW': (10, 'Уколол лапку'),
    'SICK': (15, 'Питомец простудился'),
  };
  final item = catalog[id]!;
  return {
    'id': '22222222-2222-2222-2222-222222222222',
    'event_definition_id': id,
    'amount_due': item.$1,
    'title': item.$2,
    'description': 'Описание события',
    'triggered_at': '2026-09-27T08:00:00.000Z',
  };
}

/// The screen is a tall scrolling page and a ListView does not build what is
/// off-screen, so the default 800x600 test viewport hides the plan card from
/// every finder. A tall viewport keeps the whole page mounted instead.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(screen);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
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

    expect(find.text(_petName), findsOneWidget);
    expect(find.textContaining('Стадия 1 из 3'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('restores an active event with warning UI after app restart', (
    tester,
  ) async {
    final calls = <String>[];
    await _pump(
      tester,
      _screen(
        pet: _pet(joy: 56, health: 55),
        activeEvent: _activeEvent(),
        onRequest: (request, _) => calls.add(request.url.path),
      ),
      settle: false,
    );

    expect(calls, contains('/pet-events/active'));
    expect(find.byKey(const Key('pet-event-banner')), findsOneWidget);
    expect(find.byKey(const Key('pet-event-indicator')), findsOneWidget);
    expect(find.text('55%'), findsOneWidget);
    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);
    expect(images, contains('assets/Cat/Red_collar/sad/striped.png'));

    await tester.tap(find.byKey(const Key('pet-event-banner')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ой! Мурзик уколол лапку!'), findsOneWidget);
    expect(find.text('К оплате: 10 🪙'), findsOneWidget);
  });

  testWidgets('resolving spends coins, restores health and clears the alert', (
    tester,
  ) async {
    final calls = <String>[];
    await _pump(
      tester,
      _screen(
        pet: _pet(joy: 56, health: 55),
        spendable: 40,
        activeEvent: _activeEvent(),
        onRequest: (request, _) =>
            calls.add('${request.method} ${request.url.path}'),
      ),
      settle: false,
    );

    await tester.tap(find.byKey(const Key('pet-event-banner')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('pet-event-resolve')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('pet-event-feedback')), findsOneWidget);
    expect(
      find.text(
        'Хорошо, когда есть монетки на лечение! Лапка снова в порядке!',
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      calls,
      contains('POST /pet-events/22222222-2222-2222-2222-222222222222/resolve'),
    );
    expect(find.byKey(const Key('pet-event-banner')), findsNothing);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('insufficient funds offer a safe route to quests', (
    tester,
  ) async {
    var openedQuests = false;
    await _pump(
      tester,
      _screen(
        pet: _pet(joy: 56, health: 55),
        spendable: 5,
        activeEvent: _activeEvent(),
        onOpenQuests: () => openedQuests = true,
      ),
      settle: false,
    );

    await tester.tap(find.byKey(const Key('pet-event-banner')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Монет пока не хватает'), findsOneWidget);
    expect(find.textContaining('Пойдем на тропинку заданий'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pet-event-open-quests')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(openedQuests, isTrue);
    expect(find.byKey(const Key('pet-event-banner')), findsOneWidget);
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

  testWidgets('starting a game day rolls a random event after the day exists', (
    tester,
  ) async {
    final calls = <String>[];
    await _pump(
      tester,
      _screen(
        period: null,
        onRequest: (request, _) =>
            calls.add('${request.method} ${request.url.path}'),
      ),
    );

    await tester.tap(find.text('Начать период'));
    await tester.pumpAndSettle();

    final start = calls.indexOf('POST /periods');
    final roll = calls.indexOf('POST /pet-events/roll');
    expect(start, isNonNegative);
    expect(roll, greaterThan(start));
  });

  testWidgets('without a chosen goal, starting a day asks for a goal first', (
    tester,
  ) async {
    var askedForGoal = false;
    final calls = <String>[];
    await _pump(
      tester,
      _screen(
        period: null,
        goal: null,
        onChooseGoal: () => askedForGoal = true,
        onRequest: (request, _) =>
            calls.add('${request.method} ${request.url.path}'),
      ),
    );

    await tester.tap(find.text('Начать период'));
    await tester.pumpAndSettle();

    expect(askedForGoal, isTrue);
    // The day grant is paid when a day starts, so starting one without a goal
    // would hand out coins before the child has anything to save towards.
    expect(calls, isNot(contains('POST /periods')));
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
      if (attempt <= 1) return http.Response('', 500);
      return switch (request.url.path) {
        '/economy/state' => _json(_economyState()),
        '/pet-events/active' => _json(null),
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
            onChooseGoal: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text(_petName), findsOneWidget);
  });
}

const _periodId = '11111111-1111-1111-1111-111111111111';
