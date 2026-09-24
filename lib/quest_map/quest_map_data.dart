/// Visual-only map catalogue based on the approved mini-game scenarios.
///
/// [x] is relative to the available map width. [y] is a logical-pixel
/// coordinate inside the tall, vertically scrollable map canvas.
class QuestMapNodeData {
  const QuestMapNodeData({
    required this.id,
    required this.title,
    required this.location,
    required this.description,
    required this.emoji,
    required this.x,
    required this.y,
    this.assetPath,
  });

  final String id;
  final String title;
  final String location;
  final String description;
  final String emoji;
  final double x;
  final double y;
  final String? assetPath;
}

const double kQuestMapHeight = 2320;

/// Progress runs from the village at the bottom towards the city park at the
/// top. Keeping the coordinates beside the scenario data makes it easy to
/// replace the painted background later without touching interaction code.
const questMapNodes = <QuestMapNodeData>[
  QuestMapNodeData(
    id: 'repka',
    title: 'Репка',
    location: 'Деревенский огород',
    description: 'Собери помощников и узнай, как урожай превращается в доход.',
    emoji: '🌱',
    x: 0.25,
    y: 2110,
  ),
  QuestMapNodeData(
    id: 'mole',
    title: 'Крот с лупой',
    location: 'Домик Земелика',
    description: 'Ищи скрытые условия, проверяй цены и находи ошибки в чеке.',
    emoji: '🔎',
    x: 0.72,
    y: 1845,
    assetPath: 'assets/minigames/mole/zemelik.webp',
  ),
  QuestMapNodeData(
    id: 'ivan',
    title: 'Сборы в дорогу',
    location: 'Лавка Ивана-царевича',
    description: 'Выбери необходимое для путешествия и уложись в бюджет.',
    emoji: '🎒',
    x: 0.28,
    y: 1575,
  ),
  QuestMapNodeData(
    id: 'goldfish',
    title: 'Домик у моря',
    location: 'Берег Золотой рыбки',
    description: 'Сначала обустрой необходимое, затем оставь запас монет.',
    emoji: '🐟',
    x: 0.73,
    y: 1305,
  ),
  QuestMapNodeData(
    id: 'fox',
    title: 'Хитрый Лис',
    location: 'Лесная развилка',
    description: 'Задавай вопросы и не соглашайся на сомнительные обещания.',
    emoji: '🦊',
    x: 0.27,
    y: 1040,
  ),
  QuestMapNodeData(
    id: 'bakery',
    title: 'Пекарня',
    location: 'Ярмарочная улица',
    description: 'Купи продукты, испеки пирожки и посчитай прибыль.',
    emoji: '🥧',
    x: 0.72,
    y: 780,
  ),
  QuestMapNodeData(
    id: 'tugriki',
    title: 'Тугрики',
    location: 'Заморский рынок',
    description: 'Пересчитывай цены по курсу и планируй покупки в другой валюте.',
    emoji: '🪙',
    x: 0.28,
    y: 515,
    assetPath: 'assets/minigames/tugriki/foreign_money_bag.png',
  ),
  QuestMapNodeData(
    id: 'badger',
    title: 'Сказочный парк',
    location: 'Городская площадь',
    description: 'Помоги Барсуку собрать средства и увидь, как растёт общий проект.',
    emoji: '🌳',
    x: 0.70,
    y: 250,
  ),
];

enum QuestMapNodeState { completed, current, locked }

QuestMapNodeState questMapNodeState(int index, int unlockedIndex) {
  if (index < unlockedIndex) return QuestMapNodeState.completed;
  if (index == unlockedIndex) return QuestMapNodeState.current;
  return QuestMapNodeState.locked;
}
