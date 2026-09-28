import 'active_period.dart';
import 'artifact_catalog.dart';
import 'parent_task.dart';
import 'pet.dart';

class ActiveGoal {
  const ActiveGoal({
    required this.id,
    required this.itemId,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.status,
  });

  final String id;
  final String itemId;
  final String name;
  final int targetAmount;
  final int savedAmount;
  final String status;

  int get remainingAmount =>
      (targetAmount - savedAmount).clamp(0, targetAmount).toInt();
  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0.0, 1.0);
  bool get canRedeem => status == 'ACHIEVED' || savedAmount >= targetAmount;

  factory ActiveGoal.fromJson(Map<String, dynamic> json) => ActiveGoal(
    id: json['id'] as String? ?? '',
    itemId: json['target_item_id'] as String? ?? '',
    name: json['name'] as String? ?? 'Моя мечта',
    targetAmount: _int(json['target_amount']),
    savedAmount: _int(json['saved_amount']),
    status: json['status'] as String? ?? 'ACTIVE',
  );
}

class ArtifactItem {
  const ArtifactItem({
    required this.id,
    required this.itemId,
    required this.name,
    required this.rarity,
    required this.equipped,
    required this.durabilityCurrent,
    required this.durabilityMax,
    required this.isBroken,
    required this.repairCost,
    required this.isWearable,
  });

  final String id;
  final String itemId;
  final String name;
  final String? rarity;
  final bool equipped;
  final int durabilityCurrent;
  final int durabilityMax;
  final bool isBroken;
  final int repairCost;
  final bool isWearable;

  factory ArtifactItem.fromJson(Map<String, dynamic> json) => ArtifactItem(
    id: json['id'] as String? ?? '',
    itemId: json['item_id'] as String? ?? '',
    name: json['name'] as String? ?? 'Артефакт',
    rarity: json['rarity'] as String?,
    equipped: json['equipped'] as bool? ?? false,
    durabilityCurrent: _int(json['durability_current'] ?? 100),
    durabilityMax: _int(json['durability_max'] ?? 100),
    isBroken: json['is_broken'] as bool? ?? false,
    repairCost: _int(json['repair_cost']),
    isWearable:
        json['is_wearable'] as bool? ??
        (artifactDefinition(json['item_id'] as String? ?? '')?.wearable ??
            false),
  );

  ArtifactDefinition? get definition => artifactDefinition(itemId);
  String? get assetPath => definition?.assetPath;
  String get ability => definition?.ability ?? 'Способность пока не описана.';
  double get durabilityProgress => durabilityMax <= 0
      ? 0
      : (durabilityCurrent / durabilityMax).clamp(0.0, 1.0);
}

class HomeEconomyState {
  const HomeEconomyState({
    required this.pet,
    required this.spendable,
    required this.savings,
    required this.activeDay,
    required this.activeGoal,
    required this.activeEvent,
    required this.activeInsurance,
    required this.inventory,
    required this.parentTasks,
  });

  final Pet pet;
  final int spendable;
  final int savings;
  final ActivePeriod? activeDay;
  final ActiveGoal? activeGoal;
  final Map<String, dynamic>? activeEvent;
  final Map<String, dynamic>? activeInsurance;
  final List<ArtifactItem> inventory;
  final List<ParentTask> parentTasks;

  List<String> get inventoryNames =>
      inventory.map((item) => item.name).toList(growable: false);

  HomeEconomyState copyWith({Pet? pet}) => HomeEconomyState(
    pet: pet ?? this.pet,
    spendable: spendable,
    savings: savings,
    activeDay: activeDay,
    activeGoal: activeGoal,
    activeEvent: activeEvent,
    activeInsurance: activeInsurance,
    inventory: inventory,
    parentTasks: parentTasks,
  );

  factory HomeEconomyState.fromJson(Map<String, dynamic> json) {
    final petJson = json['pet'];
    if (petJson is! Map) {
      throw const FormatException('economy state has no pet');
    }
    final wallets = Map<String, dynamic>.from(
      json['wallets'] as Map? ?? const {},
    );
    final day = json['activeDay'];
    final goal = json['activeGoal'];
    final event = json['activeEvent'];
    final insurance = json['activeInsurance'];
    final inventory = json['inventory'];
    final parentTasks = json['parentTasks'];
    return HomeEconomyState(
      pet: Pet.fromJson(Map<String, dynamic>.from(petJson)),
      spendable: _walletAmount(wallets['MAIN'] ?? wallets['SPENDABLE']),
      savings: _walletAmount(wallets['SAVINGS']),
      activeDay: day is Map
          ? ActivePeriod.fromJson(Map<String, dynamic>.from(day))
          : null,
      activeGoal: goal is Map
          ? ActiveGoal.fromJson(Map<String, dynamic>.from(goal))
          : null,
      activeEvent: event is Map ? Map<String, dynamic>.from(event) : null,
      activeInsurance: insurance is Map
          ? Map<String, dynamic>.from(insurance)
          : null,
      inventory: inventory is List
          ? inventory
                .whereType<Map>()
                .map(
                  (row) =>
                      ArtifactItem.fromJson(Map<String, dynamic>.from(row)),
                )
                .toList(growable: false)
          : const [],
      parentTasks: parentTasks is List
          ? parentTasks
                .whereType<Map>()
                .map(
                  (row) => ParentTask.fromJson(Map<String, dynamic>.from(row)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

int _walletAmount(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is Map) {
    return _int(value['spendable'] ?? value['balance'] ?? value['amount']);
  }
  return 0;
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;
