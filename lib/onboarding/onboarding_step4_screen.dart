import 'package:flutter/material.dart';

import 'onboarding_data.dart';
import 'widgets/drop_cap_story.dart';
import 'widgets/fur_color_picker.dart';
import 'widgets/onboarding_scene.dart';
import 'widgets/onboarding_step_scaffold.dart';

/// Onboarding step 4 of 4 — closing scene introducing the town's other
/// fairy-tale characters, then "Начать игру" finishes onboarding.
class OnboardingStep4Screen extends StatelessWidget {
  const OnboardingStep4Screen({
    super.key,
    required this.onBack,
    required this.onFinish,
    this.data,
  });

  final VoidCallback onBack;
  final VoidCallback onFinish;
  final OnboardingData? data;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      stepNumber: 4,
      top: OnboardingScene(
        background: 'assets/backgrounds/town.png',
        cat: catAssetForFur(data?.furColorId),
        catAlignment: const Alignment(0.1, 0.9),
        catHeightFraction: 0.46,
      ),
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
