import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A restrained paper texture shared by onboarding pages. The source asset is
/// intentionally kept very faint here: it should connect the illustrated and
/// functional areas without competing with text or controls.
class OnboardingPaperBackground extends StatelessWidget {
  const OnboardingPaperBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        image: DecorationImage(
          image: AssetImage('assets/backgrounds/paper.png'),
          fit: BoxFit.cover,
          opacity: 0.045,
        ),
      ),
      child: child,
    );
  }
}
