import 'package:flutter/material.dart';

import '../../economy/economy_state.dart';
import '../../economy/item_artwork.dart';
import '../../theme/app_theme.dart';

enum ArtifactProductState { available, selected, locked }

/// Compact goal card used by the store's savings-goal catalog.
///
/// The card keeps browsing information separate from the goal action. The
/// leading area opens details, while the bottom control communicates the
/// server-authoritative goal state in words as well as colour.
class ArtifactProductCard extends StatelessWidget {
  const ArtifactProductCard({
    super.key,
    required this.item,
    required this.state,
    required this.savedAmount,
    required this.onDetails,
    this.onSelect,
  });

  final EconomyItem item;
  final ArtifactProductState state;
  final int savedAmount;
  final VoidCallback onDetails;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = state == ArtifactProductState.selected;
    final missing = (item.price - savedAmount).clamp(0, item.price);
    final progress = item.price == 0
        ? 0.0
        : (savedAmount / item.price).clamp(0, 1).toDouble();

    return Semantics(
      key: ValueKey('artifact-card-${item.id}'),
      container: true,
      label:
          '${item.name}, ${item.price} монет, ${_stateLabel(state)}${selected ? ', накоплено $savedAmount, осталось $missing' : ''}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E9),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: selected ? AppColors.leafGreen : const Color(0xFFD9AF70),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onDetails,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final vertical =
                          constraints.maxWidth < 300 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.5;
                      final art = ItemArtwork(
                        itemId: item.id,
                        imageAsset: item.imageAsset,
                        semanticLabel: item.name,
                        size: vertical ? 96 : 88,
                        borderRadius: AppRadii.md,
                        backgroundColor: const Color(0xFFFFEBC0),
                      );
                      final details = _ArtifactSummary(
                        item: item,
                        selected: selected,
                      );
                      if (vertical) {
                        return Column(
                          children: [
                            art,
                            const SizedBox(height: AppSpacing.xs),
                            details,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          art,
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: details),
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.inkMuted,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                label: 'Накоплено $savedAmount из ${item.price} монет',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: AppColors.parchmentDark,
                    color: AppColors.leafGreen,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                missing == 0
                    ? 'Цель собрана — забери её в Копилке'
                    : 'Накоплено $savedAmount · осталось $missing монет',
                style: AppTextStyles.swatchLabel,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            _action(),
          ],
        ),
      ),
    );
  }

  Widget _action() => switch (state) {
    ArtifactProductState.available => FilledButton.icon(
      onPressed: onSelect,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: AppColors.crimson,
      ),
      icon: const Icon(Icons.savings_outlined),
      label: const Text('Копить на это'),
    ),
    ArtifactProductState.selected => Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.leafGreen,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.white),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Моя цель',
              textAlign: TextAlign.center,
              style: AppTextStyles.button,
            ),
          ),
        ],
      ),
    ),
    ArtifactProductState.locked => Container(
      constraints: const BoxConstraints(minHeight: 50),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.inkMuted),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Сначала заверши текущую цель',
              textAlign: TextAlign.center,
              style: AppTextStyles.supporting,
            ),
          ),
        ],
      ),
    ),
  };
}

class _ArtifactSummary extends StatelessWidget {
  const _ArtifactSummary({required this.item, required this.selected});

  final EconomyItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (selected)
        Text(
          'МОЯ ЦЕЛЬ',
          style: AppTextStyles.stepCounter.copyWith(color: AppColors.leafGreen),
        ),
      Text(item.name, style: AppTextStyles.cardRowLabel),
      const SizedBox(height: AppSpacing.xs),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/icons/coin.webp', width: 22, height: 22),
          const SizedBox(width: AppSpacing.xxs),
          Text('${item.price} монет', style: AppTextStyles.cardRowLabel),
        ],
      ),
      const SizedBox(height: AppSpacing.xxs),
      Text('Нажми, чтобы узнать подробнее', style: AppTextStyles.stepCounter),
    ],
  );
}

String _stateLabel(ArtifactProductState state) => switch (state) {
  ArtifactProductState.available => 'можно выбрать целью',
  ArtifactProductState.selected => 'текущая цель',
  ArtifactProductState.locked => 'недоступен до получения текущей цели',
};
