import 'package:flutter/material.dart';
import 'widgets/drop_cap_story.dart';
import 'widgets/onboarding_illustration.dart';
import 'widgets/onboarding_step_scaffold.dart';

/// Onboarding step 2 of 4 — pure backstory, no input: Groshik lives near
/// the "Чудо-лавка" and loves candy, setting up the budgeting theme.
class OnboardingStep2Screen extends StatelessWidget {
  const OnboardingStep2Screen({super.key, required this.onBack, required this.onNext});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      stepNumber: 2,
      top: const OnboardingIllustration(stepNumber: 2),
      onBack: onBack,
      onNext: onNext,
      nextLabel: 'Далее',
      content: const DropCapStory(
        dropCap: 'О',
        firstLine: 'н жил в избушке неподалёку',
        rest: 'от Чудо-лавки, где часто скупал все конфеты, что там были. '
            'Грошик любил конфеты. Немного монеток он тратил на другие вещи.',
      ),
    );
  }
}
