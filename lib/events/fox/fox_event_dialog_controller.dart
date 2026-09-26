import 'package:flutter/foundation.dart';

import 'fox_event_models.dart';
import 'fox_event_wallet.dart';

class FoxChoiceResult {
  const FoxChoiceResult._(this.dialogResult);

  const FoxChoiceResult.stayed() : this._(null);
  const FoxChoiceResult.waiting() : this._(FoxDialogResult.waitingForNextDay);
  const FoxChoiceResult.completed() : this._(FoxDialogResult.completed);

  final FoxDialogResult? dialogResult;
}

class FoxEventDialogController extends ChangeNotifier {
  FoxEventDialogController({
    required this.script,
    required this.session,
    required this.wallet,
    required this.mode,
    required this.currentGameDay,
    required this.isReturnVisit,
    this.demoTransitionDuration = const Duration(milliseconds: 700),
  });

  final FoxScript script;
  final FoxEventSession session;
  final FoxEventWallet wallet;
  final FoxRuntimeMode mode;
  final int currentGameDay;
  final bool isReturnVisit;
  final Duration demoTransitionDuration;

  bool _showArrival = true;
  bool _busy = false;
  bool _transitioning = false;
  String? _errorMessage;

  bool get showArrival => _showArrival;
  bool get busy => _busy;
  bool get transitioning => _transitioning;
  String? get errorMessage => _errorMessage;
  FoxStoryNode get node => script.node(session.currentNodeId);

  Future<void> continueFromArrival() async {
    if (_busy) return;
    _showArrival = false;
    await _applyCurrentNodeEffect();
    notifyListeners();
  }

  Future<FoxChoiceResult> select(FoxChoice choice) async {
    if (_busy || _transitioning || node.terminal) {
      return const FoxChoiceResult.stayed();
    }
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (choice.coinDelta != 0) {
        await wallet.applyDelta(
          delta: choice.coinDelta,
          effectKey: _choiceEffectKey(node.id, choice.id),
        );
      }
      session.choiceHistory.add('${node.id}:${choice.id}');

      final next = script.node(choice.nextNodeId);
      session.currentNodeId = next.id;

      if (next.waitUntilNextGameDay && mode == FoxRuntimeMode.normal) {
        session
          ..status = FoxSessionStatus.waitingForNextDay
          ..dueGameDay = currentGameDay + 1;
        return const FoxChoiceResult.waiting();
      }

      if (next.waitUntilNextGameDay && mode == FoxRuntimeMode.demo) {
        _transitioning = true;
        _busy = false;
        notifyListeners();
        if (demoTransitionDuration > Duration.zero) {
          await Future<void>.delayed(demoTransitionDuration);
        }
        _transitioning = false;
        await _applyCurrentNodeEffect();
        notifyListeners();
        return next.terminal
            ? const FoxChoiceResult.completed()
            : const FoxChoiceResult.stayed();
      }

      await _applyCurrentNodeEffect();
      notifyListeners();
      return next.terminal
          ? const FoxChoiceResult.completed()
          : const FoxChoiceResult.stayed();
    } on FoxInsufficientFundsException {
      _errorMessage = 'Сейчас не хватает монет, чтобы дать их Лису.';
      return const FoxChoiceResult.stayed();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _applyCurrentNodeEffect() async {
    final current = node;
    final key = _nodeEffectKey(current.id);
    if (current.coinDeltaOnEnter != 0 &&
        !session.appliedEffectKeys.contains(key)) {
      await wallet.applyDelta(delta: current.coinDeltaOnEnter, effectKey: key);
      session.appliedEffectKeys.add(key);
    }
    if (current.terminal) session.status = FoxSessionStatus.completed;
  }

  String _choiceEffectKey(String nodeId, String choiceId) =>
      'fox:${script.id}:$nodeId:$choiceId';

  String _nodeEffectKey(String nodeId) => 'fox:${script.id}:$nodeId:enter';
}
