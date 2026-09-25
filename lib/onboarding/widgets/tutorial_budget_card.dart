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
    return LayoutBuilder(
      builder: (context, constraints) {
        final parchmentInset = (constraints.maxWidth * 0.125).clamp(34.0, 52.0);
        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              top: -28,
              left: -12,
              right: -12,
              bottom: 0,
              child: Image(
                image: AssetImage('assets/backgrounds/paper.png'),
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxWidth * 1.42,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  parchmentInset,
                  AppSpacing.xxl + AppSpacing.lg,
                  parchmentInset,
                  96,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Твои 10 монет',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Разложи их по трём целям',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.supporting.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      child: _BudgetCategory(
                        icon: 'assets/icons/sweet.png',
                        label: 'Конфеты',
                        explanation: 'Хочется сейчас',
                        value: data.candyAmount,
                        canIncrement: data.unallocated > 0,
                        canDecrement: data.candyAmount > 0,
                        onIncrement: () => onChanged(
                          data.copyWith(candyAmount: data.candyAmount + 1),
                        ),
                        onDecrement: () => onChanged(
                          data.copyWith(candyAmount: data.candyAmount - 1),
                        ),
                      ),
                    ),
                    Divider(
                      height: AppSpacing.xl,
                      indent: AppSpacing.md,
                      color: AppColors.fieldBorder.withValues(alpha: 0.55),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      child: _BudgetCategory(
                        icon: 'assets/icons/ball.png',
                        label: 'Нужные вещи',
                        explanation: 'Пригодятся питомцу',
                        value: data.otherAmount,
                        canIncrement: data.unallocated > 0,
                        canDecrement: data.otherAmount > 0,
                        onIncrement: () => onChanged(
                          data.copyWith(otherAmount: data.otherAmount + 1),
                        ),
                        onDecrement: () => onChanged(
                          data.copyWith(otherAmount: data.otherAmount - 1),
                        ),
                      ),
                    ),
                    Divider(
                      height: AppSpacing.xl,
                      indent: AppSpacing.md,
                      color: AppColors.fieldBorder.withValues(alpha: 0.55),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      child: _BudgetCategory(
                        icon: 'assets/icons/pig.png',
                        label: 'Копилка',
                        explanation: 'На будущую мечту',
                        value: data.piggyAmount,
                        canIncrement: data.unallocated > 0,
                        canDecrement: data.piggyAmount > 0,
                        onIncrement: () => onChanged(
                          data.copyWith(piggyAmount: data.piggyAmount + 1),
                        ),
                        onDecrement: () => onChanged(
                          data.copyWith(piggyAmount: data.piggyAmount - 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final useStackedLayout =
              constraints.maxWidth < 230 || textScale > 1.4;
          final iconSize = useStackedLayout ? 52.0 : 58.0;
          final heading = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: iconSize,
                height: iconSize,
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
          );
          final controls = _CounterControls(
            label: label,
            value: value,
            canIncrement: canIncrement,
            canDecrement: canDecrement,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
          );

          if (useStackedLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: AppSpacing.sm),
                controls,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: Image.asset(icon, fit: BoxFit.contain),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(label, style: AppTextStyles.cardRowLabel),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(explanation, style: AppTextStyles.supporting),
                    const SizedBox(height: AppSpacing.sm),
                    controls,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CounterControls extends StatelessWidget {
  const _CounterControls({
    required this.label,
    required this.value,
    required this.canIncrement,
    required this.canDecrement,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String label;
  final int value;
  final bool canIncrement;
  final bool canDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CounterButton(
          icon: Icons.remove,
          onPressed: canDecrement ? onDecrement : null,
          semanticLabel: 'Убрать монету из категории «$label»',
          color: AppColors.crimson,
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/coin.png',
                width: 30,
                height: 30,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$value',
                style: AppTextStyles.counterValue,
                semanticsLabel: '$value монет',
              ),
            ],
          ),
        ),
        _CounterButton(
          icon: Icons.add,
          onPressed: canIncrement ? onIncrement : null,
          semanticLabel: 'Добавить монету в категорию «$label»',
          color: AppColors.leafGreen,
        ),
      ],
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
          child: Center(
            child: SizedBox(
              width: 44,
              height: 44,
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
        ),
      ),
    );
  }
}
