import 'active_period.dart';
import 'pet.dart';

class ActiveGoal {
  const ActiveGoal({
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
  });

  final String name;
  final int targetAmount;
  final int savedAmount;

  int get remainingAmount =>
      (targetAmount - savedAmount).clamp(0, targetAmount).toInt();
  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0.0, 1.0);

  factory ActiveGoal.fromJson(Map<String, dynamic> json) => ActiveGoal(
    name: json['name'] as String? ?? 'Моя мечта',
    targetAmount: _int(json['target_amount']),
    savedAmount: _int(json['saved_amount']),
  );
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
    required this.inventoryNames,
  });

  final Pet pet;
  final int spendable;
  final int savings;
  final ActivePeriod? activeDay;
  final ActiveGoal? activeGoal;
  final Map<String, dynamic>? activeEvent;
  final Map<String, dynamic>? activeInsurance;
  final List<String> inventoryNames;

  HomeEconomyState copyWith({Pet? pet}) => HomeEconomyState(
    pet: pet ?? this.pet,
    spendable: spendable,
    savings: savings,
    activeDay: activeDay,
    activeGoal: activeGoal,
    activeEvent: activeEvent,
    activeInsurance: activeInsurance,
    inventoryNames: inventoryNames,
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
      inventoryNames: inventory is List
          ? inventory
                .whereType<Map>()
                .map((row) => row['name'] as String?)
                .whereType<String>()
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
