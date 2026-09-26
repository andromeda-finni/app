import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Product art shared by the store and the current-goal card.
///
/// The backend may expose either `image_asset` or `imageAsset`. Until catalog
/// art is bundled, missing or invalid paths fall back to a stable symbol.
class ItemArtwork extends StatelessWidget {
  const ItemArtwork({
    super.key,
    this.imageAsset,
    this.size = 112,
    this.borderRadius = AppRadii.lg,
  });

  final String? imageAsset;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final path = imageAsset?.trim();
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
