enum TurnipDifficulty { normal, hard }

/// Economy-compatible quest identity. The economy remains responsible for
/// validating and deduplicating the reward before changing a real balance.
const turnipQuestId = 'turnip';

extension TurnipDifficultyReward on TurnipDifficulty {
  /// Both values belong to the economy's allowed quest-reward set.
  int get rewardAmount => switch (this) {
    TurnipDifficulty.normal => 10,
    TurnipDifficulty.hard => 12,
  };
}

enum TurnipCharacter { grandmother, granddaughter, zhuchka, cat, mouse }

extension TurnipCharacterData on TurnipCharacter {
  String get label => switch (this) {
    TurnipCharacter.grandmother => 'Бабушка',
    TurnipCharacter.granddaughter => 'Внучка',
    TurnipCharacter.zhuchka => 'Жучка',
    TurnipCharacter.cat => 'Кошка',
    TurnipCharacter.mouse => 'Мышка',
  };

  String get assetPath => switch (this) {
    TurnipCharacter.grandmother => 'assets/games/turnip/grandmother.png',
    TurnipCharacter.granddaughter => 'assets/games/turnip/granddaughter.png',
    TurnipCharacter.zhuchka => 'assets/games/turnip/zhuchka.png',
    TurnipCharacter.cat => 'assets/games/turnip/cat.png',
    TurnipCharacter.mouse => 'assets/games/turnip/mouse.png',
  };
}

enum TurnipGamePhase { intro, playing, pulling, completed }

enum TurnipPlacementResult { accepted, rejected, ignored, completed }

class TurnipGameResult {
  const TurnipGameResult({
    required this.difficulty,
    required this.questId,
    required this.rewardAmount,
    required this.wrongAttempts,
    required this.hintUsed,
  });

  final TurnipDifficulty difficulty;

  /// A completion quote for the economy adapter, not authority to mutate a
  /// wallet directly from the client.
  final String questId;
  final int rewardAmount;
  final int wrongAttempts;
  final bool hintUsed;
}

class TurnipStoryLine {
  const TurnipStoryLine({required this.speaker, required this.text});

  final String speaker;
  final String text;
}
