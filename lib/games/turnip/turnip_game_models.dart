enum TurnipDifficulty { normal, hard }

/// Server quest id (db/migrations/0026_turnip_quest.sql). The server decides
/// and pays the reward; the client never quotes an amount of its own.
const turnipQuestId = 'Q_TURNIP_HARVEST';

enum TurnipCharacter { grandmother, granddaughter, zhuchka, cat, mouse }

extension TurnipCharacterData on TurnipCharacter {
  String get serverCode => switch (this) {
    TurnipCharacter.grandmother => 'grandmother',
    TurnipCharacter.granddaughter => 'granddaughter',
    TurnipCharacter.zhuchka => 'zhuchka',
    TurnipCharacter.cat => 'cat',
    TurnipCharacter.mouse => 'mouse',
  };

  String get label => switch (this) {
    TurnipCharacter.grandmother => 'Бабушка',
    TurnipCharacter.granddaughter => 'Внучка',
    TurnipCharacter.zhuchka => 'Жучка',
    TurnipCharacter.cat => 'Кошка',
    TurnipCharacter.mouse => 'Мышка',
  };

  String get assetPath => switch (this) {
    TurnipCharacter.grandmother => 'assets/games/turnip/grandmother.webp',
    TurnipCharacter.granddaughter => 'assets/games/turnip/granddaughter.webp',
    TurnipCharacter.zhuchka => 'assets/games/turnip/zhuchka.webp',
    TurnipCharacter.cat => 'assets/games/turnip/cat.webp',
    TurnipCharacter.mouse => 'assets/games/turnip/mouse.webp',
  };
}

enum TurnipGamePhase { intro, playing, pulling, completed }

enum TurnipPlacementResult { accepted, rejected, ignored, completed }

class TurnipGameResult {
  const TurnipGameResult({
    required this.difficulty,
    required this.questId,
    required this.wrongAttempts,
    required this.hintUsed,
  });

  final TurnipDifficulty difficulty;

  final String questId;
  final int wrongAttempts;
  final bool hintUsed;
}

class TurnipStoryLine {
  const TurnipStoryLine({required this.speaker, required this.text});

  final String speaker;
  final String text;
}
