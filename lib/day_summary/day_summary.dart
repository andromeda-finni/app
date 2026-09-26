final class DaySummaryAmounts {
  const DaySummaryAmounts({
    required this.need,
    required this.want,
    required this.savings,
  });

  final int need;
  final int want;
  final int savings;

  factory DaySummaryAmounts.fromJson(Map<String, dynamic> json) =>
      DaySummaryAmounts(
        need: _asInt(json['need']),
        want: _asInt(json['want']),
        savings: _asInt(json['savings']),
      );
}

final class DaySummary {
  const DaySummary({
    required this.periodId,
    required this.sequenceNo,
    required this.earnedAmount,
    required this.plan,
    required this.actual,
    required this.needCovered,
    required this.planFollowed,
    required this.feedback,
    required this.recommendations,
  });

  final String periodId;
  final int sequenceNo;
  final int earnedAmount;
  final DaySummaryAmounts plan;
  final DaySummaryAmounts actual;
  final bool needCovered;
  final bool planFollowed;
  final String feedback;
  final List<String> recommendations;

  factory DaySummary.fromJson(Map<String, dynamic> json) {
    final periodId = json['periodId'];
    final plan = json['plan'];
    final actual = json['actual'];
    final feedback = json['feedback'];
    if (periodId is! String ||
        plan is! Map ||
        actual is! Map ||
        feedback is! String) {
      throw const FormatException('Invalid day summary response');
    }

    return DaySummary(
      periodId: periodId,
      sequenceNo: _asInt(json['sequenceNo']),
      earnedAmount: _asInt(json['earnedAmount']),
      plan: DaySummaryAmounts.fromJson(Map<String, dynamic>.from(plan)),
      actual: DaySummaryAmounts.fromJson(Map<String, dynamic>.from(actual)),
      needCovered: json['needCovered'] == true,
      planFollowed: json['planFollowed'] == true,
      feedback: feedback,
      recommendations: (json['recommendations'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;
