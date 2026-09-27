import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/parent_task.dart';

class ParentTasksCard extends StatelessWidget {
  const ParentTasksCard({
    super.key,
    required this.tasks,
    required this.busy,
    required this.onSubmit,
  });

  final List<ParentTask> tasks;
  final bool busy;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.family_restroom_outlined,
                color: AppColors.crimson,
                size: 26,
              ),
              const SizedBox(width: 10),
              Text('Домашние дела', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 8),
          for (final task in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(task.title, style: AppTextStyles.cardRowLabel),
              subtitle: Text(
                '${task.rewardAmount} монет · ${_statusLabel(task.status)}',
                style: AppTextStyles.supporting,
              ),
              trailing: task.canSubmit
                  ? OutlinedButton(
                      onPressed: busy ? null : () => onSubmit(task.id),
                      child: const Text('Я сделал(а)'),
                    )
                  : task.status == 'VERIFIED'
                  ? const Icon(Icons.check_circle, color: AppColors.leafGreen)
                  : null,
            ),
        ],
      ),
    );
  }
}

String _statusLabel(String status) => switch (status) {
  'AVAILABLE' || 'IN_PROGRESS' => 'можно выполнить',
  'AWAITING_PARENT' => 'ждёт подтверждения родителя',
  'VERIFIED' => 'подтверждено',
  _ => status,
};
