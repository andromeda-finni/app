import 'dart:math';

import 'package:flutter/foundation.dart';

import 'fox_event_content.dart';
import 'fox_event_models.dart';

const kDefaultFoxEventChance = 0.25;

/// Decides when the Fox appears. The whole application calls [startNextDay]
/// once when its own game-day boundary is crossed. A due return visit always
/// wins over a new random roll.
class FoxRandomEventEngine extends ChangeNotifier {
  FoxRandomEventEngine({
    this.triggerProbability = kDefaultFoxEventChance,
    FoxAgeGroup? ageGroup,
    FoxRuntimeMode? mode,
    Random? random,
  }) : assert(triggerProbability >= 0 && triggerProbability <= 1),
       _ageGroup = ageGroup ?? FoxAgeGroup.younger,
       _mode = mode ?? FoxRuntimeMode.demo,
       _random = random ?? Random();

  final double triggerProbability;
  final Random _random;

  int _gameDay = 0;
  FoxAgeGroup _ageGroup;
  FoxRuntimeMode _mode;
  FoxEventSession? _session;
  final Set<String> _completedScriptIds = <String>{};

  int get gameDay => _gameDay;
  FoxAgeGroup get ageGroup => _ageGroup;
  FoxRuntimeMode get mode => _mode;
  FoxEventSession? get session => _session;
  bool get hasPausedConversation => _session?.status == FoxSessionStatus.active;
  bool get isWaitingForReturn =>
      _session?.status == FoxSessionStatus.waitingForNextDay;

  void setAgeGroup(FoxAgeGroup value) {
    if (_session != null || value == _ageGroup) return;
    _ageGroup = value;
    notifyListeners();
  }

  void setMode(FoxRuntimeMode value) {
    if (_session != null || value == _mode) return;
    _mode = value;
    notifyListeners();
  }

  /// Advances the app's game clock by exactly one day. In demo mode
  /// [forceEvent] is normally true so an expert can reliably see the feature.
  FoxEventLaunch? startNextDay({bool forceEvent = false}) {
    _gameDay += 1;

    final active = _session;
    if (active != null) {
      if (active.status == FoxSessionStatus.waitingForNextDay &&
          (active.dueGameDay ?? _gameDay) <= _gameDay) {
        active
          ..status = FoxSessionStatus.active
          ..dueGameDay = null;
        notifyListeners();
        return FoxEventLaunch(session: active, isReturnVisit: true);
      }
      if (active.status == FoxSessionStatus.active) {
        notifyListeners();
        return FoxEventLaunch(session: active, isReturnVisit: false);
      }
    }

    _discardCompletedSession();
    if (!forceEvent && _random.nextDouble() >= triggerProbability) {
      notifyListeners();
      return null;
    }

    final script = _pickScript();
    final session = FoxEventSession(
      scriptId: script.id,
      currentNodeId: script.initialNodeId,
    );
    _session = session;
    notifyListeners();
    return FoxEventLaunch(session: session, isReturnVisit: false);
  }

  FoxEventLaunch? resumeConversation() {
    final active = _session;
    if (active == null || active.status != FoxSessionStatus.active) return null;
    return FoxEventLaunch(session: active, isReturnVisit: false);
  }

  void acceptDialogResult(FoxDialogResult result) {
    final active = _session;
    if (active == null) return;
    switch (result) {
      case FoxDialogResult.paused:
        break;
      case FoxDialogResult.waitingForNextDay:
        active.status = FoxSessionStatus.waitingForNextDay;
        active.dueGameDay ??= _gameDay + 1;
        break;
      case FoxDialogResult.completed:
        active.status = FoxSessionStatus.completed;
        _completedScriptIds.add(active.scriptId);
        _session = null;
        break;
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'gameDay': _gameDay,
    'ageGroup': _ageGroup.name,
    'mode': _mode.name,
    'completedScriptIds': _completedScriptIds.toList(growable: false),
    'session': _session?.toJson(),
  };

  void restoreFromJson(Map<String, dynamic> json) {
    _gameDay = json['gameDay'] as int? ?? 0;
    _ageGroup = FoxAgeGroup.values.byName(
      json['ageGroup'] as String? ?? FoxAgeGroup.younger.name,
    );
    _mode = FoxRuntimeMode.values.byName(
      json['mode'] as String? ?? FoxRuntimeMode.demo.name,
    );
    _completedScriptIds
      ..clear()
      ..addAll(
        (json['completedScriptIds'] as List<dynamic>? ?? const [])
            .cast<String>(),
      );
    final rawSession = json['session'];
    _session = rawSession is Map<String, dynamic>
        ? FoxEventSession.fromJson(rawSession)
        : null;
    notifyListeners();
  }

  FoxScript _pickScript() {
    final available = foxScriptsFor(_ageGroup);
    final unseen = available
        .where((script) => !_completedScriptIds.contains(script.id))
        .toList(growable: false);
    if (unseen.isNotEmpty) return unseen.first;

    // Once a difficulty line is complete, begin the same ordered sequence
    // again instead of repeatedly selecting a random story.
    _completedScriptIds.removeAll(available.map((script) => script.id));
    return available.first;
  }

  void _discardCompletedSession() {
    if (_session?.status == FoxSessionStatus.completed) _session = null;
  }
}
