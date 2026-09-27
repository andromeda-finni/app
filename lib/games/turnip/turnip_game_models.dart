enum TurnipDifficulty { normal, hard }

/// Server quest id (db/migrations/0026_turnip_quest.sql). The server decides
/// and pays the reward; the client never quotes an amount of its own.
const turnipQuestId = 'Q_TURNIP_HARVEST';

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
