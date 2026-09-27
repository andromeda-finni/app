class ParentTask {
  const ParentTask({
    required this.id,
    required this.title,
    required this.rewardAmount,
    required this.status,
  });

  final String id;
  final String title;
  final int rewardAmount;
  final String status;

  bool get canSubmit => status == 'AVAILABLE' || status == 'IN_PROGRESS';

  factory ParentTask.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final reward = json['reward_amount'];
    final status = json['status'];
    if (id is! String ||
        title is! String ||
        reward is! num ||
        reward != reward.toInt() ||
        reward <= 0 ||
        status is! String) {
      throw const FormatException('Invalid parent task');
    }
    return ParentTask(
      id: id,
      title: title,
      rewardAmount: reward.toInt(),
      status: status,
    );
  }
}
