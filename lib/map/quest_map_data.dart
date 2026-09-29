import 'package:flutter/widgets.dart';

import '../games/ivan/ivan_game_models.dart';
import '../games/goldfish/goldfish_game_models.dart';
import '../games/turnip/turnip_game_models.dart';
import '../minigames/mole/mole_game_data.dart';
import '../minigames/bakery/bakery_game_data.dart';
import '../minigames/tugriki/tugriki_game_data.dart';

enum QuestMapDestination {
  upcoming,
  turnip,
  mole,
  ivan,
  goldfish,
  bakery,
  tugriki,
  badger,
}

extension QuestMapDestinationQuest on QuestMapDestination {
  /// Server quest behind a playable node; story-only nodes have none.
  String? get questId => switch (this) {
    QuestMapDestination.turnip => turnipQuestId,
    QuestMapDestination.mole => kMoleQuestId,
    QuestMapDestination.bakery => kBakeryQuestId,
    // Multi-level tracks: see questIds / isCompletedBy.
    QuestMapDestination.ivan => null,
    QuestMapDestination.goldfish => null,
    QuestMapDestination.tugriki => kTugrikiQuestId,
    QuestMapDestination.badger => null,
    QuestMapDestination.upcoming => null,
  };

  Set<String> get questIds => switch (this) {
    QuestMapDestination.ivan => ivanQuestIds,
    QuestMapDestination.goldfish => goldfishQuestIds,
    _ when questId != null => {questId!},
    _ => const {},
  };

  bool isCompletedBy(Set<String> completedQuestIds) => switch (this) {
    QuestMapDestination.ivan => isIvanTrackComplete(completedQuestIds),
    QuestMapDestination.goldfish => isGoldfishTrackComplete(completedQuestIds),
    _ => questId != null && completedQuestIds.contains(questId),
  };
}

@immutable
class QuestMapNode {
  const QuestMapNode({
    required this.order,
    required this.id,
    required this.title,
    required this.character,
    required this.description,
    required this.topics,
    required this.heroBounds,
    required this.pathIndex,
    this.destination = QuestMapDestination.upcoming,
    this.mapLabel,
    this.showPlayAction = true,
    this.catFacesRight,
  });

  final int order;
  final String id;
  final String title;
  final String character;
  final String description;
  final List<String> topics;

  /// Clickable oval placed over the character in the original 821 x 1915 art.
  final Rect heroBounds;
  final int pathIndex;
  final QuestMapDestination destination;
  final String? mapLabel;
  final bool showPlayAction;
  final bool? catFacesRight;

  bool get isPlayable => destination != QuestMapDestination.upcoming;
  // Multi-level tracks (Иван, Золотая рыбка) have no single quest id but are
  // rewarded games all the same.
  bool get isRewardedQuest => destination.questIds.isNotEmpty;
  Offset get catStop => questMapPath[pathIndex];
  String get labelOnMap => mapLabel ?? character;
}

/// A shared bottom-to-top route following the painted road.
const questMapPath = <Offset>[
  Offset(0.45, 0.967),
  Offset(0.60, 0.875),
  Offset(0.47, 0.728),
  Offset(0.48, 0.715),
  Offset(0.50, 0.612),
  Offset(0.57, 0.585),
  Offset(0.60, 0.525),
  Offset(0.53, 0.470),
  Offset(0.43, 0.410),
  Offset(0.43, 0.355),
  Offset(0.54, 0.310),
  Offset(0.58, 0.255),
  Offset(0.62, 0.205),
  Offset(0.57, 0.155),
];

/// Progress runs from the turnip at the bottom towards the park at the top.
/// Bounds stay in the artwork coordinate system and scale with the screen.
const questMapNodes = <QuestMapNode>[
  QuestMapNode(
    order: 1,
    id: 'turnip',
    title: 'Репка',
    character: 'Дедушка и вся семья',
    description: 'Собери помощников в одну цепочку и помоги семье вытащить огромную репку.',
    topics: ['Командная работа', 'Урожай', 'Доход'],
    heroBounds: Rect.fromLTWH(105, 1585, 610, 285),
    pathIndex: 0,
    destination: QuestMapDestination.turnip,
    mapLabel: 'Репка',
  ),
  QuestMapNode(
    order: 2,
    id: 'mole',
    title: 'Крот с лупой',
    character: 'Крот Земелик',
    description: 'Исследуй объявления и чеки, находи мелкий шрифт и проверяй итоговую стоимость.',
    topics: ['Цена', 'Скидка', 'Чек'],
    heroBounds: Rect.fromLTWH(455, 1210, 330, 260),
    pathIndex: 2,
    destination: QuestMapDestination.mole,
    showPlayAction: false,
    catFacesRight: true,
  ),
  QuestMapNode(
    order: 3,
    id: 'ivan',
    title: 'Сборы в дорогу',
    character: 'Иван-царевич',
    description:
        'Собери всё необходимое для путешествия и уложись в заданный бюджет.',
    topics: ['Бюджет', 'Покупки', 'Остаток'],
    heroBounds: Rect.fromLTWH(40, 945, 400, 300),
    pathIndex: 4,
    destination: QuestMapDestination.ivan,
  ),
  QuestMapNode(
    order: 4,
    id: 'goldfish',
    title: 'Обустрой домик',
    character: 'Золотая рыбка',
    description: 'Помоги Дедушке и Бабушке выбрать нужные улучшения и оставить запас монет.',
    topics: ['Экономия', 'Запас', 'Сравнение цен'],
    heroBounds: Rect.fromLTWH(390, 760, 390, 300),
    pathIndex: 5,
    destination: QuestMapDestination.goldfish,
  ),
  QuestMapNode(
    order: 5,
    id: 'fox',
    title: 'Хитрый Лис',
    character: 'Хитрый Лис',
    description: 'Задавай вопросы перед тем, как одолжить деньги, и оценивай обещания и риски.',
    topics: ['Заём', 'Риск', 'Возврат долга'],
    heroBounds: Rect.fromLTWH(30, 585, 360, 285),
    pathIndex: 7,
  ),
  QuestMapNode(
    order: 6,
    id: 'bakery',
    title: 'Пекарня',
    character: 'Пекарь',
    description: 'Купи продукты, испеки пирожки, продай их на ярмарке и посчитай прибыль.',
    topics: ['Расходы', 'Выручка', 'Прибыль'],
    heroBounds: Rect.fromLTWH(420, 245, 365, 330),
    pathIndex: 9,
    destination: QuestMapDestination.bakery,
    catFacesRight: true,
  ),
  QuestMapNode(
    order: 7,
    id: 'tugriki',
    title: 'Тугрики',
    character: 'Воробей-путешественник',
    description: 'Отправляйся на соседний рынок, пересчитывай цены по курсу и распределяй бюджет.',
    topics: ['Валюта', 'Курс', 'Обмен'],
    heroBounds: Rect.fromLTWH(35, 230, 340, 275),
    pathIndex: 11,
    destination: QuestMapDestination.tugriki,
    catFacesRight: false,
  ),
  QuestMapNode(
    order: 8,
    id: 'badger',
    title: 'Сказочный парк',
    character: 'Барсук',
    description: 'Реши, хочешь ли ты добавить монеты на общий парк, и следи, как его строят.',
    topics: ['Общие деньги', 'Помощь городу', 'Парк'],
    heroBounds: Rect.fromLTWH(215, 25, 455, 255),
    pathIndex: 13,
    destination: QuestMapDestination.badger,
    mapLabel: 'Барсук',
  ),
];

/// The current node is the first game the child has not completed on the
/// server; every node before it is open. Story-only nodes have nothing to
/// complete, so they never block the path.
int unlockedIndexFor(Set<String> completedQuestIds) {
  for (var i = 0; i < questMapNodes.length; i++) {
    final destination = questMapNodes[i].destination;
    if (destination != QuestMapDestination.upcoming &&
        !destination.isCompletedBy(completedQuestIds)) {
      return i;
    }
  }
  return questMapNodes.length - 1;
}

/// Number of nodes that are real, server-rewarded games.
int get playableQuestCount =>
    questMapNodes.where((node) => node.isRewardedQuest).length;
