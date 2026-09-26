/// A linked child's progress as `GET /parent/children/:id/overview` returns
/// it. Parsing lives here so the dashboard only deals with ready values.
class ChildOverview {
  ChildOverview._(this._json);

  factory ChildOverview.fromJson(Map<String, dynamic> json) =>
      ChildOverview._(json);

  final Map<String, dynamic> _json;

  Map<String, dynamic> get _pet => _map(_json['pet']) ?? const {};

  String get petName => _pet['pet_name'] as String? ?? 'Питомец';
  int get stage => _int(_pet['evolution_stage']);
  int get health => _int(_pet['health_level'], 100);
  int get satiety => _int(_pet['energy_level'], 100);
  int get joy => _int(_pet['joy_level'], 50);

  int get wallet => _int(_map(_json['wallets'])?['SPENDABLE']);
  int get savings => _int(_map(_json['wallets'])?['SAVINGS']);

  String? get goalName => _map(_json['goal'])?['name'] as String?;
  int get goalTarget => _int(_map(_json['goal'])?['target_amount']);
  int get goalSaved => _int(_map(_json['goal'])?['saved_amount']);

  Map<String, dynamic>? get activeDay => _map(_json['activeDay']);

  String? get unpaidEventTitle =>
      _map(_json['activeEvent'])?['title'] as String?;
  int get unpaidEventAmount => _int(_map(_json['activeEvent'])?['amount_due']);

  List<Map<String, dynamic>> get completedQuests =>
      _list(_json['completedQuests']);

  /// Quests the child finished only after a wrong answer — the honest signal
  /// that a topic is worth talking through together.
  List<String> get questsNeedingReview => [
    for (final quest in completedQuests)
      if (quest['needed_hints'] == true) quest['title'] as String,
  ];

  int get daysFinished => _int(_map(_json['days'])?['finished']);
  int get daysFollowed => _int(_map(_json['days'])?['followed']);

  List<Map<String, dynamic>> get recentDays => _list(_json['recentDays']);

  List<Map<String, dynamic>> get parentTasks => _list(_json['parentTasks']);

  int get parentRewardLimit => _int(_map(_json['rules'])?['parentRewardLimit']);

  /// Ledger rows for the activity feed. A transfer is booked on both wallets;
  /// only its savings/frost side is kept so one action appears once.
  List<Map<String, dynamic>> get activity => [
    for (final row in _list(_json['recentActivity']))
      if (!_isMirrorLeg(row)) row,
  ];

  static bool _isMirrorLeg(Map<String, dynamic> row) {
    final type = row['event_type'];
    final wallet = row['wallet_kind'];
    if (type == 'SAVINGS_DEPOSIT' || type == 'SAVINGS_WITHDRAWAL') {
      return wallet != 'SAVINGS';
    }
    if (type == 'FROST_DEPOSIT' || type == 'FROST_WITHDRAWAL') {
      return wallet != 'FROZEN';
    }
    return false;
  }

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static List<Map<String, dynamic>> _list(Object? value) => [
    if (value is List)
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
  ];

  static int _int(Object? value, [int fallback = 0]) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? fallback;
}

const _eventLabels = <String, String>{
  'START_GRANT': 'Стартовые монеты',
  'DAILY_INCOME': 'Монеты за день',
  'STREAK_BONUS': 'Бонус за серию дней',
  'PERIOD_GRANT': 'Монеты на игровой день',
  'QUEST_REWARD': 'Награда за задание',
  'PARENT_TASK_REWARD': 'Награда за ваше задание',
  'PURCHASE': 'Покупка',
  'SAVINGS_DEPOSIT': 'Отложено в копилку',
  'SAVINGS_WITHDRAWAL': 'Взято из копилки',
  'FROST_DEPOSIT': 'Вклад в сундук Морозко',
  'FROST_WITHDRAWAL': 'Возврат из сундука Морозко',
  'FROST_BONUS': 'Бонус сундука Морозко',
  'GOAL_REDEMPTION': 'Мечта получена',
  'PET_EVENT_PAYMENT': 'Лечение питомца',
  'SCAM_OFFER_LOSS': 'Потеря на нечестном предложении',
};

String activityLabel(String? eventType) =>
    _eventLabels[eventType] ?? 'Операция';

/// "25.09 · 21:33" in the device's time zone.
String formatMoment(Object? isoTimestamp) {
  final parsed = DateTime.tryParse('${isoTimestamp ?? ''}')?.toLocal();
  if (parsed == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(parsed.day)}.${two(parsed.month)} · '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}
