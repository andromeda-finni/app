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
                      Transform.translate(
                        offset: const Offset(0, -AppSpacing.xs),
                        child: TutorialBudgetCard(
                          data: _data,
                          onChanged: _updateBudget,
                        ),
                      ),
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
            StoryDropCap(letter: 'П', size: 64, widthFactor: 0.92),
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
          'Попробуй составить план: на радость сейчас, на нужное '
          'и на будущую мечту. '
          'Решение остаётся за тобой.',
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
    final guidance = _budgetGuidanceFor(data);
    final message = complete
        ? 'Все 10 монет распределены'
        : 'Осталось распределить: ${data.unallocated}';
    return Semantics(
      liveRegion: true,
      label: '$message. ${guidance.text}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: switch (guidance.tone) {
            _BudgetGuidanceTone.success => const Color(0xFFEAF1E4),
            _BudgetGuidanceTone.caution => AppColors.infoBg,
            _BudgetGuidanceTone.neutral => AppColors.canvasWarm,
          },
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (complete)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 30,
                    color: AppColors.leafGreen,
                  )
                else
                  Image.asset(
                    'assets/icons/coin.png',
                    width: 30,
                    height: 30,
                    excludeFromSemantics: true,
                  ),
                const SizedBox(width: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (guidance.tone) {
                    _BudgetGuidanceTone.success =>
                      Icons.check_circle_outline_rounded,
                    _BudgetGuidanceTone.caution =>
                      Icons.lightbulb_outline_rounded,
                    _BudgetGuidanceTone.neutral => Icons.explore_outlined,
                  },
                  size: 22,
                  color: switch (guidance.tone) {
                    _BudgetGuidanceTone.success => AppColors.leafGreen,
                    _BudgetGuidanceTone.caution => AppColors.crimsonDark,
                    _BudgetGuidanceTone.neutral => AppColors.inkMuted,
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    guidance.text,
                    style: AppTextStyles.supporting.copyWith(
                      color: guidance.tone == _BudgetGuidanceTone.success
                          ? AppColors.leafGreen
                          : AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _BudgetGuidanceTone { neutral, caution, success }

class _BudgetGuidance {
  const _BudgetGuidance(this.text, this.tone);

  final String text;
  final _BudgetGuidanceTone tone;
}

_BudgetGuidance _budgetGuidanceFor(OnboardingData data) {
  if (data.allocated == 0) {
    return const _BudgetGuidance(
      'Сначала подумай: что нужно сейчас, а что стоит сохранить на мечту?',
      _BudgetGuidanceTone.neutral,
    );
  }

  if (data.unallocated > 0) {
    if (data.candyAmount >= 8) {
      return const _BudgetGuidance(
        'Почти все монеты уходят на конфеты. Что останется на нужное '
        'и на мечту?',
        _BudgetGuidanceTone.caution,
      );
    }
    if (data.otherAmount >= 8) {
      return const _BudgetGuidance(
        'Почти все монеты уходят на нужное. Хочешь оставить немного '
        'на радость или мечту?',
        _BudgetGuidanceTone.caution,
      );
    }
    if (data.piggyAmount >= 8) {
      return const _BudgetGuidance(
        'Почти всё отправилось в копилку. Это бережно — но, может быть, '
        'что-то нужно сегодня?',
        _BudgetGuidanceTone.caution,
      );
    }
    return _BudgetGuidance(
      'Осталось ${data.unallocated} ${_coinWord(data.unallocated)}. '
      'Проверь, учёл ли ты нужное и будущую мечту.',
      _BudgetGuidanceTone.neutral,
    );
  }

  if (data.candyAmount == kTutorialBudgetTotal ||
      data.otherAmount == kTutorialBudgetTotal ||
      data.piggyAmount == kTutorialBudgetTotal) {
    return const _BudgetGuidance(
      'Все монеты в одной корзине. Так можно, но для других целей ничего '
      'не осталось. Проверь свой выбор.',
      _BudgetGuidanceTone.caution,
    );
  }
  if (data.piggyAmount == 0) {
    return const _BudgetGuidance(
      'Копилка пуста — на мечту ничего не осталось. Можно продолжить или '
      'отложить хотя бы одну монету.',
      _BudgetGuidanceTone.caution,
    );
  }
  if (data.otherAmount == 0) {
    return const _BudgetGuidance(
      'На нужные вещи ничего не осталось. Можно продолжить или пересмотреть '
      'план.',
      _BudgetGuidanceTone.caution,
    );
  }
  if (data.candyAmount == 0) {
    return const _BudgetGuidance(
      'Разумный план: нужное и мечта учтены. Без конфет сейчас — тоже твой '
      'выбор.',
      _BudgetGuidanceTone.success,
    );
  }
  return const _BudgetGuidance(
    'Отличный план: ты учёл радость сейчас, нужное и будущую мечту.',
    _BudgetGuidanceTone.success,
  );
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
