import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A tiny leaf+berry sprig next to the drop cap, approximating the painted
/// floral ornament in the reference designs without a real art asset —
/// built from Material icons, not a hand-drawn illustration.
class DropCapOrnament extends StatelessWidget {
  const DropCapOrnament({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 2,
            child: Icon(Icons.eco, size: 18, color: AppColors.leafGreen),
          ),
          Positioned(
            top: 16,
            left: 6,
            child: Icon(Icons.circle, size: 6, color: AppColors.crimson),
          ),
          Positioned(
            top: 24,
            left: 0,
            child: Icon(Icons.circle, size: 6, color: AppColors.crimson),
          ),
          Positioned(
            top: 24,
            left: 12,
            child: Icon(Icons.circle, size: 6, color: AppColors.crimson),
          ),
        ],
      ),
    );
  }
}
