import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'onboarding_data.dart';
import 'widgets/drop_cap_ornament.dart';
import 'widgets/onboarding_step_scaffold.dart';
import 'widgets/tutorial_budget_card.dart';

/// Onboarding step 3 of 4 — the one interactive tutorial: split 10 coins
/// between candy (WANT), other things (NEED) and the piggy bank (SAVINGS).
/// A hands-on stand-in for the real budget_plans mechanic (see
/// db/migrations/0007_periods.sql) using kid-friendly labels instead of
/// budgeting jargon.
class OnboardingStep3Screen extends StatefulWidget {
  const OnboardingStep3Screen({
    super.key,
    required this.initialData,
    required this.onBack,
    required this.onNext,
  });

  final OnboardingData initialData;
  final VoidCallback onBack;
  final ValueChanged<OnboardingData> onNext;

  @override
  State<OnboardingStep3Screen> createState() => _OnboardingStep3ScreenState();
}

class _OnboardingStep3ScreenState extends State<OnboardingStep3Screen> {
  late OnboardingData _data = widget.initialData;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      stepNumber: 3,
      top: Container(
        color: AppColors.cardBg,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: TutorialBudgetCard(
            data: _data,
            onChanged: (next) => setState(() => _data = next),
          ),
        ),
      ),
      onBack: widget.onBack,
      onNext: () => widget.onNext(_data),
      nextLabel: 'Готово',
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('П', style: AppTextStyles.dropCap),
          const SizedBox(width: 4),
          const DropCapOrnament(),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'омоги Грошику распределить $kTutorialBudgetTotal монет.',
              style: AppTextStyles.story,
            ),
          ),
        ],
      ),
    );
  }
}
