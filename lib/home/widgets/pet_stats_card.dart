import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// One of the pet's three needs, drawn as a coloured badge, a bar and a
/// percentage — the shape the reference screen uses.
class PetStat {
  const PetStat({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
  });

  final String label;
  final IconData icon;
  final Color color;

  /// 0-100, as the backend stores it.
  final int value;
}

class PetStatsCard extends StatelessWidget {
  const PetStatsCard({super.key, required this.stats});

  final List<PetStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: AppColors.fieldBorder.withValues(alpha: 0.4),
              ),
            _StatRow(stat: stats[i]),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stat});

  final PetStat stat;

  @override
  Widget build(BuildContext context) {
    final fraction = (stat.value / 100).clamp(0.0, 1.0);
    return Semantics(
      label: '${stat.label}: ${stat.value} процентов',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: stat.color,
                shape: BoxShape.circle,
              ),
              child: Icon(stat.icon, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 86,
              child: Text(
                stat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardRowLabel,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 14,
                    backgroundColor: AppColors.parchmentDark,
                    valueColor: AlwaysStoppedAnimation(stat.color),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 64,
              // "100%" must never break onto two lines; at a large text scale
              // it shrinks to fit instead.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${stat.value}%',
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.counterValue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
