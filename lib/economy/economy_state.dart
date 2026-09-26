int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

const economyContractErrorMessage =
    'Не удалось загрузить правила игры. Попробуй ещё раз чуть позже.';

Map<String, dynamic>? _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;

List<Map<String, dynamic>> _asList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
    : const [];

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num &&
      value.isFinite &&
      value == value.toInt() &&
      value.toInt() > 0) {
    return value.toInt();
  }
  throw FormatException('Missing or invalid economy rule: $key');
}

final class EconomyRules {
  const EconomyRules({
    required this.dailyIncome,
    required this.foodReserve,
    required this.savingsTransferAmounts,
    required this.frostMinimum,
    required this.frostMaximum,
    required this.frostStep,
    required this.frostDays,
    required this.frostBonusPercent,
  });

  final int dailyIncome;
  final int foodReserve;
  final List<int> savingsTransferAmounts;
  final int frostMinimum;
  final int frostMaximum;
  final int frostStep;
  final int frostDays;
  final int frostBonusPercent;

  List<int> get frostPrincipalOptions => [
    for (var amount = frostMinimum; amount <= frostMaximum; amount += frostStep)
      amount,
  ];

  int frostBonusFor(int principal) =>
      (principal * frostBonusPercent + 99) ~/ 100;

  factory EconomyRules.fromJson(Map<String, dynamic> json) {
    final rawTransferAmounts = json['savingsTransferAmounts'];
    if (rawTransferAmounts is! List) {
      throw const FormatException(
        'Missing or invalid economy rule: savingsTransferAmounts',
      );
    }
    final transferAmounts = rawTransferAmounts
        .whereType<num>()
        .where(
          (amount) => amount.isFinite && amount == amount.toInt() && amount > 0,
        )
        .map((amount) => amount.toInt())
        .toList(growable: false);
    if (transferAmounts.isEmpty ||
        transferAmounts.length != rawTransferAmounts.length) {
      throw const FormatException(
        'Missing or invalid economy rule: savingsTransferAmounts',
      );
    }

    final rules = EconomyRules(
      dailyIncome: _requiredPositiveInt(json, 'dailyIncome'),
      foodReserve: _requiredPositiveInt(json, 'foodReserve'),
      savingsTransferAmounts: transferAmounts,
      frostMinimum: _requiredPositiveInt(json, 'frostMinimum'),
      frostMaximum: _requiredPositiveInt(json, 'frostMaximum'),
      frostStep: _requiredPositiveInt(json, 'frostStep'),
      frostDays: _requiredPositiveInt(json, 'frostDays'),
      frostBonusPercent: _requiredPositiveInt(json, 'frostBonusPercent'),
    );
    if (rules.frostMinimum > rules.frostMaximum ||
        (rules.frostMaximum - rules.frostMinimum) % rules.frostStep != 0) {
      throw const FormatException('Invalid frost principal range');
    }
    return rules;
  }
}

final class EconomyDay {
  const EconomyDay({
    required this.id,
    required this.sequence,
    required this.week,
    required this.dayOfWeek,
    required this.planStatus,
    required this.available,
    required this.requiredNeed,
    required this.need,
    required this.want,
    required this.savings,
    this.remainingReserve = 0,
  });

  final String id;
  final int sequence;
  final int week;
  final int dayOfWeek;
  final String planStatus;
  final int available;
  final int requiredNeed;
  final int need;
  final int want;
  final int savings;
  final int remainingReserve;

  bool get planConfirmed => planStatus == 'CONFIRMED';

  factory EconomyDay.fromJson(Map<String, dynamic> json) => EconomyDay(
    id: json['id'] as String,
    sequence: _asInt(json['sequence_no']),
    week: _asInt(json['week']),
    dayOfWeek: _asInt(json['day_of_week']),
    planStatus: json['budget_plan_status'] as String? ?? 'DRAFT',
    available: _asInt(json['available_amount']),
    requiredNeed: _asInt(json['required_need_amount']),
    need: _asInt(json['need_amount']),
    want: _asInt(json['want_amount']),
    savings: _asInt(json['savings_amount']),
    remainingReserve: _asInt(
      json['remaining_reserve'] ?? json['required_need_amount'],
    ),
  );
}

final class EconomyItem {
  const EconomyItem({
    required this.id,
    required this.name,
    required this.price,
    this.kind,
    this.rarity,
    this.imageAsset,
  });

  final String id;
  final String name;
  final int price;
  final String? kind;
  final String? rarity;
  final String? imageAsset;

  factory EconomyItem.fromJson(Map<String, dynamic> json) => EconomyItem(
    id: json['id'] as String,
    name: json['name'] as String,
    price: _asInt(json['price']),
    kind: json['kind'] as String?,
    rarity: json['rarity'] as String?,
    imageAsset: switch (json['image_asset'] ?? json['imageAsset']) {
      final String value => value,
      _ => null,
    },
  );
}

final class EconomyState {
  const EconomyState({
    required this.rules,
    required this.petName,
    required this.energy,
    required this.joy,
    required this.wallet,
    required this.savings,
    required this.frozen,
    required this.day,
    required this.event,
    required this.goal,
    required this.frost,
    required this.shopItems,
    required this.artifacts,
    required this.inventory,
    required this.quests,
    required this.parentTasks,
    required this.transactions,
    required this.recentDays,
  });

  final EconomyRules rules;
  final String petName;
  final int energy;
  final int joy;
  final int wallet;
  final int savings;
  final int frozen;
  final EconomyDay? day;
  final Map<String, dynamic>? event;
  final Map<String, dynamic>? goal;
  final Map<String, dynamic>? frost;
  final List<EconomyItem> shopItems;
  final List<EconomyItem> artifacts;
  final List<Map<String, dynamic>> inventory;
  final List<Map<String, dynamic>> quests;
  final List<Map<String, dynamic>> parentTasks;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> recentDays;

  factory EconomyState.fromJson(Map<String, dynamic> json) {
    final pet = _asMap(json['pet']) ?? const {};
    final wallets = _asMap(json['wallets']) ?? const {};
    final dayJson = _asMap(json['activeDay']);
    return EconomyState(
      rules: EconomyRules.fromJson(
        _asMap(json['rules']) ??
            (throw const FormatException('Missing economy rules')),
      ),
      // Neutral fallback: a missing name must never masquerade as a real one.
      petName: pet['pet_name'] as String? ?? 'Питомец',
      energy: _asInt(pet['energy_level']),
      joy: _asInt(pet['joy_level']),
      wallet: _asInt(wallets['SPENDABLE']),
      savings: _asInt(wallets['SAVINGS']),
      frozen: _asInt(wallets['FROZEN']),
      day: dayJson == null ? null : EconomyDay.fromJson(dayJson),
      event: _asMap(json['activeEvent']),
      goal: _asMap(json['activeGoal']),
      frost: _asMap(json['activeFrostChest']),
      shopItems: _asList(json['shopItems']).map(EconomyItem.fromJson).toList(),
      artifacts: _asList(json['artifacts']).map(EconomyItem.fromJson).toList(),
      inventory: _asList(json['inventory']),
      quests: _asList(json['quests']),
      parentTasks: _asList(json['parentTasks']),
      transactions: _asList(json['recentTransactions']),
      recentDays: _asList(json['recentDays']),
    );
  }
}
