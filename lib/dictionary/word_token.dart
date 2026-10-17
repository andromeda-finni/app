import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

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

class WaxSeal extends StatelessWidget {
  const WaxSeal({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: [Color(0xFFB34E51), AppColors.crimson, Color(0xFF5F1A26)],
      ),
      border: Border.all(color: const Color(0xFF74222D), width: 3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x402F130A),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Center(
      child: Container(
        width: size * 0.75,
        height: size * 0.75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCD7A71)),
        ),
        child: Icon(
          Icons.auto_stories_outlined,
          color: const Color(0xFFF4CBAB),
          size: size * 0.4,
        ),
      ),
    ),
  );
}
