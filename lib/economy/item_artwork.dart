import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'item_art_catalog.dart';

/// Product art shared by the store and the current-goal card.
///
/// The backend may expose either `image_asset` or `imageAsset`. Until catalog
/// art is bundled, missing or invalid paths fall back to a stable symbol.
class ItemArtwork extends StatelessWidget {
  const ItemArtwork({
    super.key,
    this.itemId,
    this.imageAsset,
    this.semanticLabel,
    this.size = 112,
    this.borderRadius = AppRadii.lg,
  });

  final String? itemId;
  final String? imageAsset;
  final String? semanticLabel;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final path = resolveItemArtwork(itemId: itemId, imageAsset: imageAsset);
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: ColoredBox(
          color: const Color(0xFFFFF1D2),
          child: path == null || path.isEmpty
              ? _fallback()
              : Image.asset(
                  path,
                  fit: BoxFit.contain,
                  semanticLabel: semanticLabel,
                  errorBuilder: (_, _, _) => _fallback(),
                ),
        ),
      ),
    );
  }

  Widget _fallback() => const Center(
    child: Icon(Icons.auto_awesome, size: 42, color: AppColors.coinGold),
  );
}
