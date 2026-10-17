import '../../pet/pet_energy_status.dart';

enum CatchLane { upperLeft, lowerLeft, upperRight, lowerRight }

extension CatchLaneAssets on CatchLane {
  String get assetName => switch (this) {
    CatchLane.upperLeft => 'upper_left',
    CatchLane.lowerLeft => 'lower_left',
    CatchLane.upperRight => 'upper_right',
    CatchLane.lowerRight => 'lower_right',
  };

  bool get isLeft => this == CatchLane.upperLeft || this == CatchLane.lowerLeft;
  String get label => switch (this) {
    CatchLane.upperLeft => 'Слева сверху',
    CatchLane.lowerLeft => 'Слева снизу',
    CatchLane.upperRight => 'Справа сверху',
    CatchLane.lowerRight => 'Справа снизу',
  };
}

enum CatchFoodPhase { ready, playing, paused, finished }

enum CatchFoodFinish { misses, tired, stopped }

extension CatchFoodFinishCode on CatchFoodFinish {
  String get code => name.toUpperCase();
}

class CatchFoodConfig {
  const CatchFoodConfig({
    this.energyCost = 20,
    this.durationMs = 60000,
    this.maxMisses = 3,
    this.travelMs = 2400,
    this.firstSpawnMs = 600,
    this.initialSpawnMs = 1300,
    this.minimumSpawnMs = 700,
    this.catchWindowMs = 180,
    this.spoiledFoodPercent = 20,
  });

  factory CatchFoodConfig.fromJson(Map<String, dynamic> json) {
    int read(String name) {
      final value = json[name];
      if (value is! int || value <= 0) {
        throw FormatException('Invalid catch-food config: $name');
      }
      return value;
    }

    final spoiledFoodPercent = json['spoiledFoodPercent'];
    if (spoiledFoodPercent is! int ||
        spoiledFoodPercent < 0 ||
        spoiledFoodPercent > 100) {
      throw const FormatException('Invalid catch-food spoiled food percentage');
    }
    final result = CatchFoodConfig(
      energyCost: read('energyCost'),
      durationMs: read('durationMs'),
      maxMisses: read('maxMisses'),
      travelMs: read('travelMs'),
      firstSpawnMs: read('firstSpawnMs'),
      initialSpawnMs: read('initialSpawnMs'),
      minimumSpawnMs: read('minimumSpawnMs'),
      catchWindowMs: read('catchWindowMs'),
      spoiledFoodPercent: spoiledFoodPercent,
    );
    if (result.energyCost > 100 ||
        result.maxMisses > 10 ||
        result.durationMs > 600000 ||
        result.minimumSpawnMs < 100 ||
        result.minimumSpawnMs > result.initialSpawnMs ||
        result.travelMs >= result.durationMs ||
        result.catchWindowMs > result.travelMs) {
      throw const FormatException('Unsupported catch-food config');
    }
    return result;
  }

  final int energyCost;
  final int durationMs;
  final int maxMisses;
  final int travelMs;
  final int firstSpawnMs;
  final int initialSpawnMs;
  final int minimumSpawnMs;
  final int catchWindowMs;
  final int spoiledFoodPercent;
}

class CatchFoodResult {
  const CatchFoodResult({
    required this.score,
    required this.misses,
    required this.elapsedMs,
    required this.reason,
  });

  final int score;
  final int misses;
  final int elapsedMs;
  final CatchFoodFinish reason;

  Map<String, dynamic> toJson() => {
    'score': score,
    'misses': misses,
    'elapsedMs': elapsedMs,
    'reason': reason.code,
  };

  factory CatchFoodResult.fromJson(Map<String, dynamic> json) =>
      CatchFoodResult(
        score: json['score'] as int,
        misses: json['misses'] as int,
        elapsedMs: json['elapsedMs'] as int,
        reason: CatchFoodFinish.values.firstWhere(
          (value) => value.code == json['reason'],
        ),
      );
}

class CatchFoodInfo {
  const CatchFoodInfo({
    required this.config,
    required this.energy,
    required this.bestScore,
  });

  factory CatchFoodInfo.fromJson(Map<String, dynamic> json) => CatchFoodInfo(
    config: CatchFoodConfig.fromJson(json['config'] as Map<String, dynamic>),
    energy: PetEnergyStatus.fromJson(json['pet'] as Map<String, dynamic>),
    bestScore: json['bestScore'] as int,
  );

  final CatchFoodConfig config;
  final PetEnergyStatus energy;
  final int bestScore;
}

const catchFoodAssetRoot = 'assets/minigames/catch_food';
