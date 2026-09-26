import 'package:flutter/material.dart';

import '../../economy/economy_state.dart';
import '../../economy/item_artwork.dart';
import '../../theme/app_theme.dart';

enum ArtifactProductState { available, selected, locked }

/// Reusable artifact card for the store and future product-catalog surfaces.
class ArtifactProductCard extends StatelessWidget {
  const ArtifactProductCard({
    super.key,
    required this.item,
    required this.state,
    this.onSelect,
  });

  final EconomyItem item;
  final ArtifactProductState state;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = state == ArtifactProductState.selected;
    return Semantics(
      key: ValueKey('artifact-card-${item.id}'),
      container: true,
      label:
          '${item.name}, ${item.price} монет, ${_rarityLabel(item.rarity)}, ${_stateLabel(state)}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? const [Color(0xFFF1F6E9), Color(0xFFE4EED8)]
                : const [Color(0xFFFFFBF3), Color(0xFFFFF0D5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: selected ? AppColors.leafGreen : const Color(0xFFE8C98E),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ItemArtwork(
                itemId: item.id,
                imageAsset: item.imageAsset,
                semanticLabel: item.name,
                size: 154,
                borderRadius: AppRadii.lg,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _RarityBadge(rarity: item.rarity)),
                const SizedBox(width: 8),
                _Price(price: item.price),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.name, style: AppTextStyles.cardTitle),
            const SizedBox(height: 14),
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
      icon: const Icon(Icons.flag_outlined),
      label: const Text('Выбрать целью'),
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
      ),
      child: Text(
        'Доступно после текущей цели',
        textAlign: TextAlign.center,
        style: AppTextStyles.supporting,
      ),
    ),
  };
}

class _Price extends StatelessWidget {
  const _Price({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset('assets/icons/coin.png', width: 24, height: 24),
      const SizedBox(width: 5),
      Text('$price', style: AppTextStyles.cardRowLabel),
    ],
  );
}

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({required this.rarity});

  final String? rarity;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (rarity) {
      'LEGENDARY' => (const Color(0xFF9C5D16), Icons.auto_awesome),
      'EPIC' => (AppColors.crimson, Icons.diamond_outlined),
      _ => (AppColors.leafGreen, Icons.star_outline),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            _rarityLabel(rarity),
            style: AppTextStyles.swatchLabel.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

String _rarityLabel(String? rarity) => switch (rarity) {
  'LEGENDARY' => 'Легендарный',
  'EPIC' => 'Эпический',
  _ => 'Редкий',
};

String _stateLabel(ArtifactProductState state) => switch (state) {
  ArtifactProductState.available => 'можно выбрать целью',
  ArtifactProductState.selected => 'текущая цель',
  ArtifactProductState.locked => 'недоступен до получения текущей цели',
};
