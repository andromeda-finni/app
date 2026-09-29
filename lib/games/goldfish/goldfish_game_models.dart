enum GoldfishDifficulty { normal, hard }

enum GoldfishLevelId { normalOne, normalTwo, hardOne, hardTwo }

extension GoldfishDifficultyData on GoldfishDifficulty {
  String get title => switch (this) {
    GoldfishDifficulty.normal => 'С подсказками',
    GoldfishDifficulty.hard => 'Самостоятельно',
  };
}

extension GoldfishLevelIdData on GoldfishLevelId {
  GoldfishDifficulty get difficulty => switch (this) {
    GoldfishLevelId.normalOne ||
    GoldfishLevelId.normalTwo => GoldfishDifficulty.normal,
    GoldfishLevelId.hardOne ||
    GoldfishLevelId.hardTwo => GoldfishDifficulty.hard,
  };

  int get sequence => switch (this) {
    GoldfishLevelId.normalOne || GoldfishLevelId.hardOne => 1,
    GoldfishLevelId.normalTwo || GoldfishLevelId.hardTwo => 2,
  };

  int get reward => switch (this) {
    GoldfishLevelId.normalOne || GoldfishLevelId.normalTwo => 10,
    GoldfishLevelId.hardOne => 12,
    GoldfishLevelId.hardTwo => 15,
  };

  String get questId => switch (this) {
    GoldfishLevelId.normalOne => 'Q_GOLDFISH_HOME_SIMPLE_1',
    GoldfishLevelId.normalTwo => 'Q_GOLDFISH_HOME_SIMPLE_2',
    GoldfishLevelId.hardOne => 'Q_GOLDFISH_HOME_ADVANCED_1',
    GoldfishLevelId.hardTwo => 'Q_GOLDFISH_HOME_ADVANCED_2',
  };

  GoldfishLevelId? get next => switch (this) {
    GoldfishLevelId.normalOne => GoldfishLevelId.normalTwo,
    GoldfishLevelId.hardOne => GoldfishLevelId.hardTwo,
    GoldfishLevelId.normalTwo || GoldfishLevelId.hardTwo => null,
  };
}

const goldfishQuestIds = <String>{
  'Q_GOLDFISH_HOME_SIMPLE_1',
  'Q_GOLDFISH_HOME_SIMPLE_2',
  'Q_GOLDFISH_HOME_ADVANCED_1',
  'Q_GOLDFISH_HOME_ADVANCED_2',
};

const normalGoldfishQuestIds = <String>{
  'Q_GOLDFISH_HOME_SIMPLE_1',
  'Q_GOLDFISH_HOME_SIMPLE_2',
};

const hardGoldfishQuestIds = <String>{
  'Q_GOLDFISH_HOME_ADVANCED_1',
  'Q_GOLDFISH_HOME_ADVANCED_2',
};

bool isGoldfishTrackComplete(Set<String> completedQuestIds) =>
    completedQuestIds.containsAll(normalGoldfishQuestIds) ||
    completedQuestIds.containsAll(hardGoldfishQuestIds);

GoldfishLevelId nextGoldfishLevel({
  required Set<String> completedQuestIds,
  required GoldfishDifficulty preferredDifficulty,
}) {
  if (completedQuestIds.contains(GoldfishLevelId.normalOne.questId) &&
      !completedQuestIds.contains(GoldfishLevelId.normalTwo.questId)) {
    return GoldfishLevelId.normalTwo;
  }
  if (completedQuestIds.contains(GoldfishLevelId.hardOne.questId) &&
      !completedQuestIds.contains(GoldfishLevelId.hardTwo.questId)) {
    return GoldfishLevelId.hardTwo;
  }
  return switch (preferredDifficulty) {
    GoldfishDifficulty.normal =>
      completedQuestIds.contains(GoldfishLevelId.normalOne.questId)
          ? GoldfishLevelId.normalTwo
          : GoldfishLevelId.normalOne,
    GoldfishDifficulty.hard =>
      completedQuestIds.contains(GoldfishLevelId.hardOne.questId)
          ? GoldfishLevelId.hardTwo
          : GoldfishLevelId.hardOne,
  };
}

enum GoldfishCategory { roof, bed, window, warmth, desire, extra }

enum GoldfishSpeaker { grandma, grandpa, goldfish }

class GoldfishOffer {
  const GoldfishOffer({
    required this.id,
    required this.name,
    required this.price,
    required this.assetPath,
    this.categories = const {},
    this.decorative = false,
  });

  final String id;
  final String name;
  final int price;
  final String assetPath;
  final Set<GoldfishCategory> categories;
  final bool decorative;
}

class GoldfishRequirement {
  const GoldfishRequirement({
    required this.label,
    required this.acceptedItemIds,
  });

  final String label;
  final Set<String> acceptedItemIds;
}

class GoldfishStoryLine {
  const GoldfishStoryLine({required this.speaker, required this.text});

  final GoldfishSpeaker speaker;
  final String text;
}

class GoldfishLevelConfig {
  const GoldfishLevelConfig({
    required this.id,
    required this.title,
    required this.budget,
    required this.taskText,
    required this.hintText,
    required this.learningText,
    required this.offers,
    required this.requirements,
    required this.introLines,
    required this.successLines,
    required this.missingLines,
    required this.budgetLines,
    this.reserveLines = const [],
    this.minimumReserve = 0,
  });

  final GoldfishLevelId id;
  final String title;
  final int budget;
  final int minimumReserve;
  final String taskText;
  final String hintText;
  final String learningText;
  final List<GoldfishOffer> offers;
  final List<GoldfishRequirement> requirements;
  final List<GoldfishStoryLine> introLines;
  final List<GoldfishStoryLine> successLines;
  final List<GoldfishStoryLine> missingLines;
  final List<GoldfishStoryLine> budgetLines;
  final List<GoldfishStoryLine> reserveLines;

  int get reward => id.reward;
  String get questId => id.questId;

  GoldfishOffer offerById(String id) =>
      offers.firstWhere((offer) => offer.id == id);
}

class GoldfishSelectionResult {
  const GoldfishSelectionResult({
    required this.isSuccessful,
    required this.spent,
    required this.remaining,
    required this.missingRequirements,
    required this.isOverBudget,
    required this.isReserveTooSmall,
  });

  final bool isSuccessful;
  final int spent;
  final int remaining;
  final List<String> missingRequirements;
  final bool isOverBudget;
  final bool isReserveTooSmall;
}

class GoldfishToggleResult {
  const GoldfishToggleResult({required this.changed, this.missingCoins = 0});

  final bool changed;
  final int missingCoins;
}

enum GoldfishGamePhase { intro, shopping, resultDialogue, result }
