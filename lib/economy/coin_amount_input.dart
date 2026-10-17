import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Makes a "+"/"−" coin button repeat while it is held, so a child does not
/// have to tap thirty times. A quick tap still changes the amount by one.
///
/// Repeats start slowly and speed up the longer the button is held. The
/// current [onStep] is re-read on every tick: once the parent disables the
/// button at a limit (passes null), repeating stops by itself.
class HoldToRepeat extends StatefulWidget {
  const HoldToRepeat({super.key, required this.onStep, required this.child});

  final VoidCallback? onStep;
  final Widget child;

  @override
  State<HoldToRepeat> createState() => _HoldToRepeatState();
}

class _HoldToRepeatState extends State<HoldToRepeat> {
  static const _holdDelay = Duration(milliseconds: 350);

  Timer? _timer;
  int _ticks = 0;

  /// ~3 steps per second at first, ~8 after a moment, ~16 when held long.
  static Duration _intervalFor(int ticks) => ticks < 5
      ? const Duration(milliseconds: 300)
      : ticks < 15
      ? const Duration(milliseconds: 120)
      : const Duration(milliseconds: 60);

  void _start() {
    _ticks = 0;
    _tick();
  }

  void _tick() {
    final step = widget.onStep;
    if (!mounted || step == null) {
      _stop();
      return;
    }
    step();
    _ticks++;
    _timer = Timer(_intervalFor(_ticks), _tick);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didUpdateWidget(covariant HoldToRepeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onStep == null) _stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: _holdDelay),
              (recognizer) {
                recognizer
                  ..onLongPressStart = (_) {
                    _start();
                  }
                  ..onLongPressEnd = (_) {
                    _stop();
                  }
                  ..onLongPressCancel = _stop;
              },
            ),
      },
      child: widget.child,
    );
  }
}

/// Lets the child type the amount instead of stepping to it. Returns null
/// when the dialog is dismissed. The result is always within [min]..[max].
Future<int?> showCoinAmountDialog(
  BuildContext context, {
  required String title,
  required int initial,
  required int min,
  required int max,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) =>
        _CoinAmountDialog(title: title, initial: initial, min: min, max: max),
  );
}

class _CoinAmountDialog extends StatefulWidget {
  const _CoinAmountDialog({
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
  });

  final String title;
  final int initial;
  final int min;
  final int max;

  @override
  State<_CoinAmountDialog> createState() => _CoinAmountDialogState();
}

class _CoinAmountDialogState extends State<_CoinAmountDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.initial}')
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: '${widget.initial}'.length,
        );

  int? get _value => int.tryParse(_controller.text);

  String? get _problem {
    final value = _value;
    if (value == null) return 'Введи число';
    if (value > widget.max) return 'Можно не больше ${widget.max}';
    if (value < widget.min) return 'Нужно не меньше ${widget.min}';
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_problem == null) Navigator.of(context).pop(_value);
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      title: Text(widget.title, style: AppTextStyles.cardTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'От ${widget.min} до ${widget.max} монет',
            style: AppTextStyles.supporting,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('coin-amount-field'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: AppTextStyles.counterValue.copyWith(fontSize: 32),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              errorText: _controller.text.isEmpty ? null : problem,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('coin-amount-done'),
          onPressed: problem == null ? _submit : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.crimson),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}

/// The tappable number between "−" and "+": looks like the plain counter it
/// replaces, with a dotted underline hinting that it can be typed in.
class TappableCoinAmount extends StatelessWidget {
  const TappableCoinAmount({
    super.key,
    required this.value,
    required this.style,
    required this.semanticLabel,
    required this.onTap,
  });

  final int value;
  final TextStyle style;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      value: '$value',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: style.copyWith(
                decoration: onTap == null ? null : TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: AppColors.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
