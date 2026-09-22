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
  // The default split (4/2/4) is already valid, so without this the child
  // could tap "Готово" without ever touching a +/- control — this tracks
  // whether they actually practiced moving a coin at least once.
  bool _hasInteracted = false;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      stepNumber: 3,
      // The card's content decides its own height instead of being
      // squeezed into a fraction of the viewport (see OnboardingScrollLayout
      // — a fixed fraction can be smaller than what this card's rows
      // actually need on a short device, which used to overflow).
      topSizeToFraction: false,
      top: Container(
        color: AppColors.cardBg,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: TutorialBudgetCard(
            data: _data,
            onChanged: (next) => setState(() {
              _data = next;
              _hasInteracted = true;
            }),
          ),
        ),
      ),
      onBack: widget.onBack,
      onNext: () => widget.onNext(_data),
      nextEnabled: _hasInteracted,
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
