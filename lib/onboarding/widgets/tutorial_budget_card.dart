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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.ink, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.cardRowLabel)),
          _RoundIconButton(
            icon: Icons.remove,
            color: AppColors.crimson,
            onPressed: canDecrement ? onDecrement : null,
          ),
          const SizedBox(width: 10),
          const Icon(Icons.monetization_on, color: AppColors.leafGreen, size: 20),
          const SizedBox(width: 6),
          SizedBox(
            width: 18,
            child: Text('$value', textAlign: TextAlign.center, style: AppTextStyles.counterValue),
          ),
          const SizedBox(width: 10),
          _RoundIconButton(
            icon: Icons.add,
            color: AppColors.leafGreen,
            onPressed: canIncrement ? onIncrement : null,
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.color, required this.onPressed});

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? color : color.withValues(alpha: 0.3),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}
