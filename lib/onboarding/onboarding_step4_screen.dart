import 'package:flutter/material.dart';
import 'widgets/drop_cap_story.dart';
import 'widgets/onboarding_illustration.dart';
import 'widgets/onboarding_step_scaffold.dart';

/// Onboarding step 4 of 4 — closing scene introducing the town's other
/// fairy-tale characters, then "Начать игру" finishes onboarding.
class OnboardingStep4Screen extends StatelessWidget {
  const OnboardingStep4Screen({super.key, required this.onBack, required this.onFinish});

  final VoidCallback onBack;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      stepNumber: 4,
      top: const OnboardingIllustration(stepNumber: 4),
      onBack: onBack,
      onNext: onFinish,
      nextLabel: 'Начать игру',
      nextShowFlourish: true,
      content: const DropCapStory(
        dropCap: 'В',
        firstLine: 'этом городе жило множество',
        rest: 'других сказочных персонажей, к которым Грошик часто захаживал в гости.',
      ),
    );
  }
}
