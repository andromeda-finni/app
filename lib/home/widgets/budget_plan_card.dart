import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/active_period.dart';

/// The period's spending plan: split the grant between must-haves, wants and
/// savings, then approve it.
///
/// Approving is the moment the savings share actually leaves SPENDABLE (the
/// backend moves it inside the confirm transaction), which is why the card
/// keeps saying so and why it locks to a read-only summary afterwards — an
/// approved plan is a commitment, not a draft the child can keep nudging.
class BudgetPlanCard extends StatefulWidget {
  const BudgetPlanCard({
    super.key,
    required this.period,
    required this.onConfirm,
    required this.onStartPeriod,
  });

  final ActivePeriod? period;

  /// Sends the split and approves it. Throws to surface a failure inline.
  final Future<void> Function(int need, int want, int savings) onConfirm;
  final Future<void> Function() onStartPeriod;

  @override
  State<BudgetPlanCard> createState() => _BudgetPlanCardState();
}

class _BudgetPlanCardState extends State<BudgetPlanCard> {
  late int _need;
  late int _want;
  late int _savings;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resetFromPeriod();
  }

  @override
  void didUpdateWidget(BudgetPlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period?.budgetPlanId != widget.period?.budgetPlanId) {
      _resetFromPeriod();
    }
  }

  void _resetFromPeriod() {
    final period = widget.period;
    _need = period?.needAmount ?? 0;
    _want = period?.wantAmount ?? 0;
    _savings = period?.savingsAmount ?? 0;
  }

  int get _allocated => _need + _want + _savings;

  int get _unallocated => (widget.period?.availableAmount ?? 0) - _allocated;

  /// Mirrors the server's two rules so the child is told before the round
  /// trip, not after a 400.
  String? get _validationMessage {
    final period = widget.period;
    if (period == null) return null;
    if (_unallocated != 0) {
      return _unallocated > 0
          ? 'Осталось разложить $_unallocated монет.'
          : 'Разложено на ${-_unallocated} монет больше, чем есть.';
    }
    if (_need < period.requiredNeedAmount) {
      return 'На нужное надо отложить хотя бы ${period.requiredNeedAmount} монет.';
    }
    return null;
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm(_need, _want, _savings);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Не получилось утвердить план. Попробуйте ещё раз.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onStartPeriod();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Не получилось начать период. Попробуйте ещё раз.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    return _CardShell(
      title: 'План на период',
      icon: Icons.assignment_outlined,
      child: period == null
          ? _NoPeriod(busy: _busy, onStart: _start, error: _error)
          : period.isConfirmed
          ? _ConfirmedSummary(period: period)
          : _Editor(
              period: period,
              need: _need,
              want: _want,
              savings: _savings,
              unallocated: _unallocated,
              validationMessage: _validationMessage,
              error: _error,
              busy: _busy,
              onChanged: (need, want, savings) => setState(() {
                _need = need;
                _want = want;
                _savings = savings;
              }),
              onConfirm: _confirm,
            ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.crimson, size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _NoPeriod extends StatelessWidget {
  const _NoPeriod({required this.busy, required this.onStart, this.error});

  final bool busy;
  final VoidCallback onStart;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Новый период — это новые монетки и новый план, как их потратить.',
          style: AppTextStyles.swatchLabel,
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: AppTextStyles.swatchLabel.copyWith(color: AppColors.crimson),
          ),
        ],
        const SizedBox(height: 14),
        _PrimaryButton(
          label: 'Начать период',
          busy: busy,
          onPressed: busy ? null : onStart,
        ),
      ],
    );
  }
}

class _ConfirmedSummary extends StatelessWidget {
  const _ConfirmedSummary({required this.period});

  final ActivePeriod period;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.leafGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('План утверждён', style: AppTextStyles.cardRowLabel),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryRow(label: 'Обязательное', amount: period.needAmount),
        _SummaryRow(label: 'Необязательное', amount: period.wantAmount),
        _SummaryRow(label: 'В копилку', amount: period.savingsAmount),
        const SizedBox(height: 8),
        Text(
          'Монетки для копилки уже отложены.',
          style: AppTextStyles.swatchLabel,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.cardRowLabel)),
          Image.asset('assets/icons/coin.png', width: 20, height: 20),
          const SizedBox(width: 6),
          Text('$amount', style: AppTextStyles.counterValue),
        ],
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.period,
    required this.need,
    required this.want,
    required this.savings,
    required this.unallocated,
    required this.validationMessage,
    required this.error,
    required this.busy,
    required this.onChanged,
    required this.onConfirm,
  });

  final ActivePeriod period;
  final int need;
  final int want;
  final int savings;
  final int unallocated;
  final String? validationMessage;
  final String? error;
  final bool busy;
  final void Function(int need, int want, int savings) onChanged;
  final VoidCallback onConfirm;

  /// Coins move between rows and are never created, so "+" stops once the
  /// grant is fully allocated — the same rule the tutorial taught in
  /// onboarding step 3.
  bool get _canAdd => unallocated > 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Разложи ${period.availableAmount} монет',
                style: AppTextStyles.cardRowLabel,
              ),
            ),
            Text(
              unallocated == 0 ? 'всё разложено' : 'осталось $unallocated',
              style: AppTextStyles.swatchLabel,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _AmountRow(
          label: 'Обязательное',
          hint: 'еда и лечение — минимум ${period.requiredNeedAmount}',
          value: need,
          canAdd: _canAdd,
          onChanged: (value) => onChanged(value, want, savings),
        ),
        _AmountRow(
          label: 'Необязательное',
          hint: 'игрушки и сладости',
          value: want,
          canAdd: _canAdd,
          onChanged: (value) => onChanged(need, value, savings),
        ),
        _AmountRow(
          label: 'В копилку',
          hint: 'отложить на потом',
          value: savings,
          canAdd: _canAdd,
          onChanged: (value) => onChanged(need, want, value),
        ),
        if (validationMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            validationMessage!,
            style: AppTextStyles.swatchLabel.copyWith(color: AppColors.crimson),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: AppTextStyles.swatchLabel.copyWith(color: AppColors.crimson),
          ),
        ],
        const SizedBox(height: 14),
        _PrimaryButton(
          label: 'Утвердить план',
          busy: busy,
          onPressed: validationMessage == null && !busy ? onConfirm : null,
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.canAdd,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final int value;
  final bool canAdd;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.cardRowLabel),
                Text(hint, style: AppTextStyles.swatchLabel),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove,
            color: AppColors.crimson,
            semanticLabel: 'Убрать монету: $label',
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 38,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTextStyles.counterValue,
            ),
          ),
          _StepButton(
            icon: Icons.add,
            color: AppColors.leafGreen,
            semanticLabel: 'Добавить монету: $label',
            onPressed: canAdd ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.color,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String semanticLabel;
  final VoidCallback? onPressed;

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
          width: 44,
          height: 44,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: enabled ? color : color.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.crimson,
          disabledBackgroundColor: AppColors.crimson.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          elevation: onPressed != null ? 2 : 0,
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label, style: AppTextStyles.button),
      ),
    );
  }
}
