import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dictionary_catalog.dart';
import 'dictionary_progress.dart';

Future<bool?> showWordExplanation(
  BuildContext context, {
  required DictionaryProgress notebook,
  required DictionaryWord word,
  MediaQueryData? media,
}) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => MediaQuery(
    data: media ?? MediaQuery.of(context),
    child: Dialog(
      backgroundColor: AppColors.cardBg,
      constraints: const BoxConstraints(maxWidth: 440),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: _Explanation(notebook: notebook, word: word),
    ),
  ),
);

class _Explanation extends StatefulWidget {
  const _Explanation({required this.notebook, required this.word});
  final DictionaryProgress notebook;
  final DictionaryWord word;
  @override
  State<_Explanation> createState() => _ExplanationState();
}

class _ExplanationState extends State<_Explanation> {
  bool _added = false;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_remember());
    });
  }

  Future<void> _remember() async {
    if (!widget.notebook.loaded) await widget.notebook.load();
    final added = await widget.notebook.remember(widget.word.id);
    if (!mounted || !added) return;
    setState(() => _added = true);
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _added = false);
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.word.title,
                  style: AppTextStyles.screenTitle,
                ),
              ),
              IconButton(
                key: const Key('close-explanation'),
                tooltip: 'Вернуться к истории',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close,
                  size: 21,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.word.definition,
            key: const Key('word-definition'),
            style: AppTextStyles.story,
          ),
          const SizedBox(height: 16),
          Text(
            widget.word.example,
            style: AppTextStyles.supporting.copyWith(fontSize: 16),
          ),
          if (_added) ...[
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: const Text(
                'Слово добавлено в словарик',
                key: Key('word-added-notice'),
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
            ),
          ],
          ListenableBuilder(
            listenable: widget.notebook,
            builder: (context, _) => widget.notebook.error == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.notebook.error!,
                          style: AppTextStyles.supporting,
                        ),
                        TextButton(
                          onPressed: widget.notebook.busy ? null : _remember,
                          child: const Text('Сохранить ещё раз'),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('explanation-open-dictionary'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Открыть словарик'),
            ),
          ),
        ],
      ),
    ),
  );
}
