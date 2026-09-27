enum SquirrelDifficulty { normal, hard }

enum SquirrelLevel { sorting, findOdd, conveyor, inspect }

enum SquirrelProductKind { mushroom, berry, nut }

enum SquirrelProductQuality { good, bad }

const squirrelDefaultPetName = 'Грошик';
const squirrelSimpleQuestId = 'Q_SQUIRREL_QUALITY_SIMPLE';
const squirrelAdvancedQuestId = 'Q_SQUIRREL_QUALITY_ADVANCED';

extension SquirrelDifficultyX on SquirrelDifficulty {
  int get rewardAmount => this == SquirrelDifficulty.normal ? 10 : 12;

  String get label => this == SquirrelDifficulty.normal ? 'Обычная' : 'Сложная';

  String get questId => this == SquirrelDifficulty.normal
      ? squirrelSimpleQuestId
      : squirrelAdvancedQuestId;

  List<SquirrelLevel> get levels => this == SquirrelDifficulty.normal
      ? const [SquirrelLevel.sorting, SquirrelLevel.findOdd]
      : const [SquirrelLevel.conveyor, SquirrelLevel.inspect];
}

extension SquirrelLevelX on SquirrelLevel {
  String get title => switch (this) {
    SquirrelLevel.sorting => 'Сортировка',
    SquirrelLevel.findOdd => 'Найди хороший товар',
    SquirrelLevel.conveyor => 'Лесной конвейер',
    SquirrelLevel.inspect => 'Кот в мешке',
  };

  String get instruction => switch (this) {
    SquirrelLevel.sorting =>
      'Рассмотри товар. Хороший купи, испорченный оставь продавцу.',
    SquirrelLevel.findOdd => 'Сравни три товара и выбери один свежий.',
    SquirrelLevel.conveyor =>
      'Перетаскивай в корзину только свежие товары из списка.',
    SquirrelLevel.inspect =>
      'Сначала нажми на товар и осмотри его с другой стороны. Потом решай.',
  };
}

class SquirrelProduct {
  const SquirrelProduct({
    required this.id,
    required this.kind,
    required this.quality,
    required this.assetPath,
    this.price = 5,
  });

  final String id;
  final SquirrelProductKind kind;
  final SquirrelProductQuality quality;
  final String assetPath;
  final int price;

  bool get isGood => quality == SquirrelProductQuality.good;

  String get name => switch (kind) {
    SquirrelProductKind.mushroom => 'гриб',
    SquirrelProductKind.berry => 'ягоды',
    SquirrelProductKind.nut => 'орех',
  };
}

const squirrelProducts = <SquirrelProduct>[
  SquirrelProduct(
    id: 'mushroom-good',
    kind: SquirrelProductKind.mushroom,
    quality: SquirrelProductQuality.good,
    assetPath: 'assets/games/squirrel/mushroom_good.png',
  ),
  SquirrelProduct(
    id: 'mushroom-bad',
    kind: SquirrelProductKind.mushroom,
    quality: SquirrelProductQuality.bad,
    assetPath: 'assets/games/squirrel/mushroom_bad.png',
  ),
  SquirrelProduct(
    id: 'berry-good',
    kind: SquirrelProductKind.berry,
    quality: SquirrelProductQuality.good,
    assetPath: 'assets/games/squirrel/berry_good.png',
  ),
  SquirrelProduct(
    id: 'berry-bad',
    kind: SquirrelProductKind.berry,
    quality: SquirrelProductQuality.bad,
    assetPath: 'assets/games/squirrel/berry_bad.png',
  ),
  SquirrelProduct(
    id: 'nut-good',
    kind: SquirrelProductKind.nut,
    quality: SquirrelProductQuality.good,
    assetPath: 'assets/games/squirrel/nut_good.png',
  ),
  SquirrelProduct(
    id: 'nut-bad',
    kind: SquirrelProductKind.nut,
    quality: SquirrelProductQuality.bad,
    assetPath: 'assets/games/squirrel/nut_bad.png',
  ),
];

SquirrelProduct squirrelProduct(
  SquirrelProductKind kind,
  SquirrelProductQuality quality,
) => squirrelProducts.firstWhere(
  (product) => product.kind == kind && product.quality == quality,
);

class SquirrelGameResult {
  const SquirrelGameResult({
    required this.difficulty,
    required this.rewardAmount,
    required this.rewardGranted,
  });

  final SquirrelDifficulty difficulty;
  final int rewardAmount;
  final bool rewardGranted;
}
