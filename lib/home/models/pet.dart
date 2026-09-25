import '../../core/pet_assets.dart';

/// The pet as `GET /pet` returns it.
class Pet {
  const Pet({
    this.id,
    required this.name,
    required this.furOptionId,
    required this.satiety,
    required this.joy,
    required this.health,
    required this.evolutionStage,
  });

  final String? id;
  final String name;
  final String? furOptionId;

  /// `energy_level` server-side — what feeding tops up.
  final int satiety;
  final int joy;
  final int health;
  final int evolutionStage;

  static int _int(Object? value, int fallback) =>
      value is int ? value : int.tryParse('${value ?? ''}') ?? fallback;

  factory Pet.fromJson(Map<String, dynamic> json) {
    final name = json['pet_name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('pet_name must be a non-empty string');
    }
    return Pet(
      id: json['id'] as String?,
      name: name,
      furOptionId: json['fur_option_id'] as String?,
      satiety: _int(json['energy_level'], 100),
      joy: _int(json['joy_level'], 50),
      health: _int(json['health_level'], 100),
      evolutionStage: _int(json['evolution_stage'], 1),
    );
  }

  PetMood get mood => moodFor(satiety: satiety, joy: joy, health: health);

  String get assetPath => catAsset(furOptionId: furOptionId, mood: mood);

  static const _stageNames = ['Малыш', 'Подросток', 'Взрослый'];

  static const maxStage = 3;

  String get stageName =>
      _stageNames[(evolutionStage - 1).clamp(0, _stageNames.length - 1)];
}
