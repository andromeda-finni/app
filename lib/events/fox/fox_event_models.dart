enum FoxAgeGroup { younger, older }

extension FoxAgeGroupLabel on FoxAgeGroup {
  String get label => switch (this) {
    FoxAgeGroup.younger => 'Нормальная',
    FoxAgeGroup.older => 'Сложная',
  };
}

enum FoxRuntimeMode { normal, demo }

extension FoxRuntimeModeLabel on FoxRuntimeMode {
  String get label => switch (this) {
    FoxRuntimeMode.normal => 'Обычный режим',
    FoxRuntimeMode.demo => 'Деморежим',
  };
}

enum FoxMood { friendly, sly }

enum FoxOutcomeTone { positive, caution, neutral }

enum FoxSessionStatus { active, waitingForNextDay, completed }

class FoxChoice {
  const FoxChoice({
    required this.id,
    required this.label,
    required this.nextNodeId,
    this.coinDelta = 0,
  });

  final String id;
  final String label;
  final String nextNodeId;

  /// Applied once when the choice is accepted. Negative values mean that the
  /// player gives coins to the Fox. The wallet implementation is responsible
  /// for refusing a delta that would make the balance negative.
  final int coinDelta;
}

class FoxStoryNode {
  const FoxStoryNode({
    required this.id,
    required this.speaker,
    required this.text,
    required this.mood,
    this.continuationTexts = const [],
    this.choices = const [],
    this.waitUntilNextGameDay = false,
    this.coinDeltaOnEnter = 0,
    this.groshikFeedback,
    this.outcomeTone = FoxOutcomeTone.neutral,
    this.terminal = false,
  });

  final String id;
  final String speaker;
  final String text;
  final FoxMood mood;
  final List<String> continuationTexts;
  final List<FoxChoice> choices;

  List<String> get textPages => [text, ...continuationTexts];

  /// In normal mode this node is shown on the following game day. In demo
  /// mode the dialog shows a short transition and opens it immediately.
  final bool waitUntilNextGameDay;

  /// Applied exactly once when the node becomes visible. It is used for debt
  /// repayments that happen when the Fox returns.
  final int coinDeltaOnEnter;
  final String? groshikFeedback;
  final FoxOutcomeTone outcomeTone;
  final bool terminal;
}

class FoxScript {
  const FoxScript({
    required this.id,
    required this.title,
    required this.ageGroup,
    required this.initialNodeId,
    required this.nodes,
  });

  final String id;
  final String title;
  final FoxAgeGroup ageGroup;
  final String initialNodeId;
  final Map<String, FoxStoryNode> nodes;

  FoxStoryNode node(String id) {
    final result = nodes[id];
    if (result == null) {
      throw StateError('Fox script $this has no node "$id".');
    }
    return result;
  }
}

class FoxEventSession {
  FoxEventSession({
    required this.scriptId,
    required this.currentNodeId,
    this.status = FoxSessionStatus.active,
    this.dueGameDay,
    Set<String>? appliedEffectKeys,
    List<String>? choiceHistory,
  }) : appliedEffectKeys = appliedEffectKeys ?? <String>{},
       choiceHistory = choiceHistory ?? <String>[];

  factory FoxEventSession.fromJson(Map<String, dynamic> json) {
    return FoxEventSession(
      scriptId: json['scriptId'] as String,
      currentNodeId: json['currentNodeId'] as String,
      status: FoxSessionStatus.values.byName(json['status'] as String),
      dueGameDay: json['dueGameDay'] as int?,
      appliedEffectKeys:
          (json['appliedEffectKeys'] as List<dynamic>? ?? const [])
              .cast<String>()
              .toSet(),
      choiceHistory: (json['choiceHistory'] as List<dynamic>? ?? const [])
          .cast<String>()
          .toList(),
    );
  }

  final String scriptId;
  String currentNodeId;
  FoxSessionStatus status;
  int? dueGameDay;
  final Set<String> appliedEffectKeys;
  final List<String> choiceHistory;

  Map<String, dynamic> toJson() => {
    'scriptId': scriptId,
    'currentNodeId': currentNodeId,
    'status': status.name,
    'dueGameDay': dueGameDay,
    'appliedEffectKeys': appliedEffectKeys.toList(growable: false),
    'choiceHistory': choiceHistory.toList(growable: false),
  };
}

class FoxEventLaunch {
  const FoxEventLaunch({required this.session, required this.isReturnVisit});

  final FoxEventSession session;
  final bool isReturnVisit;
}

enum FoxDialogResult { paused, waitingForNextDay, completed }
