import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A category entrance drawn over one complete illustrated shop plaque.
///
/// The product vignette is baked into [plaqueAsset], so its perspective,
/// lighting and contact shadows remain coherent. Text and the direction cue
/// stay native for accessibility, localization and a reliable tap target.
class ShopCategoryCard extends StatelessWidget {
  const ShopCategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    required this.plaqueAsset,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String semanticLabel;
  final String plaqueAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final naturalHeight = constraints.maxWidth / (1600 / 592);
        final scaledMinimum = 158.0 + (textScale - 1).clamp(0, 1) * 184;
        final height = math.max(naturalHeight, scaledMinimum);
        final horizontalInset = math.max(46.0, constraints.maxWidth * 0.14);
        final textTrailingInset = textScale > 1.5
            ? math.max(76.0, constraints.maxWidth * 0.22)
            : constraints.maxWidth * 0.48;

        return Semantics(
          button: true,
          label: semanticLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: SizedBox(
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ExcludeSemantics(
                        child: Image.asset(
                          plaqueAsset,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    Positioned(
                      left: horizontalInset,
                      right: textTrailingInset,
                      top: height * (textScale > 1.5 ? 0.06 : 0.1),
                      bottom: height * (textScale > 1.5 ? 0.12 : 0.24),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: textScale > 1.5 ? 6 : 0,
                          vertical: 2,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.screenTitle.copyWith(
                                fontSize: 26,
                                color: const Color(0xFF4A210B),
                                height: 1.05,
                                shadows: const [
                                  Shadow(
                                    color: Color(0xCCFFF1D2),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              subtitle,
                              maxLines: textScale > 1.5 ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.supporting.copyWith(
                                color: const Color(0xFF4A210B),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.18,
                                shadows: const [
                                  Shadow(
                                    color: Color(0xE8FFF1D2),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: math.max(28, constraints.maxWidth * 0.07),
                      top: (height - 48) / 2,
                      child: const _DirectionCue(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DirectionCue extends StatelessWidget {
  const _DirectionCue();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 48,
    height: 48,
    child: Center(
      child: Icon(
        Icons.chevron_right_rounded,
        size: 36,
        color: Color(0xFF5B260A),
      ),
    ),
  );
}
