import 'package:flutter/material.dart';

import '../../dictionary/dictionary_text.dart';
import '../../onboarding/widgets/story_button.dart';
import '../../theme/app_theme.dart';
import 'mole_truth_board.dart';
import 'mole_truth_controller.dart';
import 'mole_truth_models.dart';

class MoleTruthCaseView extends StatefulWidget {
  const MoleTruthCaseView({
    super.key,
    required this.document,
    required this.onSolved,
  });
  final MoleTruthCase document;
  final VoidCallback onSolved;

  @override
  State<MoleTruthCaseView> createState() => _MoleTruthCaseViewState();
}

class _MoleTruthCaseViewState extends State<MoleTruthCaseView> {
  late final _controller = MoleTruthController(widget.document);
  String? _feedback;
  bool _hintVisible = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm(String id) {
    final result = _controller.confirm(id);
    setState(() {
      _feedback = switch (result) {
        MoleTruthConfirmation.honest => 'Эта строка в порядке.',
        MoleTruthConfirmation.inspectFirst => 'Сначала наведи лупу.',
        MoleTruthConfirmation.found ||
        MoleTruthConfirmation.alreadyFound ||
        MoleTruthConfirmation.closed => null,
      };
    });
  }

  void _confront() {
    if (!_controller.confront()) return;
    setState(() => _feedback = null);
    widget.onSolved();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final document = widget.document;
      final found = _controller.exposedIds;
      final solved = _controller.resolved;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!solved) ...[
            Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.leafGreen,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Найди подмену. Нажми под лупой.',
                    style: AppTextStyles.supporting,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          MoleTruthBoard(
            document: document,
            exposedIds: found,
            onInspect: _controller.inspect,
            onConfirm: _confirm,
            enabled: !solved,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  'Найдено ${found.length}/${document.tricks.length}',
                  key: const Key('mole-truth-progress'),
                  style: AppTextStyles.stepCounter,
                ),
              ),
              if (!solved)
                TextButton.icon(
                  key: const Key('mole-truth-hint'),
                  onPressed: () => setState(() => _hintVisible = !_hintVisible),
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
                  label: const Text('Подсказка'),
                ),
            ],
          ),
          if (_hintVisible && !solved)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DictionaryText(
                document.hint,
                style: AppTextStyles.supporting,
              ),
            ),
          if (_feedback != null)
            Semantics(
              liveRegion: true,
              child: Text(_feedback!, style: AppTextStyles.supporting),
            ),
          if (!solved)
            Semantics(
              container: true,
              child: StoryButton(
                key: const Key('mole-truth-confront'),
                label: document.verdictLabel,
                onPressed: _controller.canConfront ? _confront : null,
              ),
            )
          else
            Container(
              key: const Key('mole-truth-verdict'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.protectionTint,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.leafGreen.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: AppColors.leafGreen,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  DictionaryText(switch (document.documentKind) {
                    MoleTruthDocumentKind.receipt => 'Чек исправлен!',
                    MoleTruthDocumentKind.advertisement =>
                      'Условие акции найдено!',
                    MoleTruthDocumentKind.contract => 'Подмена найдена!',
                    MoleTruthDocumentKind.productLabel => 'Подмена в составе!',
                  }, style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 12),
                  if (document.documentKind == MoleTruthDocumentKind.receipt)
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(
                          moleCoinAmount(document.billedTotal),
                          style: AppTextStyles.supporting.copyWith(
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.leafGreen,
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: document.billedTotal.toDouble(),
                            end: document.fairTotal.toDouble(),
                          ),
                          duration: MediaQuery.of(context).disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 550),
                          builder: (context, value, child) => Text(
                            moleCoinAmount(value.round()),
                            key: const Key('mole-truth-fair-total'),
                            style: AppTextStyles.screenTitle.copyWith(
                              color: AppColors.leafGreen,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    DictionaryText(
                      switch (document.documentKind) {
                        MoleTruthDocumentKind.advertisement =>
                          'Одна нужная вещь — ${moleCoinAmount(document.fairTotal)}.',
                        MoleTruthDocumentKind.productLabel =>
                          'Это сироп, а не мёд. Выберем другой товар.',
                        _ => 'Земелик не подписывает неподходящие условия.',
                      },
                      textAlign: TextAlign.center,
                      style: AppTextStyles.story,
                    ),
                ],
              ),
            ),
          if (found.isNotEmpty)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const Key('mole-truth-explanation'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Почему это ошибка?',
                  style: AppTextStyles.supporting,
                ),
                children: [
                  for (final span in document.tricks.where(
                    (span) => found.contains(span.id),
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: DictionaryText(
                          span.explanation!,
                          style: AppTextStyles.supporting,
                        ),
                      ),
                    ),
                  if (solved)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DictionaryText(
                        '«${document.sellerReply}»',
                        style: AppTextStyles.supporting,
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
