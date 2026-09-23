import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'back_circle_button.dart';
import 'onboarding_paper_background.dart';
import 'step_progress.dart';
import 'story_button.dart';

const kOnboardingTotalSteps = 4;

/// Shared layout for onboarding steps 2-4: a top area (illustration, or on
/// step 3 the interactive budget card) above a parchment card with the
/// step's content and a consistent progress/action footer.
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
    this.nextShowFlourish = true,
    this.nextLoading = false,
    this.topMinFraction = 0.54,
  });

  final int stepNumber;
  final Widget top;
  final Widget content;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool nextEnabled;
  final bool nextShowFlourish;
  final bool nextLoading;

  /// Raised on step 3, where `top` is the interactive budget scroll rather
  /// than decoration and so needs to keep most of the screen.
  final double topMinFraction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: OnboardingPaperBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topHeight = (constraints.maxHeight * topMinFraction).clamp(
              250.0,
              520.0,
            );
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: topHeight, child: top),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            AppSpacing.xl,
                          ),
                          child: content,
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: OnboardingFooter(
                      stepNumber: stepNumber,
                      onBack: onBack,
                      onNext: nextEnabled ? onNext : null,
                      nextLabel: nextLabel,
                      nextShowFlourish: nextShowFlourish,
                      nextLoading: nextLoading,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({
    super.key,
    required this.stepNumber,
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
    this.nextShowFlourish = false,
    this.nextLoading = false,
  });

  final int stepNumber;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool nextShowFlourish;
  final bool nextLoading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useSingleRow = constraints.maxWidth >= 340 && textScale <= 1.2;
        final progress = StepProgress(
          currentStep: stepNumber,
          totalSteps: kOnboardingTotalSteps,
        );
        final back = BackCircleButton(onPressed: onBack);
        final next = StoryButton(
          label: nextLabel,
          showFlourish: nextShowFlourish,
          isLoading: nextLoading,
          onPressed: onNext,
        );

        if (useSingleRow) {
          final buttonWidth = math.min(220.0, constraints.maxWidth * 0.56);
          return Row(
            children: [
              back,
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: progress),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(width: buttonWidth, child: next),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            progress,
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                back,
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: next),
              ],
            ),
          ],
        );
      },
    );
  }
}
