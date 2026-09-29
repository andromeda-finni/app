import 'package:flutter/foundation.dart';

import 'ivan_game_models.dart';

class IvanGameController extends ChangeNotifier {
  IvanGameController(this._level);

  IvanLevelConfig _level;
  IvanGamePhase _phase = IvanGamePhase.intro;
  int _introPageIndex = 0;
  final Set<String> _selectedItemIds = {};
  IvanSelectionResult? _result;

  IvanLevelConfig get level => _level;
  IvanGamePhase get phase => _phase;
  int get introPageIndex => _introPageIndex;
  Set<String> get selectedItemIds => Set.unmodifiable(_selectedItemIds);
  IvanSelectionResult? get result => _result;

  int get spent => _selectedItemIds.fold(
    0,
    (total, id) => total + _level.itemById(id).price,
  );

  int get remaining => _level.budget - spent;

  void advanceIntro() {
    if (_phase != IvanGamePhase.intro) return;
    if (_introPageIndex < _level.introLines.length - 1) {
      _introPageIndex++;
    } else {
      _phase = IvanGamePhase.shopping;
    }
    notifyListeners();
  }

  void toggleItem(String itemId) {
    if (_phase != IvanGamePhase.shopping) return;
    _level.itemById(itemId);
    if (!_selectedItemIds.add(itemId)) _selectedItemIds.remove(itemId);
    notifyListeners();
  }

  IvanSelectionResult checkSelection() {
    final missing = <String>[
      for (final requirement in _level.requirements)
        if (!requirement.acceptedItemIds.any(_selectedItemIds.contains))
          requirement.label,
    ];
    final overBudget = spent > _level.budget;
    _result = IvanSelectionResult(
      isSuccessful: missing.isEmpty && !overBudget,
      spent: spent,
      missingRequirements: missing,
      isOverBudget: overBudget,
    );
    _phase = IvanGamePhase.result;
    notifyListeners();
    return _result!;
  }

  void reviseSelection() {
    if (_phase != IvanGamePhase.result || _result?.isSuccessful == true) return;
    _result = null;
    _phase = IvanGamePhase.shopping;
    notifyListeners();
  }

  void replay() {
    _selectedItemIds.clear();
    _result = null;
    _introPageIndex = 0;
    _phase = IvanGamePhase.shopping;
    notifyListeners();
  }

  void startLevel(IvanLevelConfig level) {
    _level = level;
    _selectedItemIds.clear();
    _result = null;
    _introPageIndex = 0;
    _phase = IvanGamePhase.intro;
    notifyListeners();
  }
}
