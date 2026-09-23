import 'package:flutter/material.dart';

/// Painted backdrop with the cat standing in it, used as the top half of each
/// onboarding step.
///
/// The art ships as a scene and a separate cut-out cat rather than one flat
/// picture, because step 1 has to swap the cat the moment a fur colour is
/// picked while the backdrop stays put.
class OnboardingScene extends StatelessWidget {
  const OnboardingScene({
    super.key,
    required this.background,
    this.cat,
    this.catAlignment = const Alignment(0, 0.72),
    this.catHeightFraction = 0.58,
    this.backgroundAlignment = const Alignment(0, 0.45),
  });

  final String background;
  final String? cat;
  final Alignment catAlignment;

  /// The backdrops are tall portraits shown in a short landscape band, so
  /// `cover` throws most of them away. Framing just below centre keeps the
  /// trees and rooftops in view with meadow left under the cat's feet —
  /// aligning to the bottom shows nothing but grass.
  final Alignment backgroundAlignment;

  /// Cat height as a share of the scene, so it keeps its footing in the
  /// composition when the scene is squeezed on a short screen.
  final double catHeightFraction;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            background,
            fit: BoxFit.cover,
            alignment: backgroundAlignment,
          ),
          if (cat != null)
            Align(
              alignment: catAlignment,
              child: FractionallySizedBox(
                heightFactor: catHeightFraction,
                child: Image.asset(cat!, fit: BoxFit.contain),
              ),
            ),
        ],
      ),
    );
  }
}
