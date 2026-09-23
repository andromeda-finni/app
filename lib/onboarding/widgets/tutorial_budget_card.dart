import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../onboarding_data.dart';

/// The interactive budget itself. Every category explains its purpose before
/// presenting the counter, and all values start at zero so the child performs
/// the allocation rather than merely approving a hard-coded answer.
class TutorialBudgetCard extends StatelessWidget {
  const TutorialBudgetCard({
    super.key,
    required this.data,
    required this.onChanged,
  });

  final OnboardingData data;
  final ValueChanged<OnboardingData> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        image: const DecorationImage(
          image: AssetImage('assets/backgrounds/paper.png'),
          fit: BoxFit.cover,
          opacity: 0.24,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Твои 10 монет',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            _BudgetCategory(
              icon: 'assets/icons/sweet.png',
              label: 'Конфеты',
              explanation: 'То, чего хочется прямо сейчас',
              value: data.candyAmount,
              canIncrement: data.unallocated > 0,
              canDecrement: data.candyAmount > 0,
              onIncrement: () =>
                  onChanged(data.copyWith(candyAmount: data.candyAmount + 1)),
              onDecrement: () =>
                  onChanged(data.copyWith(candyAmount: data.candyAmount - 1)),
            ),
            Divider(
              height: AppSpacing.xl,
              color: AppColors.fieldBorder.withValues(alpha: 0.55),
            ),
            _BudgetCategory(
              icon: 'assets/icons/ball.png',
              label: 'Нужные вещи',
              explanation: 'То, что пригодится питомцу',
              value: data.otherAmount,
              canIncrement: data.unallocated > 0,
              canDecrement: data.otherAmount > 0,
              onIncrement: () =>
                  onChanged(data.copyWith(otherAmount: data.otherAmount + 1)),
              onDecrement: () =>
                  onChanged(data.copyWith(otherAmount: data.otherAmount - 1)),
            ),
            Divider(
              height: AppSpacing.xl,
              color: AppColors.fieldBorder.withValues(alpha: 0.55),
            ),
            _BudgetCategory(
              icon: 'assets/icons/pig.png',
              label: 'Копилка',
              explanation: 'Монеты на будущую мечту',
              value: data.piggyAmount,
              canIncrement: data.unallocated > 0,
              canDecrement: data.piggyAmount > 0,
              onIncrement: () =>
                  onChanged(data.copyWith(piggyAmount: data.piggyAmount + 1)),
              onDecrement: () =>
                  onChanged(data.copyWith(piggyAmount: data.piggyAmount - 1)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCategory extends StatelessWidget {
  const _BudgetCategory({
    required this.icon,
    required this.label,
    required this.explanation,
    required this.value,
    required this.canIncrement,
    required this.canDecrement,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String icon;
  final String label;
  final String explanation;
  final int value;
  final bool canIncrement;
  final bool canDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label, $value монет. $explanation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Image.asset(icon, fit: BoxFit.contain),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.cardRowLabel),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(explanation, style: AppTextStyles.supporting),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CounterButton(
                icon: Icons.remove,
                onPressed: canDecrement ? onDecrement : null,
                semanticLabel: 'Убрать монету из категории «$label»',
                color: AppColors.crimson,
              ),
              const SizedBox(width: AppSpacing.lg),
              SizedBox(
                width: 84,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/icons/coin.png', width: 24, height: 24),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$value',
                      style: AppTextStyles.counterValue,
                      semanticsLabel: '$value монет',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              _CounterButton(
                icon: Icons.add,
                onPressed: canIncrement ? onIncrement : null,
                semanticLabel: 'Добавить монету в категорию «$label»',
                color: AppColors.leafGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    required this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: enabled ? color : AppColors.fieldBorder,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
