/// The child's current game period and its spending plan, as
/// `GET /periods/active` returns it (null when no period is running).
class ActivePeriod {
  const ActivePeriod({
    required this.id,
    required this.requiredNeedAmount,
    required this.budgetPlanId,
    required this.budgetPlanStatus,
    required this.availableAmount,
    required this.needAmount,
    required this.wantAmount,
    required this.savingsAmount,
  });

  final String id;

  /// The floor the server enforces on the must-haves share.
  final int requiredNeedAmount;
  final String? budgetPlanId;
  final String? budgetPlanStatus;
  final int availableAmount;
  final int needAmount;
  final int wantAmount;
  final int savingsAmount;

  bool get isConfirmed => budgetPlanStatus == 'CONFIRMED';

  static int _int(Object? value) =>
      value is int ? value : int.tryParse('${value ?? ''}') ?? 0;

  static ActivePeriod? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String) return null;
    return ActivePeriod(
      id: id,
      requiredNeedAmount: _int(json['required_need_amount']),
      budgetPlanId: json['budget_plan_id'] as String?,
      budgetPlanStatus: json['budget_plan_status'] as String?,
      availableAmount: _int(json['available_amount']),
      needAmount: _int(json['need_amount']),
      wantAmount: _int(json['want_amount']),
      savingsAmount: _int(json['savings_amount']),
    );
  }
}
