import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'onboarding_data.dart';
import 'widgets/drop_cap_story.dart';
import 'widgets/onboarding_paper_background.dart';
import 'widgets/onboarding_step_scaffold.dart';
import 'widgets/tutorial_budget_card.dart';

/// Onboarding step 3 of 4 — an explicit, guided first budget. It starts with
/// all ten coins unallocated, explains each destination, and gives immediate
/// feedback about how many coins remain. There is intentionally no single
/// prescribed split: the learning goal is making a conscious choice.
class OnboardingStep3Screen extends StatefulWidget {
  const OnboardingStep3Screen({
    super.key,
    required this.initialData,
    required this.onBack,
    required this.onNext,
    this.isSubmitting = false,
  });

  final OnboardingData initialData;
  final ValueChanged<OnboardingData> onBack;
  final ValueChanged<OnboardingData>? onNext;
  final bool isSubmitting;

  @override
  State<OnboardingStep3Screen> createState() => _OnboardingStep3ScreenState();
}

class _OnboardingStep3ScreenState extends State<OnboardingStep3Screen> {
  late OnboardingData _data = widget.initialData;

  bool get _canFinish =>
      _data.budgetPracticed && _data.unallocated == 0 && !widget.isSubmitting;

  void _updateBudget(OnboardingData next) {
    setState(() => _data = next.copyWith(budgetPracticed: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: OnboardingPaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TutorialHeading(petName: _data.petName),
                      const SizedBox(height: AppSpacing.lg),
                      _BudgetProgress(data: _data),
                      const SizedBox(height: AppSpacing.md),
                      TutorialBudgetCard(data: _data, onChanged: _updateBudget),
                      const SizedBox(height: AppSpacing.sm),
                      _BudgetHint(data: _data),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: OnboardingFooter(
                  stepNumber: 3,
                  onBack: () => widget.onBack(_data),
                  onNext: _canFinish && widget.onNext != null
                      ? () => widget.onNext!(_data)
                      : null,
                  nextLabel: 'Готово',
                  nextShowFlourish: true,
                  nextLoading: widget.isSubmitting,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialHeading extends StatelessWidget {
  const _TutorialHeading({required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    final savedName = petName.trim();
    final displayName = savedName.isEmpty ? 'Питомец' : savedName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoryDropCap(letter: 'П', size: 70),
            Expanded(
              child: Text(
                'омоги распределить 10 монет',
                style: AppTextStyles.screenTitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$displayName получил 10 монет. '
          'Нажимай +, чтобы разложить их по трём корзинам. '
          'Здесь нет одного правильного ответа — важен твой выбор.',
          style: AppTextStyles.supporting,
        ),
      ],
    );
  }
}

class _BudgetProgress extends StatelessWidget {
  const _BudgetProgress({required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    final complete = data.unallocated == 0;
    final message = complete
        ? 'Все 10 монет распределены'
        : 'Осталось распределить: ${data.unallocated}';
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: complete ? const Color(0xFFEAF1E4) : AppColors.infoBg,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  complete ? Icons.check_circle : Icons.toll_outlined,
                  size: 22,
                  color: complete ? AppColors.leafGreen : AppColors.coinGold,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(message, style: AppTextStyles.sectionTitle),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: data.allocated / kTutorialBudgetTotal,
                minHeight: 8,
                backgroundColor: AppColors.cardBg,
                valueColor: const AlwaysStoppedAnimation(AppColors.crimson),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetHint extends StatelessWidget {
  const _BudgetHint({required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (!data.budgetPracticed) {
      text = 'Начни с любой корзины: нажми зелёный плюс.';
    } else if (data.unallocated > 0) {
      text =
          'Хорошо! Разложи ещё ${data.unallocated} ${_coinWord(data.unallocated)}.';
    } else {
      text = 'Готово! Проверь свой выбор. Его можно изменить кнопками − и +.';
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.supporting.copyWith(
        color: data.unallocated == 0 ? AppColors.leafGreen : AppColors.inkMuted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

String _coinWord(int value) {
  final lastTwo = value % 100;
  if (lastTwo >= 11 && lastTwo <= 14) return 'монет';
  return switch (value % 10) {
    1 => 'монету',
    2 || 3 || 4 => 'монеты',
    _ => 'монет',
  };
}
