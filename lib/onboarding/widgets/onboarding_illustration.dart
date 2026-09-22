import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Placeholder for the painted storybook illustration at the top of each
/// onboarding step. No art asset exists yet — swap this widget's body for
/// `Image.asset('assets/images/onboarding/step$stepNumber.png', fit: BoxFit.cover)`
/// once the real illustration files are dropped into
/// assets/images/onboarding/ (already wired up in pubspec.yaml).
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key, required this.stepNumber});

  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.skyTop, AppColors.skyBottom],
        ),
      ),
      child: const Center(
        child: Icon(Icons.pets, size: 96, color: Colors.white70),
      ),
    );
  }
}
