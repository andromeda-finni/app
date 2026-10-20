import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'dictionary_reader.dart';
import 'dictionary_scope.dart';
import 'dictionary_terms.dart';

/// Use for authored learning copy, outside purchase/answer button tap targets.
/// Without a profile scope it renders ordinary Text, including in game demos.
class DictionaryText extends StatefulWidget {
  const DictionaryText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.excludedWordIds = const {},
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Skip a homonym when the authored copy uses its non-financial meaning.
  final Set<String> excludedWordIds;

  @override
  State<DictionaryText> createState() => _DictionaryTextState();
}

class _CycleTermIntent extends Intent {
  const _CycleTermIntent(this.direction);
  final int direction;
}

class _DictionaryTextState extends State<DictionaryText>
    with SingleTickerProviderStateMixin {
  late final _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  List<DictionaryTermMatch> _matches = [];
  final _recognizers = <DoubleTapGestureRecognizer>[];
  DictionaryScope? _scope;
  bool _opening = false;
  bool _showFocus = false;
  int _focusedTerm = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = DictionaryScope.maybeOf(context);
    _updateTerms();
  }

  @override
  void didUpdateWidget(DictionaryText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data ||
        !setEquals(widget.excludedWordIds, oldWidget.excludedWordIds)) {
      _updateTerms();
    }
  }

  void _updateTerms() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    _matches = _scope?.progress == null
        ? []
        : matchDictionaryTerms(widget.data)
              .where((match) => !widget.excludedWordIds.contains(match.word.id))
              .toList();
    _focusedTerm = 0;
    for (final match in _matches) {
      _recognizers.add(
        DoubleTapGestureRecognizer()..onDoubleTap = () => _explain(match),
      );
    }
    if (_matches.isEmpty || MediaQuery.disableAnimationsOf(context)) {
      _glow.stop();
      _glow.value = 0.6;
    } else {
      // Introduce the glow once, then leave it steady while the child reads.
      // Static copy must not schedule frames indefinitely across retained tabs.
      _glow.forward(from: 0).then((_) {
        if (mounted) _glow.reverse();
      });
    }
  }

  Future<void> _explain(DictionaryTermMatch match) async {
    final progress = _scope?.progress;
    if (_opening || progress == null) return;
    _opening = true;
    try {
      await explainDictionaryWord(
        context,
        progress: progress,
        word: match.word,
        media: _scope?.media,
      );
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_matches.isEmpty) {
      return Text(
        widget.data,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }
    return FocusableActionDetector(
      onShowFocusHighlight: (show) => setState(() => _showFocus = show),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _CycleTermIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _CycleTermIntent(-1),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _explain(_matches[_focusedTerm]);
            return null;
          },
        ),
        _CycleTermIntent: CallbackAction<_CycleTermIntent>(
          onInvoke: (intent) {
            setState(() {
              _focusedTerm =
                  (_focusedTerm + intent.direction) % _matches.length;
            });
            return null;
          },
        ),
      },
      child: Semantics(
        hint:
            'Дважды нажми на слово, чтобы узнать значение. '
            'С клавиатуры: стрелки выбирают слово, Enter открывает значение.',
        customSemanticsActions: {
          for (final match in _matches)
            CustomSemanticsAction(
              label: 'Объяснить «${match.word.title}»',
            ): () =>
                _explain(match),
        },
        child: AnimatedBuilder(
          animation: _glow,
          builder: (context, _) {
            final strength = 0.65 + _glow.value * 0.35;
            final spans = <InlineSpan>[];
            var end = 0;
            for (var i = 0; i < _matches.length; i++) {
              final match = _matches[i];
              spans.add(
                TextSpan(text: widget.data.substring(end, match.start)),
              );
              spans.add(
                TextSpan(
                  text: widget.data.substring(match.start, match.end),
                  semanticsIdentifier: '${match.word.id}-term',
                  semanticsLabel:
                      '${widget.data.substring(match.start, match.end)}, узнать значение',
                  recognizer: _recognizers[i],
                  mouseCursor: SystemMouseCursors.click,
                  style: TextStyle(
                    color: const Color(0xFF76552C),
                    decoration: _showFocus && i == _focusedTerm
                        ? TextDecoration.underline
                        : null,
                    shadows: [
                      for (final blur in [2.0, 6.0, 12.0, 22.0])
                        Shadow(
                          color: const Color(0xFFFFCE65)
                              .withValues(alpha: strength),
                          blurRadius: blur,
                        ),
                    ],
                  ),
                ),
              );
              end = match.end;
            }
            spans.add(TextSpan(text: widget.data.substring(end)));
            return Text.rich(
              TextSpan(children: spans),
              style: widget.style,
              textAlign: widget.textAlign,
              maxLines: widget.maxLines,
              overflow: widget.overflow,
            );
          },
        ),
      ),
    );
  }
}
