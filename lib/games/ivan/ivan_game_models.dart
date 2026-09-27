enum IvanDifficulty { easy, hard }

extension IvanDifficultyData on IvanDifficulty {
  int get reward => switch (this) {
    IvanDifficulty.easy => 10,
    IvanDifficulty.hard => 12,
  };

  String get title => switch (this) {
    IvanDifficulty.easy => 'С подсказками',
    IvanDifficulty.hard => 'Самостоятельно',
  };
}

enum IvanLevelId { easyOne, easyTwo, hardOne, hardTwo }

extension IvanLevelIdData on IvanLevelId {
  IvanDifficulty get difficulty => switch (this) {
    IvanLevelId.easyOne || IvanLevelId.easyTwo => IvanDifficulty.easy,
    IvanLevelId.hardOne || IvanLevelId.hardTwo => IvanDifficulty.hard,
  };

  int get sequence => switch (this) {
    IvanLevelId.easyOne || IvanLevelId.hardOne => 1,
    IvanLevelId.easyTwo || IvanLevelId.hardTwo => 2,
  };

  String get questId => switch (this) {
    IvanLevelId.easyOne => 'Q_IVAN_ROAD_EASY_1',
    IvanLevelId.easyTwo => 'Q_IVAN_ROAD_EASY_2',
    IvanLevelId.hardOne => 'Q_IVAN_ROAD_HARD_1',
    IvanLevelId.hardTwo => 'Q_IVAN_ROAD_HARD_2',
  };

  IvanLevelId? get next => switch (this) {
    IvanLevelId.easyOne => IvanLevelId.easyTwo,
    IvanLevelId.hardOne => IvanLevelId.hardTwo,
    IvanLevelId.easyTwo || IvanLevelId.hardTwo => null,
  };
}

const ivanQuestIds = <String>{
  'Q_IVAN_ROAD_EASY_1',
  'Q_IVAN_ROAD_EASY_2',
  'Q_IVAN_ROAD_HARD_1',
  'Q_IVAN_ROAD_HARD_2',
};

const easyIvanQuestIds = <String>{'Q_IVAN_ROAD_EASY_1', 'Q_IVAN_ROAD_EASY_2'};

const hardIvanQuestIds = <String>{'Q_IVAN_ROAD_HARD_1', 'Q_IVAN_ROAD_HARD_2'};

bool isIvanTrackComplete(Set<String> completedQuestIds) =>
    completedQuestIds.containsAll(easyIvanQuestIds) ||
    completedQuestIds.containsAll(hardIvanQuestIds);

IvanLevelId nextIvanLevel({
  required Set<String> completedQuestIds,
  required IvanDifficulty preferredDifficulty,
}) {
  // Finish an already-started track even if the profile setting changed.
  if (completedQuestIds.contains(IvanLevelId.easyOne.questId) &&
      !completedQuestIds.contains(IvanLevelId.easyTwo.questId)) {
    return IvanLevelId.easyTwo;
  }
  if (completedQuestIds.contains(IvanLevelId.hardOne.questId) &&
      !completedQuestIds.contains(IvanLevelId.hardTwo.questId)) {
    return IvanLevelId.hardTwo;
  }

  return switch (preferredDifficulty) {
    IvanDifficulty.easy =>
      completedQuestIds.contains(IvanLevelId.easyOne.questId)
          ? IvanLevelId.easyTwo
          : IvanLevelId.easyOne,
    IvanDifficulty.hard =>
      completedQuestIds.contains(IvanLevelId.hardOne.questId)
          ? IvanLevelId.hardTwo
          : IvanLevelId.hardOne,
  };
}

enum IvanItemCategory { food, warmth, water, light, navigation, traversal }

class IvanItem {
  const IvanItem({
    required this.id,
    required this.name,
    required this.price,
    required this.assetPath,
    this.categories = const {},
    this.isMagic = false,
  });

  final String id;
  final String name;
  final int price;
  final String assetPath;
  final Set<IvanItemCategory> categories;
  final bool isMagic;
}

class IvanRequirement {
  const IvanRequirement({required this.label, required this.acceptedItemIds});

  final String label;
  final Set<String> acceptedItemIds;
}

class IvanStoryLine {
  const IvanStoryLine({required this.speaker, required this.text});

  final String speaker;
  final String text;
}

class IvanLevelConfig {
  const IvanLevelConfig({
    required this.id,
    required this.title,
    required this.budget,
    required this.taskText,
    required this.hintText,
    required this.successText,
    required this.items,
    required this.requirements,
    required this.introLines,
  });

  final IvanLevelId id;
  final String title;
  final int budget;
  final String taskText;
  final String hintText;
  final String successText;
  final List<IvanItem> items;
  final List<IvanRequirement> requirements;
  final List<IvanStoryLine> introLines;

  int get reward => id.difficulty.reward;
  String get questId => id.questId;

  IvanItem itemById(String id) => items.firstWhere((item) => item.id == id);
}

class IvanSelectionResult {
  const IvanSelectionResult({
    required this.isSuccessful,
    required this.spent,
    required this.missingRequirements,
    required this.isOverBudget,
  });

  final bool isSuccessful;
  final int spent;
  final List<String> missingRequirements;
  final bool isOverBudget;
}

enum IvanGamePhase { intro, shopping, result }
