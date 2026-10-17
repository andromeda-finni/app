import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/core/offline/offline_economy.dart';

Map<String, dynamic> _state({
  int spendable = 40,
  int savings = 0,
  int frozen = 0,
  int remainingReserve = 0,
  Map<String, dynamic>? goal,
  Map<String, dynamic>? chest,
  Map<String, dynamic>? event,
  List<Map<String, dynamic>> inventory = const [],
}) => {
  'rules': {
    'dailyIncome': 30,
    'foodReserve': 10,
    'daysPerWeek': 7,
    'insurancePremium': 5,
    'frostMinimum': 10,
    'frostMaximum': 50,
    'frostStep': 10,
    'frostDays': 5,
    'frostBonusPercent': 10,
  },
  'pet': {
    'pet_name': 'Мурзик',
    'energy_level': 20,
    'joy_level': 50,
    'health_level': 40,
  },
  'wallets': {'SPENDABLE': spendable, 'SAVINGS': savings, 'FROZEN': frozen},
  'activeDay': {
    'id': 'd1',
    'sequence_no': 3,
    'required_need_amount': 10,
    'budget_plan_status': 'CONFIRMED',
    'available_amount': 30,
    'need_amount': 10,
    'want_amount': 20,
    'savings_amount': 0,
    'actual_need_amount': 10 - remainingReserve,
    'remaining_reserve': remainingReserve,
    'week': 1,
    'day_of_week': 3,
  },
  'activeEvent': event,
  'activeInsurance': null,
  'activeGoal': goal,
  'activeFrostChest': chest,
  'artifacts': [
    {'id': 'boots', 'name': 'Сапоги', 'price': 135, 'rarity': 'RARE'},
  ],
  'inventory': inventory,
  'recentDays': <Object>[],
};

Map<String, dynamic> _chest({int completed = 0}) => {
  'id': 'chest-1',
  'principal_amount': 20,
  'bonus_amount': 2,
  'required_active_days': 5,
  'completed_days': completed,
  'maturity_days': 5,
  'days_remaining': 5 - completed,
  'matured': completed >= 5,
};

Map<String, dynamic> _item(
  String id,
  String itemId, {
  int durability = 100,
  int max = 100,
  int repairCost = 0,
}) => {
  'id': id,
  'item_id': itemId,
  'name': itemId,
  'durability_current': durability,
  'durability_max': max,
  'is_broken': durability == 0,
  'is_wearable': const {'shield', 'boots', 'purse'}.contains(itemId),
  'repair_cost': repairCost,
  'usable': itemId == 'vial' && durability > 0,
  'equipped': false,
};

Map<String, dynamic> _park(String stage, {String? scene}) => {
  'stage': stage,
  'scene': scene ?? stage,
  'targetAmount': 100,
  'collectedAmount': 80,
  'offerAmount': stage == 'FIRST_OFFER'
      ? 20
      : stage == 'SECOND_OFFER'
      ? 8
      : null,
  'childContribution': 0,
  'completed': false,
};

void main() {
  var ids = 0;
  final economy = OfflineEconomy(nextId: (kind) => 'offline-$kind-${++ids}');
  Matcher refusedWith(String code) =>
      isA<ApiException>().having((e) => e.code, 'code', code);

  group('insurance', () {
    test('a policy for tomorrow costs the premium and counts as need', () {
      final outcome = economy.apply('POST', '/insurance/purchase', {
        'idempotencyKey': 'ins-1',
      }, _state(remainingReserve: 10));
      final day = outcome.state!['activeDay'] as Map;
      expect(outcome.state!['wallets']['SPENDABLE'], 35);
      expect(day['remaining_reserve'], 5);
      expect(outcome.state!['activeInsurance']['coverage_sequence_no'], 4);
      expect(outcome.response['policyId'], outcome.createdId);
    });

    test('only one policy per next day', () {
      final once = economy
          .apply('POST', '/insurance/purchase', {}, _state())
          .state!;
      expect(
        () => economy.apply('POST', '/insurance/purchase', {}, once),
        throwsA(refusedWith('insurance_already_purchased_for_next_day')),
      );
    });

    test('the next offline day uses up the policy', () {
      var state = economy
          .apply('POST', '/insurance/purchase', {}, _state())
          .state!;
      state = economy.apply('POST', '/periods/d1/close', null, state).state!;
      state['recentDays'] = [
        {'sequence_no': 3},
      ];
      state['activeGoal'] = {'id': 'g', 'target_amount': 80};
      final next = economy.apply('POST', '/periods', null, state);
      expect(next.state!['activeInsurance'], isNull);
    });
  });

  group('Morozko chest', () {
    test('opening freezes coins with a 10% bonus after five days', () {
      final outcome = economy.apply('POST', '/frost-chests', {
        'principalAmount': 20,
        'idempotencyKey': 'frost-1',
      }, _state());
      final chest = outcome.state!['activeFrostChest'] as Map;
      expect(outcome.state!['wallets']['SPENDABLE'], 20);
      expect(outcome.state!['wallets']['FROZEN'], 20);
      expect(chest['bonus_amount'], 2);
      expect(chest['days_remaining'], 5);
      expect(outcome.response['id'], outcome.createdId);
    });

    test('amounts follow the 10–50 step-10 rule and the food reserve', () {
      expect(
        () => economy.apply('POST', '/frost-chests', {
          'principalAmount': 15,
        }, _state()),
        throwsA(refusedWith('invalid_frost_principal')),
      );
      expect(
        () => economy.apply('POST', '/frost-chests', {
          'principalAmount': 40,
        }, _state(remainingReserve: 10)),
        throwsA(refusedWith('food_reserve_is_unavailable_for_frost')),
      );
      expect(
        () => economy.apply('POST', '/frost-chests', {
          'principalAmount': 10,
        }, _state(chest: _chest())),
        throwsA(refusedWith('chest_already_active')),
      );
    });

    test('closed days ripen the chest; ripe chests pay the bonus', () {
      var state = _state(frozen: 20, chest: _chest(completed: 4));
      state = economy.apply('POST', '/periods/d1/close', null, state).state!;
      final chest = state['activeFrostChest'] as Map;
      expect(chest['matured'], isTrue);
      expect(chest['days_remaining'], 0);

      final collected = economy.apply(
        'POST',
        '/frost-chests/chest-1/collect',
        null,
        state,
      );
      expect(collected.state!['wallets']['SPENDABLE'], 40 + 20 + 2);
      expect(collected.state!['wallets']['FROZEN'], 0);
      expect(collected.state!['activeFrostChest'], isNull);
    });

    test('early withdrawal returns only the principal', () {
      final outcome = economy.apply(
        'POST',
        '/frost-chests/chest-1/withdraw-early',
        null,
        _state(frozen: 20, chest: _chest(completed: 2)),
      );
      expect(outcome.state!['wallets']['SPENDABLE'], 60);
      expect(outcome.response['bonusForfeited'], isTrue);
      expect(
        () => economy.apply(
          'POST',
          '/frost-chests/chest-1/collect',
          null,
          _state(frozen: 20, chest: _chest(completed: 2)),
        ),
        throwsA(refusedWith('chest_not_matured_yet')),
      );
    });
  });

  group('artifacts', () {
    test('wearing marks one item and the pet', () {
      final outcome = economy.apply(
        'POST',
        '/pet/equip',
        {'inventoryItemId': 'i-boots'},
        _state(inventory: [_item('i-boots', 'boots'), _item('i-vial', 'vial')]),
      );
      final items = outcome.state!['inventory'] as List;
      expect(items.first['equipped'], isTrue);
      expect(items.last['equipped'], isFalse);
      expect(outcome.state!['pet']['equipped_inventory_item_id'], 'i-boots');
    });

    test('a vial cannot be worn, a broken item cannot be worn', () {
      expect(
        () => economy.apply('POST', '/pet/equip', {
          'inventoryItemId': 'i-vial',
        }, _state(inventory: [_item('i-vial', 'vial')])),
        throwsA(refusedWith('artifact_not_wearable')),
      );
      expect(
        () => economy.apply('POST', '/pet/equip', {
          'inventoryItemId': 'i-boots',
        }, _state(inventory: [_item('i-boots', 'boots', durability: 0)])),
        throwsA(refusedWith('artifact_is_broken')),
      );
    });

    test('repair costs coins and restores durability', () {
      final outcome = economy.apply(
        'POST',
        '/inventory/i-boots/repair',
        null,
        _state(
          inventory: [
            _item('i-boots', 'boots', durability: 40, repairCost: 12),
          ],
        ),
      );
      final item = (outcome.state!['inventory'] as List).first as Map;
      expect(outcome.state!['wallets']['SPENDABLE'], 28);
      expect(item['durability_current'], 100);
      expect(item['repair_cost'], 0);
    });

    test('living water fills energy and is used up', () {
      final outcome = economy.apply(
        'POST',
        '/inventory/i-vial/use',
        null,
        _state(inventory: [_item('i-vial', 'vial', durability: 1, max: 1)]),
      );
      final vial = (outcome.state!['inventory'] as List).first as Map;
      expect(outcome.state!['pet']['energy_level'], 100);
      expect(vial['is_broken'], isTrue);
      expect(vial['usable'], isFalse);
    });

    test('a saved-up dream becomes an inventory item', () {
      final outcome = economy.apply(
        'POST',
        '/goals/g1/redeem',
        null,
        _state(
          savings: 140,
          goal: {
            'id': 'g1',
            'target_item_id': 'boots',
            'target_amount': 135,
            'name': 'Сапоги',
          },
        ),
      );
      final item = (outcome.state!['inventory'] as List).first as Map;
      expect(outcome.state!['wallets']['SAVINGS'], 5);
      expect(outcome.state!['activeGoal'], isNull);
      expect(outcome.state!['artifacts'], isEmpty);
      expect(item['item_id'], 'boots');
      expect(item['id'], outcome.createdId);
    });
  });

  test('paying a pet event heals the pet from the need reserve', () {
    final outcome = economy.apply(
      'POST',
      '/pet-events/e1/resolve',
      null,
      _state(remainingReserve: 10, event: {'id': 'e1', 'amount_due': 8}),
    );
    expect(outcome.state!['wallets']['SPENDABLE'], 32);
    expect(outcome.state!['pet']['health_level'], 100);
    expect(outcome.state!['activeEvent'], isNull);
    expect((outcome.state!['activeDay'] as Map)['remaining_reserve'], 2);
  });

  group('park', () {
    test('contributing funds the park and spends the coins', () {
      final outcome = economy.apply(
        'POST',
        '/park-project/decision',
        {'offer': 'FIRST', 'decision': 'CONTRIBUTE'},
        _state(),
        cachedPark: _park('FIRST_OFFER'),
      );
      expect(outcome.state!['wallets']['SPENDABLE'], 20);
      expect(outcome.park!['stage'], 'FUNDED');
      expect(outcome.park!['collectedAmount'], 100);
      expect(outcome.park!['childContribution'], 20);
    });

    test('a contribution may not use the food reserve', () {
      expect(
        () => economy.apply(
          'POST',
          '/park-project/decision',
          {'offer': 'FIRST', 'decision': 'CONTRIBUTE'},
          _state(spendable: 25, remainingReserve: 10),
          cachedPark: _park('FIRST_OFFER'),
        ),
        throwsA(refusedWith('park_contribution_would_use_need_reserve')),
      );
    });

    test('days move a declined park the way the server does', () {
      final declined = economy.apply(
        'POST',
        '/park-project/decision',
        {'offer': 'FIRST', 'decision': 'DECLINE'},
        _state(),
        cachedPark: _park('FIRST_OFFER'),
      );
      expect(declined.park!['stage'], 'WAITING_SECOND');

      var park = declined.park!;
      final scenes = <String>[];
      for (var day = 0; day < 5; day++) {
        park = economy
            .apply(
              'POST',
              '/periods/d1/close',
              null,
              _state(),
              cachedPark: park,
            )
            .park!;
        scenes.add(park['scene'] as String);
      }
      expect(scenes, [
        'SECOND_OFFER',
        'FUNDED',
        'BUILDING',
        'ALMOST_READY',
        'OPEN',
      ]);

      final opened = economy.apply(
        'POST',
        '/park-project/complete',
        {},
        _state(),
        cachedPark: park,
      );
      expect(opened.park!['completed'], isTrue);
    });

    test('a park view without a cache needs the network', () {
      expect(
        () => economy.apply('POST', '/park-project/complete', {}, _state()),
        throwsA(
          isA<ApiException>().having((e) => e.isNetworkError, 'net', true),
        ),
      );
    });
  });
}
