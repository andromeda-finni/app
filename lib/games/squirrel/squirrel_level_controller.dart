import 'dart:math';

import 'package:flutter/foundation.dart';

import 'squirrel_game_models.dart';

class SquirrelLevelController extends ChangeNotifier {
  SquirrelLevelController({required this.level, Random? random})
    : _random = random ?? Random() {
    _reset();
  }

  final SquirrelLevel level;
  final Random _random;

  int budget = 15;
  int step = 0;
  int mistakes = 0;
  bool finished = false;
  bool success = false;
  bool inspected = false;
  late List<SquirrelProduct> sequence;
  late List<SquirrelProduct> choices;
  final List<SquirrelProduct> cart = [];
  final Map<SquirrelProductKind, int> goodCounts = {
    for (final kind in SquirrelProductKind.values) kind: 0,
  };

  static const conveyorGoal = <SquirrelProductKind, int>{
    SquirrelProductKind.mushroom: 2,
    SquirrelProductKind.berry: 1,
    SquirrelProductKind.nut: 1,
  };

  SquirrelProduct? get current =>
      step < sequence.length ? sequence[step] : null;

  void _reset() {
    budget = level == SquirrelLevel.conveyor ? 20 : 15;
    step = 0;
    mistakes = 0;
    finished = false;
    success = false;
    inspected = false;
    cart.clear();
    for (final kind in SquirrelProductKind.values) {
      goodCounts[kind] = 0;
    }
    sequence = switch (level) {
      SquirrelLevel.sorting => [...squirrelProducts]..shuffle(_random),
      SquirrelLevel.findOdd => const [],
      SquirrelLevel.conveyor => const [],
      SquirrelLevel.inspect => [...squirrelProducts]..shuffle(_random),
    };
    choices = const [];
    if (level == SquirrelLevel.findOdd) _prepareFindOddRound();
  }

  void restart() {
    _reset();
    notifyListeners();
  }

  void decideSorting({required bool buy}) {
    if (finished || level != SquirrelLevel.sorting || current == null) return;
    final product = current!;
    if (buy) {
      _purchase(product);
      if (!product.isGood) mistakes++;
    } else if (product.isGood) {
      mistakes++;
    }
    step++;
    if (step >= sequence.length) {
      _finish(mistakes == 0 && cart.where((item) => item.isGood).length == 3);
    }
    notifyListeners();
  }

  void chooseFindOdd(SquirrelProduct product) {
    if (finished || level != SquirrelLevel.findOdd) return;
    _purchase(product);
    if (product.isGood) {
      goodCounts[product.kind] = goodCounts[product.kind]! + 1;
    } else {
      mistakes++;
    }
    step++;
    if (step >= SquirrelProductKind.values.length) {
      _finish(mistakes == 0);
    } else {
      _prepareFindOddRound();
    }
    notifyListeners();
  }

  void takeFromConveyor(SquirrelProduct product) {
    if (finished || level != SquirrelLevel.conveyor || budget < product.price) {
      return;
    }
    _purchase(product);
    final needed = conveyorGoal[product.kind]!;
    if (goodCounts[product.kind]! < needed) {
      goodCounts[product.kind] = goodCounts[product.kind]! + 1;
    } else {
      mistakes++;
    }
    if (!product.isGood) mistakes++;

    if (cart.length ==
        conveyorGoal.values.fold(0, (sum, value) => sum + value)) {
      final listComplete = conveyorGoal.entries.every(
        (entry) => goodCounts[entry.key] == entry.value,
      );
      _finish(mistakes == 0 && listComplete);
    }
    notifyListeners();
  }

  void inspectCurrent() {
    if (finished || level != SquirrelLevel.inspect || current == null) return;
    inspected = true;
    notifyListeners();
  }

  void decideInspected({required bool buy}) {
    if (finished ||
        level != SquirrelLevel.inspect ||
        !inspected ||
        current == null) {
      return;
    }
    final product = current!;
    if (buy) {
      _purchase(product);
      if (!product.isGood) mistakes++;
    } else if (product.isGood) {
      mistakes++;
    }
    step++;
    inspected = false;
    if (step >= sequence.length) {
      _finish(mistakes == 0 && cart.where((item) => item.isGood).length == 3);
    }
    notifyListeners();
  }

  void _prepareFindOddRound() {
    final kind = SquirrelProductKind.values[step];
    choices = [
      squirrelProduct(kind, SquirrelProductQuality.good),
      squirrelProduct(kind, SquirrelProductQuality.bad),
      squirrelProduct(kind, SquirrelProductQuality.bad),
    ]..shuffle(_random);
  }

  void _purchase(SquirrelProduct product) {
    if (budget < product.price) return;
    budget -= product.price;
    cart.add(product);
  }

  void _finish(bool value) {
    finished = true;
    success = value;
  }
}
