import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/home_economy_state.dart';

class CoinDistributionSheet extends StatefulWidget {
  const CoinDistributionSheet({
    super.key,
    required this.spendable,
    required this.savings,
    required this.protectedReserve,
    required this.goal,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onRedeem,
  });

  final int spendable;
  final int savings;
  final int protectedReserve;
  final ActiveGoal? goal;
  final Future<void> Function(int amount) onDeposit;
  final Future<void> Function(int amount) onWithdraw;
  final Future<void> Function()? onRedeem;

  @override
  State<CoinDistributionSheet> createState() => _CoinDistributionSheetState();
}

class _CoinDistributionSheetState extends State<CoinDistributionSheet> {
  bool _depositMode = true;
  int _amount = 1;
  bool _busy = false;
  String? _error;

  int get _availableToSave =>
      math.max(0, widget.spendable - widget.protectedReserve);

  int get _limit => _depositMode ? _availableToSave : widget.savings;

  void _changeMode(bool deposit) {
    setState(() {
      _depositMode = deposit;
      _amount = _limit == 0 ? 0 : 1;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || _amount < 1 || _amount > _limit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_depositMode) {
        await widget.onDeposit(_amount);
      } else {
        await widget.onWithdraw(_amount);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не получилось перевести монеты. Попробуй ещё раз.';
      });
    }
  }

  Future<void> _redeem() async {
    final callback = widget.onRedeem;
    if (_busy || callback == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await callback();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не получилось получить артефакт. Попробуй ещё раз.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          22,
          20,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Распределить заработанные монеты',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenTitle,
                ),
                const SizedBox(height: 8),
                Text(
                  'В кошельке ${widget.spendable} · в копилке ${widget.savings}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.supporting,
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.savings_rounded),
                      label: Text('В копилку'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.account_balance_wallet_rounded),
                      label: Text('В кошелёк'),
                    ),
                  ],
                  selected: {_depositMode},
                  onSelectionChanged: _busy
                      ? null
                      : (value) => _changeMode(value.first),
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Colors.white
                          : AppColors.crimson,
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.crimson
                          : AppColors.cardBg,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _depositMode
                            ? 'Можно отложить: $_availableToSave'
                            : 'Можно снять: ${widget.savings}',
                        style: AppTextStyles.cardRowLabel,
                      ),
                      if (_depositMode && widget.protectedReserve > 0) ...[
                        const SizedBox(height: 5),
                        Text(
                          '${widget.protectedReserve} монет защищены для еды питомца.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.swatchLabel,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _AmountButton(
                            semanticLabel: 'Уменьшить сумму',
                            icon: Icons.remove_rounded,
                            onPressed: !_busy && _amount > 1
                                ? () => setState(() => _amount--)
                                : null,
                          ),
                          SizedBox(
                            width: 96,
                            child: Text(
                              '$_amount',
                              key: const Key('distribution-amount'),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.counterValue.copyWith(
                                fontSize: 32,
                              ),
                            ),
                          ),
                          _AmountButton(
                            semanticLabel: 'Увеличить сумму',
                            icon: Icons.add_rounded,
                            onPressed: !_busy && _amount < _limit
                                ? () => setState(() => _amount++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.swatchLabel.copyWith(
                      color: AppColors.crimson,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const Key('confirm-coin-distribution'),
                    onPressed: _limit > 0 && !_busy ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.crimson,
                      disabledBackgroundColor: AppColors.crimsonFaded,
                    ),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _depositMode
                                ? 'Переложить в копилку'
                                : 'Вернуть в кошелёк',
                            style: AppTextStyles.button,
                          ),
                  ),
                ),
                if (goal != null) ...[
                  const SizedBox(height: 18),
                  Divider(color: AppColors.fieldBorder),
                  const SizedBox(height: 10),
                  Text(
                    'Моя мечта · ${goal.name}',
                    style: AppTextStyles.cardTitle,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${goal.savedAmount} из ${goal.targetAmount} монет',
                    style: AppTextStyles.supporting,
                  ),
                  if (goal.canRedeem) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const Key('redeem-goal'),
                        onPressed: !_busy && widget.onRedeem != null
                            ? _redeem
                            : null,
                        icon: const Icon(Icons.card_giftcard_rounded),
                        label: const Text('Получить артефакт'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.crimson,
                          side: const BorderSide(color: AppColors.crimson),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountButton extends StatelessWidget {
  const _AmountButton({
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: 48,
        child: IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon),
          color: AppColors.crimson,
        ),
      ),
    );
  }
}
