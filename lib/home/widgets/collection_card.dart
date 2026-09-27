import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The artefact shelf. Empty slots are drawn as dashed silhouettes so the
/// shelf reads as "there is room for three things here" rather than as a
/// broken or still-loading card.
class CollectionCard extends StatelessWidget {
  const CollectionCard({super.key, this.items = const [], this.slots = 3});

  final List<String> items;
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
            children: [
              for (var i = 0; i < slots; i++)
                i < items.length
                    ? _CollectionSlot(name: items[i])
                    : const _EmptySlot(),
            ],
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
              items.isEmpty
                  ? 'Артефакты появятся после квестов и покупок.'
                  : 'Собрано: ${items.length}',
              textAlign: TextAlign.center,
              style: AppTextStyles.swatchLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionSlot extends StatelessWidget {
  const _CollectionSlot({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: name,
      image: true,
      child: Container(
        width: 62,
        height: 68,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.infoBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.coinGold),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.coinGold, size: 25),
            const SizedBox(height: 3),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.stepCounter.copyWith(
                color: AppColors.ink,
                fontSize: 10,
              ),
            ),
          ],
        ),
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
