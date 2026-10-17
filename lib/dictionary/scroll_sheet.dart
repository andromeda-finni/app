import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'dictionary_audio.dart';
import 'dictionary_catalog.dart';
import 'dictionary_progress.dart';
import 'infinite_paper.dart';
import 'word_token.dart';

Future<void> showDictionaryScroll(
  BuildContext context, {
  required DictionaryProgress progress,
  DictionaryAudio audio = const GameDictionaryAudio(),
  MediaQueryData? media,
}) async {
  unawaited(audio.openScroll());
  unawaited(HapticFeedback.lightImpact());
  final presentation = media ?? MediaQuery.of(context);
  final reduced = presentation.disableAnimations;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть словарик',
    barrierColor: const Color(0x99302B22),
    transitionDuration: Duration(milliseconds: reduced ? 0 : 500),
    pageBuilder: (context, _, _) => MediaQuery(
      data: presentation,
      child: _NotebookScroll(progress: progress),
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.5),
      ),
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => ClipRect(
          child: Align(
            heightFactor:
                0.08 + Curves.easeOutCubic.transform(animation.value) * 0.92,
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _NotebookScroll extends StatefulWidget {
  const _NotebookScroll({required this.progress});
  final DictionaryProgress progress;
  @override
  State<_NotebookScroll> createState() => _NotebookScrollState();
}

class _NotebookScrollState extends State<_NotebookScroll> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  DictionaryFilter _filter = DictionaryFilter.all;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    if (!widget.progress.loaded) unawaited(widget.progress.load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _changeFilter(DictionaryFilter filter) {
    setState(() {
      _filter = filter;
      _expandedId = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _changeSearch(String _) {
    setState(() => _expandedId = null);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toggleWord(DictionaryWord word) {
    final opening = _expandedId != word.id;
    setState(() => _expandedId = opening ? word.id : null);
    if (opening) unawaited(_rememberWord(word.id));
  }

  Future<void> _rememberWord(String id) async {
    if (!widget.progress.loaded) await widget.progress.load();
    await widget.progress.remember(id);
  }

  Widget _animateExpansion(BuildContext context, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Material(
        color: Colors.transparent,
        child: InfinitePaper(
          controller: _scroll,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: widget.progress,
              builder: (context, _) {
                final readIds = widget.progress.words;
                final count = readIds.length;
                final total = dictionaryCatalog.length;
                final filteringIds = {...readIds};
                // Reading a row in the unread filter must not make its
                // explanation disappear halfway through reading it.
                if (_filter == DictionaryFilter.unread) {
                  filteringIds.remove(_expandedId);
                }
                final words = selectDictionaryWords(
                  readIds: filteringIds,
                  query: _search.text,
                  filter: _filter,
                );
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(34, 18, 26, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const WaxSeal(size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Словарик',
                                  style: AppTextStyles.eventTitle.copyWith(
                                    fontSize: 32,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: const Key('close-scroll'),
                                tooltip: 'Закрыть словарик',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.close,
                                  size: 22,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              widget.progress.loaded
                                  ? 'Прочитано $count из $total · ещё ${total - count}'
                                  : widget.progress.error == null
                                  ? 'Загружаем заметки…'
                                  : 'Отметки чтения пока недоступны',
                              key: const Key('dictionary-count'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                          if (!widget.progress.loaded &&
                              widget.progress.error != null)
                            TextButton(
                              onPressed: widget.progress.load,
                              child: const Text('Повторить загрузку'),
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('dictionary-search'),
                            controller: _search,
                            onChanged: _changeSearch,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Найти слово',
                              prefixIcon: const Icon(Icons.search, size: 21),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Очистить поиск',
                                      onPressed: () {
                                        _search.clear();
                                        _changeSearch('');
                                      },
                                      icon: const Icon(Icons.close, size: 19),
                                    ),
                              filled: true,
                              fillColor: const Color(0x55FFFCF5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.fieldBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.fieldBorder,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            children: [
                              for (final entry in const {
                                DictionaryFilter.all: 'Все слова',
                                DictionaryFilter.read: 'Читали',
                                DictionaryFilter.unread: 'Впереди',
                              }.entries)
                                TextButton(
                                  key: Key('filter-${entry.key.name}'),
                                  onPressed:
                                      entry.key != DictionaryFilter.all &&
                                          !widget.progress.loaded
                                      ? null
                                      : () => _changeFilter(entry.key),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _filter == entry.key
                                        ? AppColors.crimson
                                        : AppColors.inkMuted,
                                    textStyle: TextStyle(
                                      fontFamily: AppFonts.body,
                                      fontSize: 14,
                                      fontWeight: _filter == entry.key
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(entry.value),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _scroll,
                        thumbVisibility: true,
                        child: CustomScrollView(
                          key: const Key('dictionary-list'),
                          controller: _scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            if (words.isEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  44,
                                  24,
                                  38,
                                  24,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Text(
                                    _search.text.isNotEmpty
                                        ? _filter == DictionaryFilter.all
                                              ? 'По этому запросу ничего не нашлось. Попробуй другое название.'
                                              : 'В этом списке совпадений нет. Попробуй «Все слова».'
                                        : _filter == DictionaryFilter.read
                                        ? 'Когда прочитаешь объяснение, оно появится здесь.'
                                        : 'Все объяснения уже прочитаны.',
                                    style: AppTextStyles.supporting,
                                  ),
                                ),
                              ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(38, 0, 36, 64),
                              sliver: SliverList.builder(
                                itemCount: words.length,
                                itemBuilder: (context, index) {
                                  final word = words[index];
                                  final letter = word.title.substring(0, 1);
                                  final showLetter =
                                      index == 0 ||
                                      words[index - 1].title.substring(0, 1) !=
                                          letter;
                                  final expanded = _expandedId == word.id;
                                  return Column(
                                    key: Key('entry-${word.id}'),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (showLetter)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 18,
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            letter,
                                            style: AppTextStyles.eventTitle
                                                .copyWith(fontSize: 28),
                                          ),
                                        ),
                                      InkWell(
                                        onTap: () => _toggleWord(word),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Semantics(
                                          expanded: expanded,
                                          button: true,
                                          label:
                                              '${word.title}, ${readIds.contains(word.id) ? 'прочитано' : 'ещё не читали'}',
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 14,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        word.title,
                                                        style: AppTextStyles
                                                            .sectionTitle
                                                            .copyWith(
                                                              fontSize: 21,
                                                              color: expanded
                                                                  ? AppColors
                                                                        .crimsonDark
                                                                  : readIds
                                                                        .contains(
                                                                          word.id,
                                                                        )
                                                                  ? AppColors
                                                                        .ink
                                                                  : AppColors
                                                                        .inkMuted,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        word.category,
                                                        style: AppTextStyles
                                                            .supporting
                                                            .copyWith(
                                                              fontSize: 12,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  expanded
                                                      ? Icons.expand_less
                                                      : Icons.expand_more,
                                                  size: 20,
                                                  color: AppColors.inkMuted,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      _animateExpansion(
                                        context,
                                        expanded
                                            ? Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      6,
                                                      0,
                                                      6,
                                                      18,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Text(
                                                      word.definition,
                                                      key: Key(
                                                        'definition-${word.id}',
                                                      ),
                                                      style:
                                                          AppTextStyles.story,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      word.example,
                                                      style: AppTextStyles
                                                          .supporting
                                                          .copyWith(
                                                            fontSize: 16,
                                                          ),
                                                    ),
                                                    if (widget.progress.error !=
                                                            null &&
                                                        !readIds.contains(
                                                          word.id,
                                                        )) ...[
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      Text(
                                                        widget.progress.error!,
                                                        style: AppTextStyles
                                                            .supporting,
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            _rememberWord(
                                                              word.id,
                                                            ),
                                                        child: const Text(
                                                          'Сохранить ещё раз',
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                      const Divider(
                                        height: 1,
                                        color: AppColors.fieldBorder,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
