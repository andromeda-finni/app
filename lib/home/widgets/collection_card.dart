import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The artefact shelf. Empty slots are drawn as dashed silhouettes so the
/// shelf reads as "there is room for three things here" rather than as a
/// broken or still-loading card.
class CollectionCard extends StatelessWidget {
  const CollectionCard({super.key, this.slots = 3});

  final int slots;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/icons/chest.png', width: 30, height: 30),
              const SizedBox(width: 10),
              Text('Коллекция', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (var i = 0; i < slots; i++) const _EmptySlot()],
          ),
          const SizedBox(height: 8),
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.parchmentDark,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Артефакты появятся после квестов и покупок.',
              textAlign: TextAlign.center,
              style: AppTextStyles.swatchLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.parchment.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.8)),
      ),
      child: Icon(
        Icons.pets,
        size: 26,
        color: AppColors.inkMuted.withValues(alpha: 0.45),
      ),
    );
  }
}
