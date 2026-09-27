import 'package:flutter/material.dart';

import '../onboarding/widgets/back_circle_button.dart';
import '../theme/app_theme.dart';
import 'child_overview.dart';

/// The parent's read-only view of one linked child. Everything shown comes
/// from the child's real account; nothing here is sample content.
class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({
    super.key,
    required this.overview,
    required this.children,
    required this.selectedChildUserId,
    required this.onChildSelected,
    required this.onRefresh,
    required this.onInviteChild,
    required this.onExitToRoleChoice,
    required this.onCreateTask,
    required this.onVerifyTask,
    required this.busy,
    this.error,
  });

  final ChildOverview overview;
  final List<({String childUserId, String petName})> children;
  final String selectedChildUserId;
  final ValueChanged<String> onChildSelected;
  final Future<void> Function() onRefresh;
  final VoidCallback onInviteChild;
  final VoidCallback onExitToRoleChoice;
  final Future<void> Function(String title, int rewardAmount) onCreateTask;
  final ValueChanged<String> onVerifyTask;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final attention = _attentionItems(overview);
    return Scaffold(
      backgroundColor: const Color(0xFFF1EEE8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              color: AppColors.crimson,
              onRefresh: onRefresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  _Header(onBack: onExitToRoleChoice),
                  const SizedBox(height: 14),
                  if (children.length > 1) ...[
                    _ChildPicker(
                      children: children,
                      selectedChildUserId: selectedChildUserId,
                      onSelected: onChildSelected,
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    '${overview.petName}: прогресс',
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 28,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Стадия ${overview.stage} из 3 · '
                    'кошелёк ${overview.wallet} · копилка ${overview.savings}',
                    style: AppTextStyles.swatchLabel,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Заданий пройдено',
                          value: '${overview.completedQuests.length}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          label: 'Дней по плану',
                          value:
                              '${overview.daysFollowed} из ${overview.daysFinished}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          label: 'Нужен разговор',
                          value: '${attention.length}',
                          alert: attention.isNotEmpty,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final item in attention) ...[
                    _AttentionCard(title: item.title, detail: item.detail),
                    const SizedBox(height: 10),
                  ],
                  if (overview.goalName != null)
                    _InfoCard(
                      icon: Icons.savings_outlined,
                      title: 'Копит на «${overview.goalName}»',
                      detail:
                          'Накоплено ${overview.goalSaved} из ${overview.goalTarget} монет.',
                    ),
                  if (overview.activeDay != null) ...[
                    const SizedBox(height: 10),
                    _InfoCard(
                      icon: Icons.assignment_outlined,
                      title: _dayTitle(overview.activeDay!),
                      detail: _dayDetail(overview.activeDay!),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _ParentTasksSection(
                    tasks: overview.parentTasks,
                    rewardLimit: overview.parentRewardLimit,
                    busy: busy,
                    onCreate: onCreateTask,
                    onVerify: onVerifyTask,
                    error: error,
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Последние действия',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 22,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (overview.activity.isEmpty)
                    Text(
                      'Пока ничего не происходило. Действия ребёнка появятся здесь.',
                      style: AppTextStyles.swatchLabel,
                    )
                  else
                    for (final row in overview.activity)
                      _ActivityTile(row: row),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onInviteChild,
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: const Text('Пригласить ещё одного ребёнка'),
                    style: _outlined,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onExitToRoleChoice,
                    icon: const Icon(Icons.switch_account_outlined),
                    label: const Text('Выйти к выбору пользователя'),
                    style: _outlined,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ParentTasksSection extends StatelessWidget {
  const _ParentTasksSection({
    required this.tasks,
    required this.rewardLimit,
    required this.busy,
    required this.onCreate,
    required this.onVerify,
    this.error,
  });

  final List<Map<String, dynamic>> tasks;
  final int rewardLimit;
  final bool busy;
  final Future<void> Function(String title, int rewardAmount) onCreate;
  final ValueChanged<String> onVerify;
  final String? error;

  Future<void> _showCreateDialog(BuildContext context) async {
    if (rewardLimit <= 0) return;
    var title = '';
    var reward = 1;
    final result = await showDialog<({String title, int reward})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Новое домашнее дело'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                autofocus: true,
                maxLength: 160,
                onChanged: (value) => title = value,
                decoration: const InputDecoration(
                  labelText: 'Что нужно сделать',
                  hintText: 'Например, полить цветы',
                ),
              ),
              const SizedBox(height: 12),
              Text('Награда: $reward монет'),
              Slider(
                value: reward.toDouble(),
                min: 1,
                max: rewardLimit.toDouble(),
                divisions: rewardLimit > 1 ? rewardLimit - 1 : null,
                label: '$reward',
                onChanged: (value) =>
                    setDialogState(() => reward = value.round()),
              ),
              Text(
                'Лимит приложения: до $rewardLimit монет за дело.',
                style: AppTextStyles.swatchLabel,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final trimmedTitle = title.trim();
                if (trimmedTitle.isNotEmpty) {
                  Navigator.pop(dialogContext, (
                    title: trimmedTitle,
                    reward: reward,
                  ));
                }
              },
              child: const Text('Назначить'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await onCreate(result.title, result.reward);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9D2C6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Домашние дела',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Добавить дело',
                onPressed: busy || rewardLimit <= 0
                    ? null
                    : () => _showCreateDialog(context),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          if (tasks.isEmpty)
            Text(
              'Назначьте небольшое дело — награда поступит только после вашего подтверждения.',
              style: AppTextStyles.swatchLabel,
            )
          else
            for (final task in tasks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${task['title'] ?? ''}'),
                subtitle: Text(
                  '${task['reward_amount'] ?? 0} монет · ${_parentTaskStatus('${task['status'] ?? ''}')}',
                ),
                trailing: task['status'] == 'AWAITING_PARENT'
                    ? FilledButton(
                        onPressed: busy
                            ? null
                            : () => onVerify('${task['id']}'),
                        child: const Text('Подтвердить'),
                      )
                    : task['status'] == 'VERIFIED'
                    ? const Icon(Icons.check_circle, color: AppColors.leafGreen)
                    : null,
              ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: AppTextStyles.swatchLabel.copyWith(
                color: AppColors.crimson,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _parentTaskStatus(String status) => switch (status) {
  'AVAILABLE' || 'IN_PROGRESS' => 'ждёт выполнения',
  'AWAITING_PARENT' => 'ребёнок отметил как выполненное',
  'VERIFIED' => 'награда выдана',
  _ => status,
};

class _ChildPicker extends StatelessWidget {
  const _ChildPicker({
    required this.children,
    required this.selectedChildUserId,
    required this.onSelected,
  });

  final List<({String childUserId, String petName})> children;
  final String selectedChildUserId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: const Key('parent-child-picker'),
      initialValue: selectedChildUserId,
      decoration: const InputDecoration(
        labelText: 'Чей прогресс показать',
        prefixIcon: Icon(Icons.family_restroom_rounded),
      ),
      items: [
        for (var index = 0; index < children.length; index++)
          DropdownMenuItem(
            value: children[index].childUserId,
            child: Text(_labelFor(index)),
          ),
      ],
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
    );
  }

  String _labelFor(int index) {
    final child = children[index];
    final duplicateCount = children
        .where((candidate) => candidate.petName == child.petName)
        .length;
    return duplicateCount > 1
        ? '${child.petName} · ${index + 1}'
        : child.petName;
  }
}

final _outlined = OutlinedButton.styleFrom(
  foregroundColor: AppColors.ink,
  padding: const EdgeInsets.symmetric(vertical: 14),
  side: const BorderSide(color: AppColors.fieldBorder),
);

/// Only situations a parent can actually help with; an empty list means the
/// dashboard shows no warning at all rather than a reassuring placeholder.
List<({String title, String detail})> _attentionItems(ChildOverview o) => [
  if (o.unpaidEventTitle != null)
    (
      title: o.unpaidEventTitle!,
      detail:
          '${o.petName} ждёт оплаты ${o.unpaidEventAmount} монет. '
          'Хороший повод обсудить, зачем нужен запас на непредвиденное.',
    ),
  for (final title in o.questsNeedingReview)
    (
      title: 'Тема «$title»',
      detail: 'Задание пройдено, но не с первой попытки. Стоит разобрать его вместе.',
    ),
  if (o.recentDays.isNotEmpty && o.recentDays.first['plan_followed'] == false)
    (
      title: 'Последний день прошёл не по плану',
      detail: '${o.recentDays.first['feedback_text'] ?? ''}',
    ),
];

String _dayTitle(Map<String, dynamic> day) {
  final confirmed = day['plan_status'] == 'CONFIRMED';
  return 'День ${day['sequence_no']}: '
      '${confirmed ? 'план утверждён' : 'план ещё составляется'}';
}

String _dayDetail(Map<String, dynamic> day) =>
    'Надо ${day['need_amount']} · Хочу ${day['want_amount']} · '
    'В копилку ${day['savings_amount']}';

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BackCircleButton(onPressed: onBack),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Кабинет родителя',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.alert = false});

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert ? AppColors.crimsonFaded : const Color(0xFFD9D2C6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: alert ? AppColors.crimson : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2E4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2A970), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.priority_high_rounded, color: AppColors.crimson),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  style: const TextStyle(height: 1.35, color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9D2C6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.leafGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final amount = (row['delta_amount'] as num?)?.toInt() ?? 0;
    final positive = amount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: positive ? AppColors.leafGreen : AppColors.crimson,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatMoment(row['occurred_at']),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activityLabel(row['event_type'] as String?),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : '−'}${amount.abs()}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: positive ? AppColors.leafGreen : AppColors.crimson,
            ),
          ),
        ],
      ),
    );
  }
}
