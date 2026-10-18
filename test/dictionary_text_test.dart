import 'package:andromeda_app/dictionary/dictionary_progress.dart';
import 'package:andromeda_app/dictionary/dictionary_scope.dart';
import 'package:andromeda_app/dictionary/dictionary_text.dart';
import 'package:andromeda_app/events/fox/fox_event_content.dart';
import 'package:andromeda_app/events/fox/fox_event_dialog.dart';
import 'package:andromeda_app/events/fox/fox_event_models.dart';
import 'package:andromeda_app/events/fox/fox_event_wallet.dart';
import 'package:andromeda_app/games/goldfish/goldfish_game_screen.dart';
import 'package:andromeda_app/games/goldfish/goldfish_game_models.dart';
import 'package:andromeda_app/games/squirrel/squirrel_game_models.dart';
import 'package:andromeda_app/games/squirrel/squirrel_game_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dictionary_progress_test.dart' show MemoryStorage;

Finder _copy(String text) => find.byWidgetPredicate(
  (widget) => widget is DictionaryText && widget.data == text,
);

Future<void> _explain(WidgetTester tester, Finder copy, String term) async {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: copy, matching: find.byType(RichText)).first,
  );
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final start = text.indexOf(term);
  expect(start, greaterThanOrEqualTo(0));
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + term.length),
      )
      .first;
  final point = paragraph.localToGlobal(box.toRect().center);
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tapAt(point);
  await tester.pumpAndSettle();
}

Widget _app(
  Widget child, {
  DictionaryProgress? progress,
  double scale = 1,
  bool reducedMotion = true,
}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reducedMotion,
      textScaler: TextScaler.linear(scale),
    ),
    child: child!,
  ),
  home: DictionaryScope(progress: progress, child: child),
);

void main() {
  testWidgets(
    'Fox explains a term without changing its conversation or wallet',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final progress = DictionaryProgress(storage: MemoryStorage());
      final wallet = InMemoryFoxEventWallet();
      addTearDown(progress.dispose);
      addTearDown(wallet.dispose);
      final script = foxScriptById('fox_younger_introduction');
      final session = FoxEventSession(
        scriptId: script.id,
        currentNodeId: script.initialNodeId,
      );
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFoxEventDialog(
                  context,
                  launch: FoxEventLaunch(
                    session: session,
                    isReturnVisit: false,
                  ),
                  wallet: wallet,
                  mode: FoxRuntimeMode.normal,
                  currentGameDay: 1,
                  petName: 'Мурзик',
                ),
                child: const Text('Открыть разговор'),
              ),
            ),
          ),
          progress: progress,
        ),
      );
      await tester.tap(find.text('Открыть разговор'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Поговорить'));
      await tester.pumpAndSettle();
      final copy = _copy(script.node('start').text);
      expect(
        DictionaryScope.maybeOf(tester.element(copy))?.progress,
        same(progress),
      );
      await tester.ensureVisible(copy);
      await _explain(tester, copy, 'монет');
      expect(find.byKey(const Key('word-definition')), findsOneWidget);
      expect(progress.words, {'coin'});
      expect(session.currentNodeId, 'start');
      expect(session.choiceHistory, isEmpty);
      expect(wallet.balance, 100);
      await tester.tap(find.byKey(const Key('close-explanation')));
      await tester.pumpAndSettle();
      expect(copy, findsOneWidget);
      final choice = find.text('А зачем тебе деньги?');
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(session.currentNodeId, 'purpose');
      expect(wallet.balance, 100);
      await tester.tap(find.byTooltip('Закрыть событие'));
      await tester.pumpAndSettle();
      expect(find.byType(FoxEventDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Squirrel food supplies do not open the money reserve entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('PTSerif')
      ..addFont(rootBundle.load('assets/fonts/PTSerif-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PTSerif-Bold.ttf'));
    await font.load();
    final progress = DictionaryProgress(storage: MemoryStorage());
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      _app(
        const SquirrelGameScreen(difficulty: SquirrelDifficulty.normal),
        progress: progress,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Нажми, чтобы продолжить'));
    await tester.pumpAndSettle();
    final copy = tester
        .widgetList<DictionaryText>(find.byType(DictionaryText))
        .firstWhere((copy) => copy.data.contains('зимних запасов'));
    final richText = tester.widget<Text>(
      find.descendant(of: _copy(copy.data), matching: find.byType(Text)).first,
    );
    final spans = (richText.textSpan as TextSpan).children!
        .whereType<TextSpan>();
    expect(
      spans.where((span) => span.semanticsIdentifier == 'reserve-term'),
      isEmpty,
    );
    expect(
      spans.where((span) => span.semanticsIdentifier == 'coin-term'),
      hasLength(1),
    );
    await _explain(tester, _copy(copy.data), 'монеток');
    expect(progress.words, {'coin'});
  });

  testWidgets('glow settles while terms remain available for reading', (
    tester,
  ) async {
    final progress = DictionaryProgress(storage: MemoryStorage());
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      _app(
        const Scaffold(body: DictionaryText('Выручка и прибыль')),
        progress: progress,
        reducedMotion: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await _explain(tester, _copy('Выручка и прибыль'), 'прибыль');
    expect(progress.words, {'profit'});
  });

  testWidgets('all terms open their own definition without a parent tap', (
    tester,
  ) async {
    final progress = DictionaryProgress(storage: MemoryStorage());
    addTearDown(progress.dispose);
    var advances = 0;
    const text = 'Бюджет: полная стоимость покупки со скидкой.';
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: GestureDetector(
            onTap: () => advances++,
            child: const DictionaryText(text, style: TextStyle(fontSize: 20)),
          ),
        ),
        progress: progress,
      ),
    );
    for (final entry in {
      'полная стоимость': 'total_cost',
      'скидкой': 'discount',
    }.entries) {
      await _explain(tester, _copy(text), entry.key);
      expect(find.byKey(const Key('word-definition')), findsOneWidget);
      expect(progress.words, contains(entry.value));
      expect(advances, 0);
      await tester.tap(find.byKey(const Key('close-explanation')));
      await tester.pumpAndSettle();
      expect(_copy(text), findsOneWidget);
    }
    expect(progress.words, {'total_cost', 'discount'});
  });

  testWidgets('keyboard selects the second term and opens its explanation', (
    tester,
  ) async {
    final progress = DictionaryProgress(storage: MemoryStorage());
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      _app(
        const Scaffold(body: DictionaryText('Доход и прибыль')),
        progress: progress,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(progress.words, {'profit'});
    expect(find.byKey(const Key('word-definition')), findsOneWidget);
  });

  testWidgets('a new story page replaces its term recognizers', (tester) async {
    final progress = DictionaryProgress(storage: MemoryStorage());
    addTearDown(progress.dispose);
    final page = ValueNotifier('Кредит');
    addTearDown(page.dispose);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ValueListenableBuilder(
            valueListenable: page,
            builder: (context, text, _) => DictionaryText(text),
          ),
        ),
        progress: progress,
      ),
    );
    page.value = 'Аренда';
    await tester.pump();
    await _explain(tester, _copy('Аренда'), 'Аренда');
    expect(progress.words, {'rental'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialogs and sheets capture the same profile scope', (
    tester,
  ) async {
    final progress = DictionaryProgress(storage: MemoryStorage());
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        const Dialog(child: DictionaryText('Подписка')),
                  ),
                  child: const Text('Диалог'),
                ),
                TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const DictionaryText('Возврат долга'),
                  ),
                  child: const Text('Лист'),
                ),
              ],
            ),
          ),
        ),
        progress: progress,
      ),
    );
    for (final entry in {
      'Диалог': 'Подписка',
      'Лист': 'Возврат долга',
    }.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      await _explain(tester, _copy(entry.value), entry.value);
      await tester.tap(find.byKey(const Key('close-explanation')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    expect(progress.words, {'subscription', 'repayment'});
  });

  testWidgets('320px and 200% text retain plain Text line metrics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final progress = DictionaryProgress(storage: MemoryStorage());
    addTearDown(progress.dispose);
    const text =
        'Выручка — это деньги от продажи. Прибыль остаётся после расходов.';
    const style = TextStyle(fontSize: 18, height: 1.35);
    await tester.pumpWidget(
      _app(const Scaffold(body: DictionaryText(text, style: style)), scale: 2),
    );
    final plainSize = tester.getSize(find.byType(Text));
    expect(tester.widget<Text>(find.byType(Text)).textSpan, isNull);
    await tester.pumpWidget(
      _app(
        const Scaffold(body: DictionaryText(text, style: style)),
        progress: progress,
        scale: 2,
      ),
    );
    expect(tester.getSize(find.byType(Text)), plainSize);
    await _explain(tester, _copy(text), 'Прибыль');
    expect(progress.words, {'profit'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('Goldfish double tap preserves the actual dialogue page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final progress = DictionaryProgress(storage: MemoryStorage());
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      _app(
        const GoldfishGameScreen(initialLevel: GoldfishLevelId.normalOne),
        progress: progress,
      ),
    );
    await tester.pumpAndSettle();
    // The first greeting has no financial terms; advance through the real story.
    for (var i = 0; i < 10; i++) {
      final copies = tester.widgetList<DictionaryText>(
        find.byType(DictionaryText),
      );
      if (copies.any((copy) => copy.data.contains('монет'))) break;
      await tester.tap(find.text('Нажми, чтобы продолжить').last);
      await tester.pumpAndSettle();
    }
    final copy = tester
        .widgetList<DictionaryText>(find.byType(DictionaryText))
        .firstWhere((copy) => copy.data.contains('монет'));
    await _explain(tester, _copy(copy.data), 'монет');
    expect(progress.words, {'coin'});
    await tester.tap(find.byKey(const Key('close-explanation')));
    await tester.pumpAndSettle();
    expect(_copy(copy.data), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
