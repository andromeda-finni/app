import '../../core/child_difficulty.dart';

const kBakeryQuestId = 'Q_BAKERY_PROFIT';

abstract final class BakeryAssets {
  static const root = 'assets/minigames/bakery';
  static const background = '$root/bakery_background.png';
  static const bakerHappy = '$root/baker_happy.png';
  static const bakerThinking = '$root/baker_thinking.png';
  static const bakerWithPies = '$root/baker_with_pies.png';
  static const flour = '$root/flour_bag.png';
  static const berries = '$root/berry_basket.png';
  static const butter = '$root/butter_piece.png';
  static const honey = '$root/honey_jar.png';
  static const bowl = '$root/mixing_bowl.png';
  static const pie = '$root/pie_single.png';
  static const coin = 'assets/icons/coin.webp';
}

enum BakeryIngredient { flour, berries, butter, honey }

extension BakeryIngredientData on BakeryIngredient {
  String get title => switch (this) {
    BakeryIngredient.flour => 'Мука',
    BakeryIngredient.berries => 'Ягоды',
    BakeryIngredient.butter => 'Масло',
    BakeryIngredient.honey => 'Мёд',
  };

  int get price => switch (this) {
    BakeryIngredient.flour => 5,
    BakeryIngredient.berries => 4,
    BakeryIngredient.butter => 3,
    BakeryIngredient.honey => 6,
  };

  String get asset => switch (this) {
    BakeryIngredient.flour => BakeryAssets.flour,
    BakeryIngredient.berries => BakeryAssets.berries,
    BakeryIngredient.butter => BakeryAssets.butter,
    BakeryIngredient.honey => BakeryAssets.honey,
  };

  bool get requiredForRecipe => this != BakeryIngredient.honey;
}

enum BakeryStage {
  intro,
  shopping,
  remainderQuiz,
  cooking,
  selling,
  revenueLesson,
  profitQuiz,
  complete,
}

class BakeryGameState {
  BakeryGameState({required this.difficulty});

  final ChildDifficulty difficulty;
  BakeryStage stage = BakeryStage.intro;
  final Set<BakeryIngredient> basket = {};
  final List<BakeryIngredient> addedToBowl = [];
  int soldCount = 0;
  int remainderMistakes = 0;
  int profitMistakes = 0;

  int get startingCash => 20;
  int get basketTotal => basket.fold(0, (sum, item) => sum + item.price);
  int get cashAfterShopping => startingCash - basketTotal;
  int get piesBaked => difficulty == ChildDifficulty.advanced ? 6 : 5;
  int get piesSold => 5;
  int get revenue => piesSold * 4;
  int get profit => revenue - basketTotal;
  int get finalWallet => startingCash - basketTotal + revenue;
  int get reward => difficulty == ChildDifficulty.advanced ? 15 : 12;
  int get unsoldCount => piesBaked - piesSold;
  bool get boughtHoney => basket.contains(BakeryIngredient.honey);
  bool get hasRecipe => BakeryIngredient.values
      .where((item) => item.requiredForRecipe)
      .every(basket.contains);
  bool get cookingComplete => addedToBowl.length == 3;

  void toggleBasket(BakeryIngredient item) {
    if (!basket.add(item)) basket.remove(item);
  }

  bool answerRemainder(int answer) {
    if (answer == cashAfterShopping) {
      stage = BakeryStage.cooking;
      return true;
    }
    remainderMistakes += 1;
    return false;
  }

  void addToBowl(BakeryIngredient item) {
    if (!item.requiredForRecipe || addedToBowl.contains(item)) return;
    addedToBowl.add(item);
  }

  bool answerProfit(int answer) {
    if (answer == profit) {
      stage = BakeryStage.complete;
      return true;
    }
    profitMistakes += 1;
    return false;
  }
}
