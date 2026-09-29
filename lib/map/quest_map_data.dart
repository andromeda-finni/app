import 'package:flutter/widgets.dart';

import '../games/turnip/turnip_game_models.dart';
import '../minigames/mole/mole_game_data.dart';
import '../minigames/tugriki/tugriki_game_data.dart';

enum QuestMapDestination { upcoming, turnip, mole, tugriki }

enum QuestMapNodeState { completed, current, locked, comingSoon }

enum QuestSceneEffect {
  turnipGlow,
  lensGlint,
  compassGlint,
  waterGlint,
  fireflies,
  ovenLight,
  coinGlint,
  jarGlint,
}

extension QuestMapDestinationQuest on QuestMapDestination {
  /// Server quest behind a playable node; story-only nodes have none.
  String? get questId => switch (this) {
    QuestMapDestination.turnip => turnipQuestId,
    QuestMapDestination.mole => kMoleQuestId,
    QuestMapDestination.tugriki => kTugrikiQuestId,
    QuestMapDestination.upcoming => null,
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
    required this.nodeCenter,
    required this.catStop,
    required this.sceneEffectAnchor,
    required this.sceneEffect,
    required this.pathIndex,
    this.destination = QuestMapDestination.upcoming,
    this.rewardAmount,
    this.catFacesRight,
  });

  final int order;
  final String id;
  final String title;
  final String character;
  final String description;
  final List<String> topics;

  /// Centre of the interactive quest marker in normalized map coordinates.
  /// Nodes 1–7 are measured from the painted checkpoint interiors in the
  /// 821×1916 source image. Node 8 is the proposed stop on the park path.
  final Offset nodeCenter;

  /// Feet/contact point on the painted road, in normalized map coordinates.
  final Offset catStop;

  /// Small story-specific detail that receives local light when highlighted.
  final Offset sceneEffectAnchor;
  final QuestSceneEffect sceneEffect;
  final int pathIndex;
  final QuestMapDestination destination;
  final int? rewardAmount;
  final bool? catFacesRight;

  bool get isPlayable => destination != QuestMapDestination.upcoming;
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
  Offset(0.50, 0.082),
];

/// Progress runs from the turnip at the bottom towards the park at the top.
const questMapNodes = <QuestMapNode>[
  QuestMapNode(
    order: 1,
    id: 'turnip',
    title: 'Репка',
    character: 'Дедушка и вся семья',
    description: 'Собери помощников в одну цепочку и помоги семье вытащить огромную репку.',
    topics: ['Командная работа', 'Урожай', 'Доход'],
    nodeCenter: Offset(374.65 / 821, 1853.50 / 1916),
    catStop: Offset(374.65 / 821, 1853.50 / 1916),
    sceneEffectAnchor: Offset(280 / 821, 1752 / 1916),
    sceneEffect: QuestSceneEffect.turnipGlow,
    pathIndex: 0,
    destination: QuestMapDestination.turnip,
    rewardAmount: 10,
  ),
  QuestMapNode(
    order: 2,
    id: 'mole',
    title: 'Крот с лупой',
    character: 'Крот Земелик',
    description: 'Исследуй объявления и чеки, находи мелкий шрифт и проверяй итоговую стоимость.',
    topics: ['Цена', 'Скидка', 'Чек'],
    nodeCenter: Offset(392.04 / 821, 1381.20 / 1916),
    catStop: Offset(392.04 / 821, 1381.20 / 1916),
    sceneEffectAnchor: Offset(690 / 821, 1360 / 1916),
    sceneEffect: QuestSceneEffect.lensGlint,
    pathIndex: 2,
    destination: QuestMapDestination.mole,
    rewardAmount: 15,
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
    nodeCenter: Offset(411.58 / 821, 1178.44 / 1916),
    catStop: Offset(411.58 / 821, 1178.44 / 1916),
    sceneEffectAnchor: Offset(180 / 821, 1110 / 1916),
    sceneEffect: QuestSceneEffect.compassGlint,
    pathIndex: 4,
  ),
  QuestMapNode(
    order: 4,
    id: 'goldfish',
    title: 'Обустрой домик',
    character: 'Золотая рыбка',
    description: 'Помоги Дедушке и Бабушке выбрать нужные улучшения и оставить запас монет.',
    topics: ['Экономия', 'Запас', 'Сравнение цен'],
    nodeCenter: Offset(471.02 / 821, 902.34 / 1916),
    catStop: Offset(471.02 / 821, 902.34 / 1916),
    sceneEffectAnchor: Offset(545 / 821, 980 / 1916),
    sceneEffect: QuestSceneEffect.waterGlint,
    pathIndex: 7,
  ),
  QuestMapNode(
    order: 5,
    id: 'fox',
    title: 'Хитрый Лис',
    character: 'Хитрый Лис',
    description: 'Задавай вопросы перед тем, как одолжить деньги, и оценивай обещания и риски.',
    topics: ['Заём', 'Риск', 'Возврат долга'],
    nodeCenter: Offset(350.96 / 821, 684.20 / 1916),
    catStop: Offset(350.96 / 821, 684.20 / 1916),
    sceneEffectAnchor: Offset(260 / 821, 820 / 1916),
    sceneEffect: QuestSceneEffect.fireflies,
    pathIndex: 9,
  ),
  QuestMapNode(
    order: 6,
    id: 'bakery',
    title: 'Пекарня',
    character: 'Пекарь',
    description: 'Купи продукты, испеки пирожки, продай их на ярмарке и посчитай прибыль.',
    topics: ['Расходы', 'Выручка', 'Прибыль'],
    nodeCenter: Offset(457.66 / 821, 487.95 / 1916),
    catStop: Offset(457.66 / 821, 487.95 / 1916),
    sceneEffectAnchor: Offset(760 / 821, 475 / 1916),
    sceneEffect: QuestSceneEffect.ovenLight,
    pathIndex: 11,
    catFacesRight: true,
  ),
  QuestMapNode(
    order: 7,
    id: 'tugriki',
    title: 'Тугрики',
    character: 'Воробей-путешественник',
    description: 'Отправляйся на соседний рынок, пересчитывай цены по курсу и распределяй бюджет.',
    topics: ['Валюта', 'Курс', 'Обмен'],
    nodeCenter: Offset(472.57 / 821, 299.69 / 1916),
    catStop: Offset(472.57 / 821, 299.69 / 1916),
    sceneEffectAnchor: Offset(170 / 821, 450 / 1916),
    sceneEffect: QuestSceneEffect.coinGlint,
    pathIndex: 13,
    destination: QuestMapDestination.tugriki,
    rewardAmount: 15,
    catFacesRight: false,
  ),
  QuestMapNode(
    order: 8,
    id: 'badger',
    title: 'Сказочный парк',
    character: 'Барсук',
    description: 'Реши, готов ли ты сделать вклад в общий парк, и следи за ходом строительства.',
    topics: ['Общие деньги', 'Вклад', 'Городской бюджет'],
    nodeCenter: Offset(742 / 821, 248 / 1916),
    catStop: Offset(742 / 821, 248 / 1916),
    sceneEffectAnchor: Offset(354 / 821, 188 / 1916),
    sceneEffect: QuestSceneEffect.jarGlint,
    pathIndex: 14,
  ),
];

/// The current node is the first game the child has not completed on the
/// server; every node before it is open. Story-only nodes have nothing to
/// complete, so they never block the path.
int? currentPlayableNodeIndex(Set<String> completedQuestIds) {
  for (var i = 0; i < questMapNodes.length; i++) {
    final questId = questMapNodes[i].destination.questId;
    if (questId != null && !completedQuestIds.contains(questId)) return i;
  }
  return null;
}

QuestMapNodeState stateForQuestMapNode(
  QuestMapNode node,
  Set<String> completedQuestIds,
) {
  final questId = node.destination.questId;
  if (questId == null) return QuestMapNodeState.comingSoon;
  if (completedQuestIds.contains(questId)) return QuestMapNodeState.completed;
  final currentIndex = currentPlayableNodeIndex(completedQuestIds);
  return questMapNodes.indexOf(node) == currentIndex
      ? QuestMapNodeState.current
      : QuestMapNodeState.locked;
}

int catNodeIndexFor(Set<String> completedQuestIds) {
  final current = currentPlayableNodeIndex(completedQuestIds);
  if (current != null) return current;
  for (var i = questMapNodes.length - 1; i >= 0; i--) {
    final questId = questMapNodes[i].destination.questId;
    if (questId != null && completedQuestIds.contains(questId)) return i;
  }
  return 0;
}

int completedPlayableQuestCount(Set<String> completedQuestIds) {
  return questMapNodes
      .where((node) => completedQuestIds.contains(node.destination.questId))
      .length;
}

/// Number of nodes that are real, server-rewarded games.
int get playableQuestCount =>
    questMapNodes.where((node) => node.isPlayable).length;
