import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/core/offline/offline_economy.dart';

Map<String, dynamic> _state({
  Map<String, dynamic>? day,
  bool goal = true,
  int spendable = 0,
  int savings = 0,
}) => {
  'rules': {'dailyIncome': 30, 'foodReserve': 10, 'daysPerWeek': 7},
  'pet': {'pet_name': 'Мурзик', 'energy_level': 50, 'joy_level': 50},
  'wallets': {'SPENDABLE': spendable, 'SAVINGS': savings, 'FROZEN': 0},
  'activeDay': day,
  'activeEvent': null,
  'activeGoal': goal
      ? {
          'id': 'g1',
          'target_amount': 80,
          'saved_amount': savings,
          'remaining_amount': 80 - savings,
        }
      : null,
  'shopItems': [
    {
      'id': 'apple',
      'kind': 'NEED',
      'name': 'Яблоко',
      'price': 5,
      'energy_delta': 10,
      'joy_delta': 0,
    },
    {
      'id': 'ball',
      'kind': 'WANT',
      'name': 'Мяч',
      'price': 8,
      'energy_delta': 0,
      'joy_delta': 15,
    },
  ],
  'quests': [
    {'id': 'Q_DONE', 'assignment_status': 'COMPLETED'},
    {'id': 'Q_NEW', 'assignment_status': null},
  ],
  'recentDays': [
    {'sequence_no': 4, 'feedback_text': 'ok'},
  ],
};

Map<String, dynamic> _confirmedDay({
  int need = 10,
  int want = 10,
  int savings = 10,
}) => {
  'id': 'd1',
  'sequence_no': 5,
  'required_need_amount': 10,
  'budget_plan_status': 'CONFIRMED',
  'available_amount': 30,
  'need_amount': need,
  'want_amount': want,
  'savings_amount': savings,
  'actual_need_amount': 0,
  'remaining_reserve': 10,
};

void main() {
  late OfflineEconomy economy;
  var ids = 0;
  setUp(() {
    ids = 0;
    economy = OfflineEconomy(nextId: (kind) => 'offline-$kind-${++ids}');
  });

  Matcher refusedWith(String code) =>
      isA<ApiException>().having((e) => e.code, 'code', code);

  test('starting a day grants the daily income with a draft plan', () {
    final outcome = economy.apply('POST', '/periods', null, _state());
    final day = outcome.state!['activeDay'] as Map;
    expect(outcome.state!['wallets']['SPENDABLE'], 30);
    expect(day['sequence_no'], 5);
    expect(day['budget_plan_status'], 'DRAFT');
    expect(day['available_amount'], 30);
    expect(day['week'], 1);
    expect(day['day_of_week'], 5);
    expect(outcome.response['periodId'], outcome.createdId);
    expect(outcome.createdId, startsWith(kOfflineIdPrefix));
  });

  test('a day cannot start without a dream or twice', () {
    expect(
      () => economy.apply('POST', '/periods', null, _state(goal: false)),
      throwsA(refusedWith('financial_goal_required')),
    );
    expect(
      () =>
          economy.apply('POST', '/periods', null, _state(day: _confirmedDay())),
      throwsA(refusedWith('period_already_active')),
    );
  });

  test('confirming the plan moves the planned savings to the piggy bank', () {
    var state = economy.apply('POST', '/periods', null, _state()).state!;
    final dayId = (state['activeDay'] as Map)['id'] as String;
    state = economy.apply('PUT', '/periods/$dayId/budget-plan', {
      'needAmount': 10,
      'wantAmount': 12,
      'savingsAmount': 8,
    }, state).state!;
    state = economy
        .apply('POST', '/periods/$dayId/budget-plan/confirm', null, state)
        .state!;
    expect(state['wallets']['SPENDABLE'], 22);
    expect(state['wallets']['SAVINGS'], 8);
    expect(state['activeGoal']['saved_amount'], 8);
    expect((state['activeDay'] as Map)['budget_plan_status'], 'CONFIRMED');
  });

  test('a plan is refused the same way the server refuses it', () {
    var state = economy.apply('POST', '/periods', null, _state()).state!;
    final dayId = (state['activeDay'] as Map)['id'] as String;
    final partial = economy.apply('PUT', '/periods/$dayId/budget-plan', {
      'needAmount': 10,
      'wantAmount': 5,
      'savingsAmount': 0,
    }, state).state!;
    expect(
      () => economy.apply(
        'POST',
        '/periods/$dayId/budget-plan/confirm',
        null,
        partial,
      ),
      throwsA(refusedWith('plan_must_allocate_the_full_available_amount')),
    );
    final noFood = economy.apply('PUT', '/periods/$dayId/budget-plan', {
      'needAmount': 5,
      'wantAmount': 25,
      'savingsAmount': 0,
    }, state).state!;
    expect(
      () => economy.apply(
        'POST',
        '/periods/$dayId/budget-plan/confirm',
        null,
        noFood,
      ),
      throwsA(refusedWith('need_amount_must_be_at_least_10')),
    );
  });

  test('buying food spends coins, feeds the pet and lowers the reserve', () {
    final outcome = economy.apply('POST', '/purchases', {
      'itemId': 'apple',
      'quantity': 2,
      'idempotencyKey': 'k1',
    }, _state(day: _confirmedDay(), spendable: 20));
    final day = outcome.state!['activeDay'] as Map;
    expect(outcome.state!['wallets']['SPENDABLE'], 10);
    expect(outcome.state!['pet']['energy_level'], 70);
    expect(day['actual_need_amount'], 10);
    expect(day['remaining_reserve'], 0);
    expect(outcome.response['balanceAfter'], 10);
    expect((outcome.response['pet'] as Map)['energy_level'], 70);
  });

  test('a want cannot use the coins kept for food', () {
    expect(
      () => economy.apply('POST', '/purchases', {
        'itemId': 'ball',
        'idempotencyKey': 'k2',
      }, _state(day: _confirmedDay(), spendable: 15)),
      throwsA(refusedWith('food_reserve_is_unavailable_for_wants')),
    );
  });

  test('purchases need a confirmed plan', () {
    expect(
      () => economy.apply('POST', '/purchases', {
        'itemId': 'apple',
        'idempotencyKey': 'k3',
      }, _state(spendable: 30)),
      throwsA(refusedWith('active_day_with_confirmed_plan_required')),
    );
  });

  test('closing a followed plan records a successful day', () {
    var state = _state(
      day: _confirmedDay(need: 10, want: 8, savings: 0),
      spendable: 30,
    );
    state = economy.apply('POST', '/purchases', {
      'itemId': 'apple',
      'quantity': 2,
      'idempotencyKey': 'k4',
    }, state).state!;
    state = economy.apply('POST', '/purchases', {
      'itemId': 'ball',
      'idempotencyKey': 'k5',
    }, state).state!;
    final closed = economy.apply('POST', '/periods/d1/close', null, state);
    expect(closed.state!['activeDay'], isNull);
    final recent = (closed.state!['recentDays'] as List).first as Map;
    expect(recent['plan_followed'], isTrue);
    expect(recent['actual_want_amount'], 8);
    expect(recent['feedback_text'], contains('Мурзик'));
    expect(closed.response['offline'], isTrue);
  });

  test(
    'stroking follows the server rule: half a point, 10% less each time',
    () {
      var now = DateTime(2026, 10, 18, 12);
      economy = OfflineEconomy(
        nextId: (kind) => 'offline-$kind-${++ids}',
        clock: () => now,
      );
      var state = _state();
      final gains = <double>[];
      for (var i = 0; i < 3; i++) {
        final outcome = economy.apply('POST', '/pet/stroke', null, state);
        gains.add(outcome.response['joy_gain'] as double);
        state = outcome.state!;
        now = now.add(const Duration(seconds: 1));
      }
      expect(gains.map((g) => (g * 1000).round()), [500, 450, 405]);
      expect(state['pet']['joy_level'], 51);
    },
  );

  test('a completed quest is replayed as training, a new one gets an id', () {
    final done = economy.apply('POST', '/quests/Q_DONE/start', null, _state());
    expect(done.queue, isFalse);
    expect(done.response['completed'], isTrue);

    final fresh = economy.apply('POST', '/quests/Q_NEW/start', null, _state());
    expect(fresh.queue, isTrue);
    expect(fresh.response['assignmentId'], fresh.createdId);
  });

  test('quest answers are saved without a preview', () {
    final outcome = economy.apply(
      'POST',
      '/assignments/offline-assignment-1/answer',
      {'stepNo': 1},
      _state(),
    );
    expect(outcome.saveOnly, isTrue);
  });

  test('only choices that need the server stay online-only', () {
    expect(OfflineEconomy.supports('POST', '/purchases'), isTrue);
    expect(OfflineEconomy.supports('PUT', '/periods/x/budget-plan'), isTrue);
    expect(OfflineEconomy.supports('POST', '/insurance/purchase'), isTrue);
    expect(OfflineEconomy.supports('POST', '/frost-chests'), isTrue);
    expect(OfflineEconomy.supports('POST', '/park-project/decision'), isTrue);
    expect(OfflineEconomy.supports('POST', '/goals'), isTrue);
    // Linking a parent and rolling events stay online.
    expect(
      OfflineEconomy.supports('POST', '/child/parent-link/redeem'),
      isFalse,
    );
    expect(OfflineEconomy.supports('POST', '/pet-events/roll'), isFalse);
  });

  group('choosing a dream', () {
    Map<String, dynamic> withCatalog({int savings = 0}) => {
      ..._state(goal: false, savings: savings),
      'artifacts': [
        {'id': 'saucer', 'name': 'Блюдечко', 'price': 70},
      ],
      'inventory': [
        {'id': 'i1', 'item_id': 'vial'},
      ],
    };

    test('picks an artifact from the remembered catalog', () {
      final outcome = economy.apply('POST', '/goals', {
        'targetItemId': 'saucer',
      }, withCatalog(savings: 20));
      final goal = outcome.state!['activeGoal'] as Map;
      expect(goal['target_amount'], 70);
      expect(goal['saved_amount'], 20);
      expect(goal['status'], 'ACTIVE');
      expect(goal['name'], 'Блюдечко');
      expect(outcome.response['id'], outcome.createdId);
    });

    test('savings that already cover it make the dream achieved', () {
      final outcome = economy.apply('POST', '/goals', {
        'targetItemId': 'saucer',
      }, withCatalog(savings: 80));
      expect((outcome.state!['activeGoal'] as Map)['status'], 'ACHIEVED');
    });

    test('a dream cannot be changed, owned or unknown', () {
      final chosen = economy.apply('POST', '/goals', {
        'targetItemId': 'saucer',
      }, withCatalog()).state!;
      final again = economy.apply('POST', '/goals', {
        'targetItemId': 'saucer',
      }, chosen);
      expect(again.queue, isFalse);
      expect(again.response['replayed'], isTrue);
      expect(
        () =>
            economy.apply('POST', '/goals', {'targetItemId': 'boots'}, chosen),
        throwsA(refusedWith('goal_change_not_allowed')),
      );
      expect(
        () => economy.apply('POST', '/goals', {
          'targetItemId': 'vial',
        }, withCatalog()),
        throwsA(refusedWith('artifact_already_owned')),
      );
      expect(
        () => economy.apply('POST', '/goals', {
          'targetItemId': 'unknown',
        }, withCatalog()),
        throwsA(refusedWith('artifact_not_found')),
      );
    });

    test('topping up the piggy bank to the price achieves the dream', () {
      var state = economy.apply('POST', '/goals', {
        'targetItemId': 'saucer',
      }, withCatalog(savings: 65)).state!;
      state['activeDay'] = _confirmedDay();
      state['wallets']['SPENDABLE'] = 30;
      state = economy.apply('POST', '/savings/deposit', {
        'amount': 5,
      }, state).state!;
      expect((state['activeGoal'] as Map)['status'], 'ACHIEVED');
    });
  });
}
