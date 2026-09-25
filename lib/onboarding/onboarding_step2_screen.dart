import 'package:flutter/material.dart';

import 'onboarding_data.dart';
import 'widgets/drop_cap_story.dart';
import 'widgets/fur_color_picker.dart';
import 'widgets/onboarding_scene.dart';
import 'widgets/onboarding_step_scaffold.dart';

/// Onboarding step 2 of 4 — pure backstory, no input: Groshik lives near
/// the "Чудо-лавка" and loves candy, setting up the budgeting theme.
class OnboardingStep2Screen extends StatelessWidget {
  const OnboardingStep2Screen({
    super.key,
    required this.onBack,
    required this.onNext,
    this.data,
    this.isSubmitting = false,
  });

  final VoidCallback onBack;
  final VoidCallback? onNext;
  final bool isSubmitting;

  /// Carries the fur colour picked on step 1 so the story keeps showing the
  /// child's own cat rather than reverting to the generic one.
  final OnboardingData? data;

  @override
  Widget build(BuildContext context) {
    final savedName = data?.petName.trim();
    final petName = savedName == null || savedName.isEmpty
        ? 'котёнок'
        : savedName;
    return OnboardingStepScaffold(
      stepNumber: 2,
      top: OnboardingScene(
        background: 'assets/backgrounds/shop.png',
        foreground: 'assets/backgrounds/meadow_foreground.png',
        cat: catAssetForFur(data?.furColorId),
        catAlignment: const Alignment(-0.35, 0.85),
        catHeightFraction: 0.5,
      ),
      onBack: onBack,
      onNext: onNext,
      nextLoading: isSubmitting,
      nextLabel: 'Далее',
      content: DropCapStory(
        dropCap: 'О',
        firstLine: 'н жил рядом с Чудо-лавкой и очень любил конфеты.',
        rest:
            'Иногда $petName тратил все монеты сразу — и на нужные вещи уже ничего не оставалось.',
      ),
    );
  }
}
