enum PetProfileMode { standard, demo }

class PetEnergyStatus {
  const PetEnergyStatus({
    required this.level,
    required this.maxEnergy,
    required this.activityCost,
    required this.energyPerTick,
    required this.tickSeconds,
    required this.mode,
    required this.serverClockOffset,
    this.nextTickAt,
    this.fullAt,
  });

  const PetEnergyStatus.full()
    : level = 100,
      maxEnergy = 100,
      activityCost = 20,
      energyPerTick = 20,
      tickSeconds = 180,
      mode = PetProfileMode.standard,
      serverClockOffset = Duration.zero,
      nextTickAt = null,
      fullAt = null;

  factory PetEnergyStatus.fromJson(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
  }) {
    final recovery =
        json['energy_recovery'] as Map<String, dynamic>? ?? const {};
    final clientNow = (receivedAt ?? DateTime.now()).toUtc();
    final serverNow = _parseDate(json['server_time']) ?? clientNow;

    return PetEnergyStatus(
      level: (json['energy_level'] as num?)?.toInt() ?? 100,
      maxEnergy: (recovery['max_energy'] as num?)?.toInt() ?? 100,
      activityCost: (recovery['activity_cost'] as num?)?.toInt() ?? 20,
      energyPerTick: (recovery['energy_per_tick'] as num?)?.toInt() ?? 20,
      tickSeconds: (recovery['tick_seconds'] as num?)?.toInt() ?? 180,
      mode: json['mode'] == 'DEMO'
          ? PetProfileMode.demo
          : PetProfileMode.standard,
      serverClockOffset: serverNow.difference(clientNow),
      nextTickAt: _parseDate(recovery['next_tick_at']),
      fullAt: _parseDate(recovery['full_at']),
    );
  }

  final int level;
  final int maxEnergy;
  final int activityCost;
  final int energyPerTick;
  final int tickSeconds;
  final PetProfileMode mode;
  final Duration serverClockOffset;
  final DateTime? nextTickAt;
  final DateTime? fullAt;

  bool get isDemo => mode == PetProfileMode.demo;
  bool get isRecovering => level < maxEnergy && fullAt != null;
  bool get blocksActivities => level < activityCost;

  DateTime serverNow([DateTime? clientNow]) =>
      (clientNow ?? DateTime.now()).toUtc().add(serverClockOffset);

  Duration untilNextTick([DateTime? clientNow]) =>
      _remaining(nextTickAt, serverNow(clientNow));

  Duration untilFull([DateTime? clientNow]) =>
      _remaining(fullAt, serverNow(clientNow));

  bool nextTickIsDue([DateTime? clientNow]) =>
      nextTickAt != null && !serverNow(clientNow).isBefore(nextTickAt!);

  static Duration _remaining(DateTime? target, DateTime now) {
    if (target == null || !target.isAfter(now)) return Duration.zero;
    return target.difference(now);
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}

String formatEnergyCountdown(Duration value) {
  final roundedUpSeconds = (value.inMilliseconds + 999) ~/ 1000;
  final seconds = roundedUpSeconds.clamp(0, 99 * 60 + 59);
  final minutesPart = seconds ~/ 60;
  final secondsPart = seconds % 60;
  return '${minutesPart.toString().padLeft(2, '0')}:${secondsPart.toString().padLeft(2, '0')}';
}
