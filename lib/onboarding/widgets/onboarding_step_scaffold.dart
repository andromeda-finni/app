import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'back_circle_button.dart';
import 'step_progress.dart';
import 'story_button.dart';

const kOnboardingTotalSteps = 4;

/// Shared layout for onboarding steps 2-4: a top area (illustration, or on
/// step 3 the interactive budget card) above a parchment card with the
/// step's content, and a bottom row of
/// [back button] — [progress dots] — [next/done button]. Step 1 has its own
/// screen (no back button, full-width button) since its bottom layout
/// differs from the rest.
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.stepNumber,
    required this.top,
    required this.content,
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
    this.nextEnabled = true,
    this.nextShowFlourish = false,
  });

  final int stepNumber;
  final Widget top;
  final Widget content;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool nextEnabled;
  final bool nextShowFlourish;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Column(
        children: [
          Expanded(child: top),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.parchment,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    content,
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        BackCircleButton(onPressed: onBack),
                        Expanded(
                          child: Center(
                            child: StepProgress(
                              currentStep: stepNumber,
                              totalSteps: kOnboardingTotalSteps,
                            ),
                          ),
                        ),
                        StoryButton(
                          label: nextLabel,
                          expand: false,
                          showFlourish: nextShowFlourish,
                          onPressed: nextEnabled ? onNext : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
