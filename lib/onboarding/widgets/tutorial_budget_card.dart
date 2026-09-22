import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../onboarding_data.dart';

/// The "help Groshik split 10 coins" card on onboarding step 3 — a hands-on
/// stand-in for real budget planning (candy = WANT, other things = NEED,
/// piggy bank = SAVINGS; see onboarding_data.dart). Coins move between rows,
/// never appear or disappear: a row's "+" is disabled once every coin is
/// already assigned somewhere, and "-" is disabled once a row hits zero.
class TutorialBudgetCard extends StatelessWidget {
  const TutorialBudgetCard({super.key, required this.data, required this.onChanged});

  final OnboardingData data;
  final ValueChanged<OnboardingData> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Text('$kTutorialBudgetTotal монет', style: AppTextStyles.cardTitle)),
          const SizedBox(height: 16),
          _CounterRow(
            icon: Icons.icecream_outlined,
            label: 'Конфеты',
            value: data.candyAmount,
            canIncrement: data.unallocated > 0,
            canDecrement: data.candyAmount > 0,
            onIncrement: () => onChanged(data.copyWith(candyAmount: data.candyAmount + 1)),
            onDecrement: () => onChanged(data.copyWith(candyAmount: data.candyAmount - 1)),
          ),
          const SizedBox(height: 10),
          _CounterRow(
            icon: Icons.sports_baseball_outlined,
            label: 'Другие вещи',
            value: data.otherAmount,
            canIncrement: data.unallocated > 0,
            canDecrement: data.otherAmount > 0,
            onIncrement: () => onChanged(data.copyWith(otherAmount: data.otherAmount + 1)),
            onDecrement: () => onChanged(data.copyWith(otherAmount: data.otherAmount - 1)),
          ),
          const SizedBox(height: 10),
          _CounterRow(
            icon: Icons.savings_outlined,
            label: 'Копилка',
            value: data.piggyAmount,
            canIncrement: data.unallocated > 0,
            canDecrement: data.piggyAmount > 0,
            onIncrement: () => onChanged(data.copyWith(piggyAmount: data.piggyAmount + 1)),
            onDecrement: () => onChanged(data.copyWith(piggyAmount: data.piggyAmount - 1)),
          ),
        ],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.canIncrement,
    required this.canDecrement,
    required this.onIncrement,
    required this.onDecrement,
  });

  final IconData icon;
  final String label;
  final int value;
  final bool canIncrement;
  final bool canDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    // Two lines instead of one cramped row: the 48x48 accessible tap targets
    // plus icon + coin count leave a single-line layout with almost no room
    // for the label at narrow widths (e.g. 320px), which forced "Другие
    // вещи" to text-wrap across dozens of lines and blew the row's height
    // out by hundreds of pixels. Stacking guarantees each line always has
    // the row's full width to itself, at any screen width.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.ink, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(label, style: AppTextStyles.cardRowLabel)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _RoundIconButton(
                icon: Icons.remove,
                color: AppColors.crimson,
                onPressed: canDecrement ? onDecrement : null,
                semanticLabel: 'Убрать монету из категории «$label»',
              ),
              const SizedBox(width: 6),
              const Icon(Icons.monetization_on, color: AppColors.leafGreen, size: 20),
              const SizedBox(width: 6),
              SizedBox(
                width: 20,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.counterValue,
                  semanticsLabel: '$value монет в категории $label',
                ),
              ),
              const SizedBox(width: 6),
              _RoundIconButton(
                icon: Icons.add,
                color: AppColors.leafGreen,
                onPressed: canIncrement ? onIncrement : null,
                semanticLabel: 'Добавить монету в категорию «$label»',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String semanticLabel;

  // Visible circle stays small (28) to match the card's proportions; the
  // actual tappable area is padded out to Android's ~48dp minimum target.
  static const _visibleSize = 28.0;
  static const _tapTargetSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: SizedBox(
        width: _tapTargetSize,
        height: _tapTargetSize,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: ExcludeSemantics(
              child: Center(
                child: Container(
                  width: _visibleSize,
                  height: _visibleSize,
                  decoration: BoxDecoration(
                    color: enabled ? color : color.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
