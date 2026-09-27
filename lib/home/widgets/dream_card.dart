import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/home_economy_state.dart';

class DreamCard extends StatelessWidget {
  const DreamCard({super.key, required this.goal, required this.onTap});

  final ActiveGoal? goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currentGoal = goal;
    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.fieldBorder),
      ),
      child: InkWell(
        key: const Key('dream-card'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 126),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    color: AppColors.infoBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 42,
                    color: AppColors.coinGold,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Моя мечта', style: AppTextStyles.supporting),
                      const SizedBox(height: 3),
                      Text(
                        currentGoal?.name ?? 'Выбрать мечту',
                        style: AppTextStyles.cardTitle,
                      ),
                      if (currentGoal != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: currentGoal.progress,
                            minHeight: 9,
                            backgroundColor: AppColors.parchmentDark,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.crimson,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${currentGoal.savedAmount} из ${currentGoal.targetAmount} монет',
                          style: AppTextStyles.swatchLabel,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 34),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
