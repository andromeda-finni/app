class RecentDay {
  const RecentDay({
    required this.week,
    required this.dayOfWeek,
    required this.planFollowed,
    required this.feedback,
  });

  final int week;
  final int dayOfWeek;
  final bool planFollowed;
  final String feedback;

  factory RecentDay.fromJson(Map<String, dynamic> json) {
    final week = (json['week'] as num?)?.toInt();
    final dayOfWeek = (json['dayOfWeek'] as num?)?.toInt();
    final feedback = json['feedback_text'];
    if (week == null || dayOfWeek == null || feedback is! String) {
      throw const FormatException('recent day is incomplete');
    }
    return RecentDay(
      week: week,
      dayOfWeek: dayOfWeek,
      planFollowed: json['plan_followed'] == true,
      feedback: feedback,
    );
  }
}
