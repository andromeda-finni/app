import 'dart:math';

import 'package:flutter/foundation.dart';

import 'turnip_game_models.dart';

class TurnipGameController extends ChangeNotifier {
  TurnipGameController({
    required this.difficulty,
    this.wrongAttemptsBeforeHint = 3,
    Random? random,
  }) : assert(wrongAttemptsBeforeHint > 0),
       _random = random ?? Random() {
    _shuffleTray();
  }

  final TurnipDifficulty difficulty;
  final int wrongAttemptsBeforeHint;
  final Random _random;

  TurnipGamePhase _phase = TurnipGamePhase.intro;
  int _introPageIndex = 0;
  final List<TurnipCharacter> _placedCharacters = [];
  final List<TurnipCharacter> _trayCharacters = [];
  int _wrongAttempts = 0;
  int _consecutiveWrongAttempts = 0;
  bool _hintVisible = false;
  bool _hintUsed = false;
  TurnipCharacter? _lastRejectedCharacter;

  TurnipGamePhase get phase => _phase;
  int get introPageIndex => _introPageIndex;
  List<TurnipCharacter> get placedCharacters =>
      List.unmodifiable(_placedCharacters);
  List<TurnipCharacter> get trayCharacters =>
      List.unmodifiable(_trayCharacters);
  int get wrongAttempts => _wrongAttempts;
  bool get hintVisible => _hintVisible;
  bool get hintUsed => _hintUsed;
  TurnipCharacter? get lastRejectedCharacter => _lastRejectedCharacter;

  TurnipCharacter? get expectedCharacter {
    if (_placedCharacters.length >= TurnipCharacter.values.length) return null;
    return TurnipCharacter.values[_placedCharacters.length];
  }

  void advanceIntro({required int pageCount}) {
    if (_phase != TurnipGamePhase.intro || pageCount <= 0) return;
    if (_introPageIndex < pageCount - 1) {
      _introPageIndex++;
    } else {
      _phase = TurnipGamePhase.playing;
    }
    notifyListeners();
  }

  TurnipPlacementResult place(TurnipCharacter character) {
    if (_phase != TurnipGamePhase.playing ||
        _placedCharacters.contains(character)) {
      return TurnipPlacementResult.ignored;
    }

    if (difficulty == TurnipDifficulty.hard && character != expectedCharacter) {
      _wrongAttempts++;
      _consecutiveWrongAttempts++;
      _lastRejectedCharacter = character;
      if (_consecutiveWrongAttempts >= wrongAttemptsBeforeHint) {
        _showHint();
      }
      notifyListeners();
      return TurnipPlacementResult.rejected;
    }

    _placedCharacters.add(character);
    _consecutiveWrongAttempts = 0;
    _lastRejectedCharacter = null;
    if (_placedCharacters.length == TurnipCharacter.values.length) {
      _phase = TurnipGamePhase.pulling;
      notifyListeners();
      return TurnipPlacementResult.completed;
    }

    notifyListeners();
    return TurnipPlacementResult.accepted;
  }

  void showHint() {
    if (_phase != TurnipGamePhase.playing) return;
    _showHint();
    notifyListeners();
  }

  void hideHint() {
    if (!_hintVisible) return;
    _hintVisible = false;
    notifyListeners();
  }

  void finishPulling() {
    if (_phase != TurnipGamePhase.pulling) return;
    _phase = TurnipGamePhase.completed;
    notifyListeners();
  }

  TurnipGameResult get result => TurnipGameResult(
    difficulty: difficulty,
    questId: turnipQuestId,
    rewardAmount: difficulty.rewardAmount,
    wrongAttempts: _wrongAttempts,
    hintUsed: _hintUsed,
  );

  void restart({bool includeIntro = false}) {
    _phase = includeIntro ? TurnipGamePhase.intro : TurnipGamePhase.playing;
    _introPageIndex = 0;
    _placedCharacters.clear();
    _wrongAttempts = 0;
    _consecutiveWrongAttempts = 0;
    _hintVisible = false;
    _hintUsed = false;
    _lastRejectedCharacter = null;
    _shuffleTray();
    notifyListeners();
  }

  void _showHint() {
    _hintVisible = true;
    _hintUsed = true;
  }

  void _shuffleTray() {
    _trayCharacters
      ..clear()
      ..addAll(TurnipCharacter.values)
      ..shuffle(_random);
  }
}
