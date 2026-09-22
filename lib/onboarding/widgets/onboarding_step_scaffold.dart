import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'back_circle_button.dart';
import 'onboarding_scroll_layout.dart';
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
    this.topSizeToFraction = true,
  });

  final int stepNumber;
  final Widget top;
  final Widget content;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool nextEnabled;
  final bool nextShowFlourish;

  /// False for a `top` with real content needs (e.g. step 3's interactive
  /// card) so it can size to its own content instead of being squeezed into
  /// a fixed fraction of the viewport — see OnboardingScrollLayout.
  final bool topSizeToFraction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: OnboardingScrollLayout(
        top: top,
        sizeTopToFraction: topSizeToFraction,
        bottom: Container(
          decoration: const BoxDecoration(
            color: AppColors.parchment,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  content,
                  const SizedBox(height: 24),
                  // Wrap, not Row: giving the progress section and the
                  // button equal flex shares (Expanded/Flexible) split the
                  // row 50/50 regardless of actual content width, which
                  // could starve a long label ("Начать игру" at a large
                  // text-scale factor) of the room its icons + padding
                  // need and overflow. Wrap lets every item take its
                  // natural width and only drops the button to its own
                  // line on the rare screen where all three truly don't
                  // fit on one — it can never overflow.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 12,
                    children: [
                      BackCircleButton(onPressed: onBack),
                      StepProgress(currentStep: stepNumber, totalSteps: kOnboardingTotalSteps),
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
      ),
    );
  }
}
