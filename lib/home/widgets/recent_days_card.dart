import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/recent_day.dart';

class RecentDaysCard extends StatelessWidget {
  const RecentDaysCard({super.key, required this.days});

  final List<RecentDay> days;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
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
              const Icon(Icons.history, color: AppColors.crimsonDark),
              const SizedBox(width: 10),
              Text('Последние дни', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 6),
          for (final day in days.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                day.planFollowed
                    ? Icons.check_circle_outline
                    : Icons.tips_and_updates_outlined,
                color: day.planFollowed
                    ? AppColors.leafGreen
                    : AppColors.coinGold,
              ),
              title: Text('Неделя ${day.week}, день ${day.dayOfWeek}'),
              subtitle: Text(day.feedback),
            ),
        ],
      ),
    );
  }
}
