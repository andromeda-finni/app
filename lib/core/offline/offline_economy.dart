import 'dart:convert';
import 'dart:math' as math;

import '../api_client.dart';

/// Thrown after an action that has no local preview (a quest answer) was
/// saved in the queue: the caller shows "saved, will be sent later".
const kSavedOfflineCode = 'saved_offline';

/// Prefix of identifiers the device invents while offline. The sync replaces
/// them with the server's ids once the creating request has gone through.
const kOfflineIdPrefix = 'offline-';

/// The result of applying one action to the cached economy without a server.
class OfflineOutcome {
  const OfflineOutcome({
    required this.response,
    this.state,
    this.park,
    this.daily,
    this.createdId,
    this.previewReward,
    this.label = 'Действие',
    this.queue = true,
    this.saveOnly = false,
  });

  /// What the caller receives instead of the server's answer.
  final Map<String, dynamic> response;

  /// The cached `/economy/state` after the action; null when unchanged.
  final Map<String, dynamic>? state;

  /// The cached `/park-project` view after the action; null when unchanged.
  final Map<String, dynamic>? park;

  /// The cached `/quests/day` offers after the action; null when unchanged.
  final Map<String, dynamic>? daily;

  /// Coins credited ahead of the server for a completed quest. If the server
  /// later does not confirm the completion, the child is told why they left.
  final int? previewReward;

  /// An offline id this action creates (a day, an assignment); the sync maps
  /// it to the id the server returns.
  final String? createdId;

  /// Child-facing name used if the server later refuses the action.
  final String label;

  /// False when nothing has to reach the server (e.g. an already completed
  /// quest).
  final bool queue;

  /// True when there is no local preview: the action is queued and the
  /// caller gets [kSavedOfflineCode].
  final bool saveOnly;
}

/// Local preview of the economy's core loop, used while the server is
/// unreachable.
///
/// The server stays authoritative: every action applied here is also queued
/// and replayed against the real API when the connection returns, after which
/// the server's state replaces this preview. The rules below mirror the
/// server's main checks so a child is not shown something the server is
/// certain to refuse; effects the server decides by chance or history
/// (random events, artifact abilities, pet growth streaks) are left to it.
class OfflineEconomy {
  OfflineEconomy({required this.nextId, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Produces a fresh offline id with the given kind, e.g. `offline-day-3`.
  final String Function(String kind) nextId;
  final DateTime Function() _clock;

  static final _periodPlan = RegExp(r'^/periods/([^/]+)/budget-plan$');
  static final _periodConfirm = RegExp(
    r'^/periods/([^/]+)/budget-plan/confirm$',
  );
  static final _periodClose = RegExp(r'^/periods/([^/]+)/close$');
  static final _savings = RegExp(r'^/savings/(deposit|withdraw)$');
  static final _questStart = RegExp(r'^/quests/([^/]+)/start$');
  static final _answer = RegExp(r'^/assignments/([^/]+)/answer$');
  static final _frost = RegExp(
    r'^/frost-chests/([^/]+)/(collect|withdraw-early)$',
  );
  static final _inventory = RegExp(r'^/inventory/([^/]+)/(repair|use)$');
  static final _redeem = RegExp(r'^/goals/([^/]+)/redeem$');
  static final _resolveEvent = RegExp(r'^/pet-events/([^/]+)/resolve$');

  static const _wearable = {'shield', 'boots', 'purse'};
  static const _petHealthFull = 100;
  static const _maxEnergy = 100;
  static const _parkTarget = 100;

  /// Whether [method] [path] can be done offline at all.
  static bool supports(String method, String path) {
    if (method == 'POST') {
      return path == '/periods' ||
          path == '/purchases' ||
          path == '/pet/stroke' ||
          _periodConfirm.hasMatch(path) ||
          _periodClose.hasMatch(path) ||
          _savings.hasMatch(path) ||
          _questStart.hasMatch(path) ||
          _answer.hasMatch(path) ||
          path == '/insurance/purchase' ||
          path == '/frost-chests' ||
          _frost.hasMatch(path) ||
          path == '/pet/equip' ||
          _inventory.hasMatch(path) ||
          _redeem.hasMatch(path) ||
          _resolveEvent.hasMatch(path) ||
          path == '/goals' ||
          path == '/park-project/decision' ||
          path == '/park-project/complete';
    }
    if (method == 'PUT') return _periodPlan.hasMatch(path);
    return false;
  }

  /// Applies one action to a copy of [cachedState]. Throws [ApiException]
  /// with the server's own error code when the server would refuse it, so
  /// the screens show the same messages as online.
  OfflineOutcome apply(
    String method,
    String path,
    Map<String, dynamic>? body,
    Map<String, dynamic>? cachedState, {
    Map<String, dynamic>? cachedPark,
    Map<String, dynamic>? cachedDaily,
  }) {
    final answer = _answer.firstMatch(path);
    if (answer != null) {
      return _answerQuest(
        answer.group(1)!,
        body ?? const {},
        cachedState == null ? null : _copy(cachedState),
        cachedDaily == null ? null : _copy(cachedDaily),
      );
    }
    final questStart = _questStart.firstMatch(path);
    if (questStart != null) {
      return _startQuest(
        questStart.group(1)!,
        cachedState == null ? null : _copy(cachedState),
        cachedDaily == null ? null : _copy(cachedDaily),
      );
    }

    if (cachedState == null) {
      // Nothing to preview against: the screen keeps its usual offline error.
      throw ApiException(0, 'network_error');
    }
    final state = _copy(cachedState);
    if (path == '/periods') return _startDay(state);
    if (path == '/purchases') return _purchase(state, body ?? const {});
    if (path == '/pet/stroke') return _stroke(state);
    final plan = _periodPlan.firstMatch(path);
    if (plan != null && method == 'PUT') {
      return _editPlan(state, plan.group(1)!, body ?? const {});
    }
    final confirm = _periodConfirm.firstMatch(path);
    if (confirm != null) return _confirmPlan(state, confirm.group(1)!);
    final close = _periodClose.firstMatch(path);
    if (close != null) {
      return _closeDay(
        state,
        close.group(1)!,
        cachedPark == null ? null : _copy(cachedPark),
      );
    }
    final savings = _savings.firstMatch(path);
    if (savings != null) {
      return _transfer(state, savings.group(1)!, body ?? const {});
    }
    final input = body ?? const <String, dynamic>{};
    if (path == '/goals') return _chooseGoal(state, input);
    if (path == '/insurance/purchase') return _buyInsurance(state);
    if (path == '/frost-chests') return _openFrost(state, input);
    final frost = _frost.firstMatch(path);
    if (frost != null) {
      return _closeFrost(state, frost.group(1)!, frost.group(2) == 'collect');
    }
    if (path == '/pet/equip') return _equip(state, input);
    final inventory = _inventory.firstMatch(path);
    if (inventory != null) {
      return inventory.group(2) == 'repair'
          ? _repair(state, inventory.group(1)!)
          : _useVial(state, inventory.group(1)!);
    }
    final redeem = _redeem.firstMatch(path);
    if (redeem != null) return _redeemGoal(state, redeem.group(1)!);
    final event = _resolveEvent.firstMatch(path);
    if (event != null) return _payEvent(state, event.group(1)!);
    if (path.startsWith('/park-project/')) {
      if (cachedPark == null) throw ApiException(0, 'network_error');
      final park = _copy(cachedPark);
      return path == '/park-project/decision'
          ? _parkDecision(state, park, input)
          : _parkComplete(park);
    }
    throw ApiException(0, 'network_error');
  }

  /// A remembered park view with the wallet as it is now, not as it was
  /// when the view was loaded.
  static Map<String, dynamic> refreshPark(
    Map<String, dynamic> park,
    Map<String, dynamic>? state,
  ) {
    if (state == null) return park;
    final view = _copy(park);
    _setParkMoney(view, state);
    return view;
  }

  OfflineOutcome _chooseGoal(
    Map<String, dynamic> state,
    Map<String, dynamic> body,
  ) {
    final itemId = body['targetItemId'];
    final current = state['activeGoal'];
    if (current is Map && current['target_item_id'] == itemId) {
      return OfflineOutcome(
        queue: false,
        response: {
          'id': current['id'],
          'targetAmount': current['target_amount'],
          'replayed': true,
        },
      );
    }
    if (current != null) throw ApiException(409, 'goal_change_not_allowed');
    final owned = _list(state['inventory'])
        .map(_map)
        .any((item) => item['item_id'] == itemId);
    if (owned) throw ApiException(409, 'artifact_already_owned');
    final artifact = _list(state['artifacts'])
        .map(_map)
        .where((entry) => entry['id'] == itemId)
        .firstOrNull;
    if (artifact == null) throw ApiException(404, 'artifact_not_found');

    final price = _int(artifact['price']);
    final saved = _int(_map(state['wallets'])['SAVINGS']);
    final goalId = nextId('goal');
    state['activeGoal'] = {
      'id': goalId,
      'target_item_id': itemId,
      'target_amount': price,
      'status': saved >= price ? 'ACHIEVED' : 'ACTIVE',
      'name': artifact['name'],
      'saved_amount': saved,
      'remaining_amount': math.max(0, price - saved),
    };
    return OfflineOutcome(
      state: state,
      createdId: goalId,
      label: 'Выбор мечты «${artifact['name'] ?? itemId}»',
      response: {'id': goalId, 'targetAmount': price, 'replayed': false},
    );
  }

  OfflineOutcome _buyInsurance(Map<String, dynamic> state) {
    final day = _confirmedDay(state);
    final coverage = _int(day['sequence_no']) + 1;
    final current = state['activeInsurance'];
    if (current is Map && _int(current['coverage_sequence_no']) == coverage) {
      throw ApiException(409, 'insurance_already_purchased_for_next_day');
    }
    final premium = _int(_map(state['rules'])['insurancePremium'], 5);
    _spend(state, premium);
    _countAsNeed(day, premium);
    final policyId = nextId('policy');
    state['activeInsurance'] = {
      'id': policyId,
      'coverage_sequence_no': coverage,
      'premium_amount': premium,
      'status': 'ACTIVE',
      'covered_event_definition_id': null,
    };
    return OfflineOutcome(
      state: state,
      createdId: policyId,
      label: 'Страховка',
      response: {
        'policyId': policyId,
        'coverageSequence': coverage,
        'premium': premium,
        'balanceAfter': _wallets(state)['SPENDABLE'],
        'replayed': false,
      },
    );
  }

  OfflineOutcome _openFrost(
    Map<String, dynamic> state,
    Map<String, dynamic> body,
  ) {
    final rules = _map(state['rules']);
    final principal = _int(body['principalAmount']);
    final step = math.max(1, _int(rules['frostStep'], 10));
    if (principal < _int(rules['frostMinimum'], 10) ||
        principal > _int(rules['frostMaximum'], 50) ||
        principal % step != 0) {
      throw ApiException(400, 'invalid_frost_principal');
    }
    final day = _confirmedDay(state);
    if (state['activeFrostChest'] != null) {
      throw ApiException(409, 'chest_already_active');
    }
    final wallets = _wallets(state);
    if (_int(wallets['SPENDABLE']) - principal <
        _int(day['remaining_reserve'])) {
      throw ApiException(409, 'food_reserve_is_unavailable_for_frost');
    }
    _move(state, from: 'SPENDABLE', to: 'FROZEN', amount: principal);
    final bonus = (principal * _int(rules['frostBonusPercent'], 10) / 100)
        .ceil();
    final days = _int(rules['frostDays'], 5);
    final chestId = nextId('chest');
    state['activeFrostChest'] = {
      'id': chestId,
      'principal_amount': principal,
      'bonus_amount': bonus,
      'opened_at': _clock().toUtc().toIso8601String(),
      'required_active_days': days,
      'completed_days': 0,
      'maturity_days': days,
      'days_remaining': days,
      'matured': false,
    };
    return OfflineOutcome(
      state: state,
      createdId: chestId,
      label: 'Сундук Морозко',
      response: {
        'id': chestId,
        'principalAmount': principal,
        'bonusAmount': bonus,
        'maturityDays': days,
        'replayed': false,
      },
    );
  }

  OfflineOutcome _closeFrost(
    Map<String, dynamic> state,
    String chestId,
    bool collect,
  ) {
    final chest = state['activeFrostChest'];
    if (chest is! Map<String, dynamic> || chest['id'] != chestId) {
      throw ApiException(404, 'active_chest_not_found');
    }
    final matured = chest['matured'] == true;
    if (collect && !matured) throw ApiException(400, 'chest_not_matured_yet');
    if (!collect && matured) {
      throw ApiException(400, 'chest_already_matured_use_collect');
    }
    final principal = _int(chest['principal_amount']);
    final bonus = collect ? _int(chest['bonus_amount']) : 0;
    _move(state, from: 'FROZEN', to: 'SPENDABLE', amount: principal);
    final wallets = _wallets(state);
    wallets['SPENDABLE'] = _int(wallets['SPENDABLE']) + bonus;
    state['activeFrostChest'] = null;
    return OfflineOutcome(
      state: state,
      label: collect ? 'Сундук Морозко' : 'Досрочное открытие сундука',
      response: {
        'ok': true,
        'principalReturned': principal,
        if (collect) 'bonusAwarded': bonus else 'bonusForfeited': true,
      },
    );
  }

  OfflineOutcome _equip(Map<String, dynamic> state, Map<String, dynamic> body) {
    final id = body['inventoryItemId'] as String?;
    final items = _inventoryItems(state);
    if (id != null) {
      final item = items.where((entry) => entry['id'] == id).firstOrNull;
      if (item == null) throw ApiException(403, 'item_not_owned');
      if (!_wearable.contains(item['item_id'])) {
        throw ApiException(400, 'artifact_not_wearable');
      }
      if (item['is_broken'] == true || _int(item['durability_current']) == 0) {
        throw ApiException(409, 'artifact_is_broken');
      }
    }
    for (final item in items) {
      item['equipped'] = id != null && item['id'] == id;
    }
    final pet = _map(state['pet']);
    pet['equipped_inventory_item_id'] = id;
    state['pet'] = pet;
    return OfflineOutcome(
      state: state,
      label: id == null ? 'Снять артефакт' : 'Надеть артефакт',
      response: {'ok': true, 'equippedInventoryItemId': id},
    );
  }

  OfflineOutcome _repair(Map<String, dynamic> state, String itemId) {
    final item = _inventoryItem(state, itemId);
    final cost = _int(item['repair_cost']);
    if (cost == 0) throw ApiException(409, 'artifact_not_damaged');
    _spend(state, cost);
    item['durability_current'] = item['durability_max'];
    item['is_broken'] = false;
    item['repair_cost'] = 0;
    item['usable'] = item['item_id'] == 'vial';
    return OfflineOutcome(
      state: state,
      label: 'Починка «${item['name'] ?? 'артефакта'}»',
      response: {
        'ok': true,
        'repairCost': cost,
        'durabilityCurrent': item['durability_max'],
        'durabilityMax': item['durability_max'],
        'balanceAfter': _wallets(state)['SPENDABLE'],
      },
    );
  }

  OfflineOutcome _useVial(Map<String, dynamic> state, String itemId) {
    final item = _inventoryItem(state, itemId);
    if (item['item_id'] != 'vial') {
      throw ApiException(409, 'inventory_item_not_usable');
    }
    final durability = _int(item['durability_current']);
    if (item['is_broken'] == true || durability == 0) {
      throw ApiException(409, 'artifact_is_broken');
    }
    final after = durability - 1;
    item['durability_current'] = after;
    item['is_broken'] = after == 0;
    item['usable'] = after > 0;
    if (after < _int(item['durability_max'])) item['repair_cost'] = 100;
    final pet = _map(state['pet']);
    pet['energy_level'] = _maxEnergy;
    pet['energy_depleted_at'] = null;
    state['pet'] = pet;
    return OfflineOutcome(
      state: state,
      label: 'Живая вода',
      response: {'ok': true, 'pet': pet},
    );
  }

  OfflineOutcome _redeemGoal(Map<String, dynamic> state, String goalId) {
    final goal = state['activeGoal'];
    if (goal is! Map<String, dynamic> || goal['id'] != goalId) {
      throw ApiException(404, 'achieved_goal_not_found');
    }
    _confirmedDay(state);
    final price = _int(goal['target_amount']);
    final wallets = _wallets(state);
    final saved = _int(wallets['SAVINGS']);
    if (saved < price) throw ApiException(409, 'insufficient_funds');
    wallets['SAVINGS'] = saved - price;

    final artifactId = goal['target_item_id'];
    final artifacts = _list(state['artifacts']).map(_map).toList();
    final artifact = artifacts
        .where((entry) => entry['id'] == artifactId)
        .firstOrNull;
    final durability = artifactId == 'vial' ? 1 : 100;
    final inventoryId = nextId('item');
    state['inventory'] = [
      {
        'id': inventoryId,
        'item_id': artifactId,
        'name': goal['name'] ?? artifact?['name'],
        'rarity': artifact?['rarity'],
        'effect_code': artifact?['effect_code'],
        'durability_current': durability,
        'durability_max': durability,
        'is_broken': false,
        'is_wearable': _wearable.contains(artifactId),
        'repair_cost': 0,
        'usable': artifactId == 'vial',
        'equipped': false,
      },
      ..._list(state['inventory']),
    ];
    state['artifacts'] = [
      for (final entry in artifacts)
        if (entry['id'] != artifactId) entry,
    ];
    state['activeGoal'] = null;
    return OfflineOutcome(
      state: state,
      createdId: inventoryId,
      label: 'Получение мечты',
      response: {'ok': true, 'inventoryItemId': inventoryId},
    );
  }

  OfflineOutcome _payEvent(Map<String, dynamic> state, String eventId) {
    final event = state['activeEvent'];
    if (event is! Map || event['id'] != eventId) {
      throw ApiException(404, 'active_event_not_found');
    }
    final amount = _int(event['amount_due']);
    _spend(state, amount);
    final day = state['activeDay'];
    if (day is Map<String, dynamic>) _countAsNeed(day, amount);
    state['activeEvent'] = null;
    final pet = _map(state['pet']);
    pet['health_level'] = _petHealthFull;
    state['pet'] = pet;
    return OfflineOutcome(
      state: state,
      label: 'Помощь питомцу',
      response: {
        'ok': true,
        'paidFromSavings': false,
        'spendableBalance': _wallets(state)['SPENDABLE'],
        'healthLevel': _petHealthFull,
      },
    );
  }

  OfflineOutcome _parkDecision(
    Map<String, dynamic> state,
    Map<String, dynamic> park,
    Map<String, dynamic> body,
  ) {
    final first = body['offer'] == 'FIRST';
    final contribute = body['decision'] == 'CONTRIBUTE';
    if (park['stage'] != (first ? 'FIRST_OFFER' : 'SECOND_OFFER')) {
      throw ApiException(409, 'park_offer_changed');
    }
    final amount = first ? 20 : 8;
    if (contribute) {
      if (_parkAvailable(state) < amount) {
        throw ApiException(409, 'park_contribution_would_use_need_reserve');
      }
      _spend(state, amount);
      park['childContribution'] = _int(park['childContribution']) + amount;
    }
    _setParkStage(
      park,
      contribute
          ? 'FUNDED'
          : first
          ? 'WAITING_SECOND'
          : 'WAITING_COMMUNITY',
    );
    _setParkMoney(park, state);
    return OfflineOutcome(
      state: state,
      park: park,
      label: 'Решение о парке',
      response: {...park, 'replayed': false},
    );
  }

  OfflineOutcome _parkComplete(Map<String, dynamic> park) {
    if (park['scene'] != 'OPEN') throw ApiException(409, 'park_not_open_yet');
    park['stage'] = 'COMPLETE';
    park['completed'] = true;
    park['daysToNextStage'] = null;
    return OfflineOutcome(
      park: park,
      label: 'Открытие парка',
      response: {...park, 'replayed': false},
    );
  }

  /// One completed day moves the park forward the way the server's
  /// `advanceProject` does.
  static void _advanceParkByDay(Map<String, dynamic> park) {
    switch (park['stage']) {
      case 'WAITING_SECOND':
        _setParkStage(park, 'SECOND_OFFER');
      case 'SECOND_OFFER' || 'WAITING_COMMUNITY':
        _setParkStage(park, 'FUNDED');
      case 'FUNDED':
        const building = ['FUNDED', 'BUILDING', 'ALMOST_READY', 'OPEN'];
        final next = math.min(
          building.indexOf(park['scene'] as String? ?? 'FUNDED') + 1,
          building.length - 1,
        );
        park['scene'] = building[next];
        park['daysToNextStage'] = park['scene'] == 'OPEN' ? null : 1;
    }
  }

  static void _setParkStage(Map<String, dynamic> park, String stage) {
    park['stage'] = stage;
    park['scene'] = stage;
    park['offerAmount'] = switch (stage) {
      'FIRST_OFFER' => 20,
      'SECOND_OFFER' => 8,
      _ => null,
    };
    park['collectedAmount'] = switch (stage) {
      'FIRST_OFFER' || 'WAITING_SECOND' => 80,
      'SECOND_OFFER' => 92,
      _ => _parkTarget,
    };
    park['daysToNextStage'] =
        stage == 'FUNDED' ||
            stage == 'WAITING_SECOND' ||
            stage == 'WAITING_COMMUNITY'
        ? 1
        : null;
  }

  static int _parkAvailable(Map<String, dynamic> state) {
    final day = state['activeDay'];
    final reserve = day is Map ? _int(day['remaining_reserve']) : 0;
    return math.max(0, _int(_map(state['wallets'])['SPENDABLE']) - reserve);
  }

  static void _setParkMoney(
    Map<String, dynamic> park,
    Map<String, dynamic> state,
  ) {
    final available = _parkAvailable(state);
    final offer = park['offerAmount'];
    park['spendableBalance'] = _int(_map(state['wallets'])['SPENDABLE']);
    park['availableToContribute'] = available;
    park['canContribute'] = offer is num && available >= offer;
  }

  List<Map<String, dynamic>> _inventoryItems(Map<String, dynamic> state) {
    final items = _list(state['inventory']).map(_map).toList();
    state['inventory'] = items;
    return items;
  }

  Map<String, dynamic> _inventoryItem(Map<String, dynamic> state, String id) {
    final item = _inventoryItems(state)
        .where((entry) => entry['id'] == id)
        .firstOrNull;
    if (item == null) throw ApiException(404, 'inventory_item_not_found');
    return item;
  }

  /// Takes coins from the wallet, refusing like the server's ledger does.
  void _spend(Map<String, dynamic> state, int amount) {
    final wallets = _wallets(state);
    final balance = _int(wallets['SPENDABLE']);
    if (balance < amount) throw ApiException(409, 'insufficient_funds');
    wallets['SPENDABLE'] = balance - amount;
  }

  /// Event bills and insurance premiums count as the day's required spending.
  static void _countAsNeed(Map<String, dynamic> day, int amount) {
    final actualNeed = _int(day['actual_need_amount']) + amount;
    day['actual_need_amount'] = actualNeed;
    day['remaining_reserve'] = math.max(
      0,
      _int(day['required_need_amount']) - actualNeed,
    );
  }

  OfflineOutcome _startDay(Map<String, dynamic> state) {
    if (state['activeDay'] != null) {
      throw ApiException(409, 'period_already_active');
    }
    if (state['activeGoal'] == null) {
      throw ApiException(409, 'financial_goal_required');
    }
    final rules = _map(state['rules']);
    final income = _int(rules['dailyIncome'], 30);
    final reserve = _int(rules['foodReserve'], 10);
    final daysPerWeek = math.max(1, _int(rules['daysPerWeek'], 7));
    final sequence = _lastSequence(state) + 1;
    final wallets = _wallets(state);
    wallets['SPENDABLE'] = _int(wallets['SPENDABLE']) + income;
    final insurance = state['activeInsurance'];
    if (insurance is Map &&
        _int(insurance['coverage_sequence_no']) <= sequence) {
      // The policy covered this day's random event, which only the server
      // rolls; from here on it is no longer "for the next day".
      state['activeInsurance'] = null;
    }
    final dayId = nextId('day');
    state['activeDay'] = {
      'id': dayId,
      'sequence_no': sequence,
      'required_need_amount': reserve,
      'budget_plan_id': nextId('plan'),
      'budget_plan_status': 'DRAFT',
      'available_amount': income,
      'need_amount': 0,
      'want_amount': 0,
      'savings_amount': 0,
      'actual_need_amount': 0,
      'remaining_reserve': reserve,
      'week': (sequence - 1) ~/ daysPerWeek + 1,
      'day_of_week': (sequence - 1) % daysPerWeek + 1,
      '_offline_actual_want': 0,
      '_offline_net_savings': 0,
    };
    return OfflineOutcome(
      state: state,
      createdId: dayId,
      label: 'Начало дня',
      response: {
        'periodId': dayId,
        'grantAmount': income,
        'balanceAfter': wallets['SPENDABLE'],
        'eventTriggered': false,
        'coveredByInsurance': false,
        'insuranceNotice': null,
        'artifactEffects': const <Object>[],
      },
    );
  }

  OfflineOutcome _editPlan(
    Map<String, dynamic> state,
    String dayId,
    Map<String, dynamic> body,
  ) {
    final day = _dayWithId(state, dayId);
    if (day == null || day['budget_plan_status'] != 'DRAFT') {
      throw ApiException(404, 'draft_budget_plan_not_found');
    }
    day['need_amount'] = _int(body['needAmount']);
    day['want_amount'] = _int(body['wantAmount']);
    day['savings_amount'] = _int(body['savingsAmount']);
    return OfflineOutcome(
      state: state,
      label: 'План дня',
      response: const {'ok': true},
    );
  }

  OfflineOutcome _confirmPlan(Map<String, dynamic> state, String dayId) {
    final day = _dayWithId(state, dayId);
    if (day == null) throw ApiException(404, 'draft_budget_plan_not_found');
    if (day['budget_plan_status'] == 'CONFIRMED') {
      return const OfflineOutcome(
        queue: false,
        response: {'ok': true, 'replayed': true},
      );
    }
    final need = _int(day['need_amount']);
    final want = _int(day['want_amount']);
    final savings = _int(day['savings_amount']);
    final required = _int(day['required_need_amount']);
    if (need + want + savings != _int(day['available_amount'])) {
      throw ApiException(400, 'plan_must_allocate_the_full_available_amount');
    }
    if (need < required) {
      throw ApiException(400, 'need_amount_must_be_at_least_$required');
    }
    if (savings > 0 && state['activeGoal'] == null) {
      throw ApiException(409, 'financial_goal_required');
    }
    day['budget_plan_status'] = 'CONFIRMED';
    _move(state, from: 'SPENDABLE', to: 'SAVINGS', amount: savings);
    day['_offline_net_savings'] = _int(day['_offline_net_savings']) + savings;
    return OfflineOutcome(
      state: state,
      label: 'План дня',
      response: const {'ok': true, 'replayed': false},
    );
  }

  OfflineOutcome _purchase(
    Map<String, dynamic> state,
    Map<String, dynamic> body,
  ) {
    final day = _confirmedDay(state);
    final itemId = body['itemId'];
    final item = _list(state['shopItems'])
        .map(_map)
        .where((candidate) => candidate['id'] == itemId)
        .firstOrNull;
    if (item == null) throw ApiException(404, 'item_not_found');
    final quantity = math.max(1, _int(body['quantity'], 1));
    final total = _int(item['price']) * quantity;
    final wallets = _wallets(state);
    final balance = _int(wallets['SPENDABLE']);
    final isNeed = item['kind'] == 'NEED';

    if (isNeed) {
      final eventReserve = _int(_map(state['activeEvent'])['amount_due']);
      if (balance - total < eventReserve) {
        throw ApiException(
          409,
          'active_event_reserve_is_unavailable_for_purchases',
          {'reserve': eventReserve},
        );
      }
    } else {
      final reserve = _int(day['remaining_reserve']);
      if (balance - total < reserve) {
        throw ApiException(409, 'food_reserve_is_unavailable_for_wants', {
          'reserve': reserve,
        });
      }
    }
    if (balance < total) throw ApiException(409, 'insufficient_funds');

    wallets['SPENDABLE'] = balance - total;
    if (isNeed) {
      final actualNeed = _int(day['actual_need_amount']) + total;
      day['actual_need_amount'] = actualNeed;
      day['remaining_reserve'] = math.max(
        0,
        _int(day['required_need_amount']) - actualNeed,
      );
    } else {
      day['_offline_actual_want'] = _int(day['_offline_actual_want']) + total;
    }
    final pet = _map(state['pet']);
    pet['energy_level'] = _clampStat(
      _int(pet['energy_level']) + _int(item['energy_delta']) * quantity,
    );
    pet['joy_level'] = _clampStat(
      _int(pet['joy_level']) + _int(item['joy_delta']) * quantity,
    );
    state['pet'] = pet;
    return OfflineOutcome(
      state: state,
      label: 'Покупка «${item['name'] ?? itemId}»',
      response: {
        'purchaseId': nextId('purchase'),
        'balanceAfter': wallets['SPENDABLE'],
        'pet': pet,
        'impulsive': false,
      },
    );
  }

  OfflineOutcome _transfer(
    Map<String, dynamic> state,
    String direction,
    Map<String, dynamic> body,
  ) {
    final amount = _int(body['amount']);
    final deposit = direction == 'deposit';
    if (deposit && state['activeGoal'] == null) {
      throw ApiException(409, 'financial_goal_required');
    }
    final day = _confirmedDay(state);
    final wallets = _wallets(state);
    if (deposit) {
      final reserve = _int(day['remaining_reserve']);
      if (_int(wallets['SPENDABLE']) - amount < reserve) {
        throw ApiException(409, 'food_reserve_is_unavailable_for_savings');
      }
    }
    _move(
      state,
      from: deposit ? 'SPENDABLE' : 'SAVINGS',
      to: deposit ? 'SAVINGS' : 'SPENDABLE',
      amount: amount,
    );
    day['_offline_net_savings'] =
        _int(day['_offline_net_savings']) + (deposit ? amount : -amount);
    return OfflineOutcome(
      state: state,
      label: deposit ? 'Перевод в копилку' : 'Возврат из копилки',
      response: {'ok': true, 'amount': amount},
    );
  }

  OfflineOutcome _closeDay(
    Map<String, dynamic> state,
    String dayId,
    Map<String, dynamic>? park,
  ) {
    final day = _dayWithId(state, dayId);
    if (day == null) throw ApiException(404, 'period_not_found');
    if (day['budget_plan_status'] != 'CONFIRMED') {
      throw ApiException(400, 'budget_plan_not_confirmed');
    }
    if (state['activeEvent'] != null) {
      throw ApiException(409, 'active_event_must_be_resolved');
    }
    final actualNeed = _int(day['actual_need_amount']);
    final actualWant = _int(day['_offline_actual_want']);
    final netSavings = _int(day['_offline_net_savings']);
    final needCovered = actualNeed >= _int(day['required_need_amount']);
    final planFollowed =
        needCovered &&
        actualNeed >= _int(day['need_amount']) &&
        actualWant <= _int(day['want_amount']) &&
        netSavings >= _int(day['savings_amount']);
    final petName = _map(state['pet'])['pet_name'] as String? ?? 'Питомец';
    final feedback = planFollowed
        ? 'Ты молодец! Сегодня мы уложились в план. $petName доволен и растёт.'
        : needCovered
        ? 'Сегодня план и действия немного разошлись. Завтра попробуем ещё раз.'
        : 'Сегодня план и действия немного разошлись. $petName ждёт заботы, '
              'а завтра попробуем ещё раз.';
    state['activeDay'] = null;
    // The server shows a policy only "for the day after the active one";
    // with no active day it is out of the read model until it is used.
    state['activeInsurance'] = null;
    final chest = state['activeFrostChest'];
    if (chest is Map<String, dynamic>) {
      final completed = _int(chest['completed_days']) + 1;
      final maturity = _int(chest['maturity_days'], 5);
      chest['completed_days'] = completed;
      chest['days_remaining'] = math.max(0, maturity - completed);
      chest['matured'] = completed >= maturity;
    }
    if (park != null) {
      _advanceParkByDay(park);
      _setParkMoney(park, state);
    }
    state['recentDays'] = [
      {
        'sequence_no': day['sequence_no'],
        'week': day['week'],
        'dayOfWeek': day['day_of_week'],
        'actual_need_amount': actualNeed,
        'actual_want_amount': actualWant,
        'net_savings_contribution': netSavings,
        'plan_followed': planFollowed,
        'feedback_text': feedback,
      },
      ..._list(state['recentDays']).take(6),
    ];
    return OfflineOutcome(
      state: state,
      park: park,
      label: 'Завершение дня',
      // Not a full day summary: the summary screen is skipped offline and
      // the home shows this day in its history instead.
      response: {'offline': true, 'feedback': feedback},
    );
  }

  /// Mirrors backend/src/modules/pet/stroke.ts: half a joy point, each stroke
  /// of a series worth 10% less, the series ends after ten quiet minutes.
  OfflineOutcome _stroke(Map<String, dynamic> state) {
    final pet = _map(state['pet']);
    final memory = _map(state['_offline_stroke']);
    final now = _clock().millisecondsSinceEpoch;
    final last = _int(memory['last'], -1);
    final continues = last >= 0 && now - last < 10 * 60 * 1000;
    final streak = continues ? _int(memory['streak']) : 0;
    final gain = 0.5 * math.pow(0.9, streak);
    final total =
        _int(pet['joy_level']) +
        ((memory['fraction'] as num?)?.toDouble() ?? 0) +
        gain;
    final joy = math.min(100, total.floor());
    pet['joy_level'] = joy;
    state['pet'] = pet;
    state['_offline_stroke'] = {
      'streak': streak + 1,
      'last': now,
      'fraction': joy >= 100 ? 0.0 : total - total.floor(),
    };
    return OfflineOutcome(
      state: state,
      label: 'Поглаживание',
      response: {...pet, 'joy_gain': gain},
    );
  }

  /// Starts one of today's quest offers. Offers are chosen by the server, so
  /// a quest can start offline only from the day's list loaded while online.
  OfflineOutcome _startQuest(
    String questId,
    Map<String, dynamic>? state,
    Map<String, dynamic>? daily,
  ) {
    final quest = _questEntry(state, questId);
    if (quest?['assignment_status'] == 'COMPLETED') {
      return OfflineOutcome(
        queue: false,
        response: {
          'completed': true,
          'rewardAlreadyGranted': true,
          'assignmentId': quest?['assignment_id'],
          'rewardAmount': quest?['reward_amount'],
        },
      );
    }
    if (state == null || daily == null) {
      throw ApiException(0, 'daily_quests_need_connection');
    }
    final day = state['activeDay'];
    // A day opened offline has no server-chosen offers yet.
    if (day is! Map ||
        daily['periodId'] == null ||
        day['id'] != daily['periodId']) {
      throw ApiException(0, 'daily_quests_need_connection');
    }
    _confirmedDay(state);
    final offer = _offers(daily)
        .where((entry) => entry['questId'] == questId)
        .firstOrNull;
    if (offer == null) throw ApiException(409, 'quest_not_offered_today');
    final reward = _int(offer['rewardAmount']);
    if (offer['status'] == 'COMPLETED') {
      return OfflineOutcome(
        queue: false,
        response: {
          'completed': true,
          'rewardAlreadyGranted': true,
          'assignmentId': offer['assignmentId'],
          'rewardAmount': reward,
        },
      );
    }
    if (offer['status'] == 'IN_PROGRESS' && offer['assignmentId'] is String) {
      return OfflineOutcome(
        queue: false,
        response: {
          'assignmentId': offer['assignmentId'],
          'rewardAmount': reward,
          'resumed': true,
          'nextStepNo': _int(offer['_offline_next_step'], 1),
        },
      );
    }

    // A new run costs energy, exactly once, like on the server.
    final pet = _map(state['pet']);
    final cost = _int(_map(pet['energy_recovery'])['activity_cost'], 20);
    final energy = _int(pet['energy_level']);
    if (energy < cost) {
      throw ApiException(409, 'pet_energy_insufficient', {
        'energyLevel': energy,
        'requiredEnergy': cost,
      });
    }
    pet['energy_level'] = energy - cost;
    state['pet'] = pet;
    final assignmentId = nextId('assignment');
    offer['status'] = 'IN_PROGRESS';
    offer['assignmentId'] = assignmentId;
    offer['_offline_next_step'] = 1;
    if (quest != null) {
      quest['assignment_status'] = 'IN_PROGRESS';
      quest['assignment_id'] = assignmentId;
    }
    return OfflineOutcome(
      state: state,
      daily: daily,
      createdId: assignmentId,
      label: 'Начало задания «${quest?['title'] ?? questId}»',
      response: {
        'assignmentId': assignmentId,
        'rewardAmount': reward,
        'resumed': false,
        'nextStepNo': 1,
        'pet': pet,
      },
    );
  }

  /// Records a mini-game result. The game sends it only after the child
  /// succeeded by its own rules, so the last step pays the offer's reward
  /// right away; the server re-checks every answer when the queue is sent.
  OfflineOutcome _answerQuest(
    String assignmentId,
    Map<String, dynamic> body,
    Map<String, dynamic>? state,
    Map<String, dynamic>? daily,
  ) {
    final offer = daily == null
        ? null
        : _offers(daily)
              .where((entry) => entry['assignmentId'] == assignmentId)
              .firstOrNull;
    final steps = _int(offer?['stepCount']);
    if (state == null || offer == null || steps <= 0) {
      // Not one of today's known offers: keep the result for the server.
      return const OfflineOutcome(
        response: {},
        label: 'Результат задания',
        saveOnly: true,
      );
    }
    final reward = _int(offer['rewardAmount']);
    final quest = _questEntry(state, offer['questId']);
    final title = quest?['title'] ?? 'задание';
    if (offer['status'] == 'COMPLETED') {
      return OfflineOutcome(
        queue: false,
        response: {
          'outcome': 'SUCCESS',
          'feedback': 'Результат уже сохранён.',
          'questCompleted': true,
          'rewardAmount': reward,
          'balanceAfter': _wallets(state)['SPENDABLE'],
          'rewardAlreadyGranted': true,
          'replayed': true,
        },
      );
    }
    final stepNo = math.max(1, _int(body['stepNo'], 1));
    if (stepNo < steps) {
      offer['_offline_next_step'] = math.max(
        _int(offer['_offline_next_step'], 1),
        stepNo + 1,
      );
      return OfflineOutcome(
        state: state,
        daily: daily,
        label: 'Результат задания «$title»',
        response: const {
          'outcome': 'SUCCESS',
          'feedback': '',
          'questCompleted': false,
        },
      );
    }

    final wallets = _wallets(state);
    wallets['SPENDABLE'] = _int(wallets['SPENDABLE']) + reward;
    offer['status'] = 'COMPLETED';
    if (quest != null) quest['assignment_status'] = 'COMPLETED';
    return OfflineOutcome(
      state: state,
      daily: daily,
      previewReward: reward,
      label: 'Награда за задание «$title»',
      response: {
        'outcome': 'SUCCESS',
        'feedback': 'Отлично! Награда уже в кошельке.',
        'questCompleted': true,
        'rewardAmount': reward,
        'balanceAfter': wallets['SPENDABLE'],
        'artifactEffects': const <Object>[],
      },
    );
  }

  Map<String, dynamic>? _questEntry(
    Map<String, dynamic>? state,
    Object? questId,
  ) =>
      _list(state?['quests'])
          .whereType<Map<String, dynamic>>()
          .where((q) => q['id'] == questId)
          .firstOrNull;

  List<Map<String, dynamic>> _offers(Map<String, dynamic> daily) {
    final offers = _list(daily['offers']).map(_map).toList();
    daily['offers'] = offers;
    return offers;
  }

  Map<String, dynamic> _confirmedDay(Map<String, dynamic> state) {
    final day = state['activeDay'];
    if (day is! Map<String, dynamic> ||
        day['budget_plan_status'] != 'CONFIRMED') {
      throw ApiException(409, 'active_day_with_confirmed_plan_required');
    }
    return day;
  }

  Map<String, dynamic>? _dayWithId(Map<String, dynamic> state, String id) {
    final day = state['activeDay'];
    return day is Map<String, dynamic> && day['id'] == id ? day : null;
  }

  int _lastSequence(Map<String, dynamic> state) {
    var last = 0;
    for (final day in _list(state['recentDays']).map(_map)) {
      last = math.max(last, _int(day['sequence_no']));
    }
    return last;
  }

  void _move(
    Map<String, dynamic> state, {
    required String from,
    required String to,
    required int amount,
  }) {
    if (amount <= 0) return;
    final wallets = _wallets(state);
    final available = _int(wallets[from]);
    if (available < amount) throw ApiException(409, 'insufficient_funds');
    wallets[from] = available - amount;
    wallets[to] = _int(wallets[to]) + amount;
    final goal = state['activeGoal'];
    if (goal is Map<String, dynamic>) {
      final saved = _int(wallets['SAVINGS']);
      final target = _int(goal['target_amount']);
      goal['saved_amount'] = saved;
      goal['remaining_amount'] = math.max(0, target - saved);
      // The server promotes the goal on every read once savings cover it.
      if (goal['status'] == 'ACTIVE' && saved >= target) {
        goal['status'] = 'ACHIEVED';
      }
    }
  }

  Map<String, dynamic> _wallets(Map<String, dynamic> state) {
    final wallets = _map(state['wallets']);
    state['wallets'] = wallets;
    return wallets;
  }

  static int _clampStat(int value) => value.clamp(0, 100);

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic>
      ? value
      : value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static int _int(Object? value, [int fallback = 0]) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? fallback;
}
