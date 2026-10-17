import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'catch_food_models.dart';

class CatchFoodEntryCard extends StatelessWidget {
  const CatchFoodEntryCard({super.key, required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.cardBg,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.fieldBorder),
      borderRadius: BorderRadius.circular(AppRadii.lg),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: const Key('open-catch-food'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                '$catchFoodAssetRoot/game_entry.webp',
                width: 88,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Лови корм', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Поиграй с питомцем между заданиями',
                    style: AppTextStyles.swatchLabel,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.crimson),
          ],
        ),
      ),
    ),
  );
}
