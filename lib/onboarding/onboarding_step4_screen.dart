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
    this.isSubmitting = false,
  });

  final VoidCallback onBack;
  final VoidCallback? onFinish;
  final OnboardingData? data;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final savedName = data?.petName.trim();
    final petName = savedName == null || savedName.isEmpty
        ? 'котёнок'
        : savedName;
    return OnboardingStepScaffold(
      stepNumber: 4,
      top: OnboardingScene(
        background: 'assets/backgrounds/town.png',
        foreground: 'assets/backgrounds/meadow_foreground.png',
        cat: catAssetForFur(data?.furColorId, happy: true),
        catAlignment: const Alignment(0.1, 0.9),
        catHeightFraction: 0.46,
      ),
      onBack: onBack,
      onNext: onFinish,
      nextLoading: isSubmitting,
      nextLabel: 'Начать игру',
      nextShowFlourish: true,
      content: DropCapStory(
        dropCap: 'Т',
        firstLine: 'еперь $petName знает: монеты можно распределять заранее.',
        rest: 'Часть — на желания, часть — на нужные вещи, а часть — на большую мечту. В городе его ждут новые истории!',
      ),
    );
  }
}
