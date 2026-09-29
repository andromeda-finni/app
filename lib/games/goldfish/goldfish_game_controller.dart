import 'package:flutter/foundation.dart';

import 'goldfish_game_models.dart';

class GoldfishGameController extends ChangeNotifier {
  GoldfishGameController(this._level);

  GoldfishLevelConfig _level;
  GoldfishGamePhase _phase = GoldfishGamePhase.intro;
  int _dialoguePageIndex = 0;
  final Set<String> _selectedItemIds = {};
  GoldfishSelectionResult? _result;
  List<GoldfishStoryLine> _resultLines = const [];

  GoldfishLevelConfig get level => _level;
  GoldfishGamePhase get phase => _phase;
  int get dialoguePageIndex => _dialoguePageIndex;
  Set<String> get selectedItemIds => Set.unmodifiable(_selectedItemIds);
  GoldfishSelectionResult? get result => _result;
  List<GoldfishStoryLine> get activeDialogue =>
      _phase == GoldfishGamePhase.intro ? _level.introLines : _resultLines;

  int get spent => _selectedItemIds.fold(
    0,
    (total, id) => total + _level.offerById(id).price,
  );

  int get remaining => _level.budget - spent;

  void advanceDialogue() {
    if (_phase != GoldfishGamePhase.intro &&
        _phase != GoldfishGamePhase.resultDialogue) {
      return;
    }
    final lines = activeDialogue;
    if (_dialoguePageIndex < lines.length - 1) {
      _dialoguePageIndex++;
    } else if (_phase == GoldfishGamePhase.intro) {
      _phase = GoldfishGamePhase.shopping;
      _dialoguePageIndex = 0;
    } else {
      _phase = GoldfishGamePhase.result;
      _dialoguePageIndex = 0;
    }
    notifyListeners();
  }

  GoldfishToggleResult toggleOffer(String itemId) {
    if (_phase != GoldfishGamePhase.shopping) {
      return const GoldfishToggleResult(changed: false);
    }
    final offer = _level.offerById(itemId);
    if (_selectedItemIds.remove(itemId)) {
      notifyListeners();
      return const GoldfishToggleResult(changed: true);
    }
    final missing = spent + offer.price - _level.budget;
    if (missing > 0) {
      return GoldfishToggleResult(changed: false, missingCoins: missing);
    }
    _selectedItemIds.add(itemId);
    notifyListeners();
    return const GoldfishToggleResult(changed: true);
  }

  GoldfishSelectionResult checkSelection() {
    final missing = <String>[
      for (final requirement in _level.requirements)
        if (!requirement.acceptedItemIds.any(_selectedItemIds.contains))
          requirement.label,
    ];
    final overBudget = spent > _level.budget;
    final reserveTooSmall = remaining < _level.minimumReserve;
    _result = GoldfishSelectionResult(
      isSuccessful: missing.isEmpty && !overBudget && !reserveTooSmall,
      spent: spent,
      remaining: remaining,
      missingRequirements: missing,
      isOverBudget: overBudget,
      isReserveTooSmall: reserveTooSmall,
    );
    _resultLines = _result!.isSuccessful
        ? _level.successLines
        : missing.isNotEmpty
        ? _level.missingLines
        : overBudget
        ? _level.budgetLines
        : _level.reserveLines;
    _dialoguePageIndex = 0;
    _phase = GoldfishGamePhase.resultDialogue;
    notifyListeners();
    return _result!;
  }

  void reviseSelection() {
    if (_phase != GoldfishGamePhase.result || _result?.isSuccessful == true) {
      return;
    }
    _result = null;
    _resultLines = const [];
    _phase = GoldfishGamePhase.shopping;
    notifyListeners();
  }

  void replay() {
    _selectedItemIds.clear();
    _result = null;
    _resultLines = const [];
    _dialoguePageIndex = 0;
    _phase = GoldfishGamePhase.shopping;
    notifyListeners();
  }

  void startLevel(GoldfishLevelConfig level) {
    _level = level;
    _selectedItemIds.clear();
    _result = null;
    _resultLines = const [];
    _dialoguePageIndex = 0;
    _phase = GoldfishGamePhase.intro;
    notifyListeners();
  }
}
