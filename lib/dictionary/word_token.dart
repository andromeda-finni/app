import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export '../theme/wax_seal.dart';

/// A real inline TextSpan: identical font, weight, size and line metrics.
/// Only the ink tint and luminous shadows differ from the surrounding copy.
class FinancialStoryText extends StatefulWidget {
  const FinancialStoryText({
    super.key,
    required this.onExplain,
    required this.before,
    required this.term,
    required this.after,
    required this.wordId,
    required this.style,
  });
  final VoidCallback onExplain;
  final String before;
  final String term;
  final String after;
  final String wordId;
  final TextStyle style;

  @override
  State<FinancialStoryText> createState() => _FinancialStoryTextState();
}

class _FinancialStoryTextState extends State<FinancialStoryText>
    with SingleTickerProviderStateMixin {
  late final _doubleTap = DoubleTapGestureRecognizer()
    ..onDoubleTap = () => widget.onExplain();
  late final _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _glow.stop();
      _glow.value = 0.6;
    } else {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _doubleTap.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onExplain();
          return null;
        },
      ),
    },
    child: AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final strength = 0.65 + _glow.value * 0.35;
        return Text.rich(
          key: const Key('financial-story'),
          TextSpan(
            children: [
              TextSpan(text: widget.before),
              TextSpan(
                text: widget.term,
                semanticsIdentifier: '${widget.wordId}-term',
                semanticsLabel: '${widget.term}, узнать значение',
                recognizer: _doubleTap,
                mouseCursor: SystemMouseCursors.click,
                style: TextStyle(
                  color: const Color(0xFF76552C),
                  shadows: [
                    Shadow(
                      color: const Color(0xFFFFCE65)
                          .withValues(alpha: strength),
                      blurRadius: 2,
                    ),
                    Shadow(
                      color: const Color(0xFFF8BA42)
                          .withValues(alpha: strength),
                      blurRadius: 6,
                    ),
                    Shadow(
                      color: const Color(0xFFFFC85B)
                          .withValues(alpha: strength * 0.9),
                      blurRadius: 12,
                    ),
                    Shadow(
                      color: const Color(0xFFFFC85B)
                          .withValues(alpha: strength * 0.65),
                      blurRadius: 22,
                    ),
                  ],
                ),
              ),
              TextSpan(text: widget.after),
            ],
          ),
          style: widget.style,
        );
      },
    ),
  );
}
