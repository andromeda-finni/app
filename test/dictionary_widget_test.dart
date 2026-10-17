import 'dart:async';

import 'package:andromeda_app/dictionary/dictionary_audio.dart';
import 'package:andromeda_app/dictionary/dictionary_catalog.dart';
import 'package:andromeda_app/dictionary/dictionary_progress.dart';
import 'package:andromeda_app/dictionary/dictionary_reader.dart';
import 'package:andromeda_app/dictionary/scroll_sheet.dart';
import 'package:andromeda_app/dictionary/word_token.dart';
import 'package:andromeda_app/minigames/tugriki/tugriki_game_screen.dart';
import 'package:andromeda_app/onboarding/widgets/story_button.dart';
import 'package:andromeda_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dictionary_progress_test.dart' show MemoryStorage;

class SilentDictionaryAudio implements DictionaryAudio {
  int opens = 0;
  @override
  Future<void> openScroll() async {
    opens++;
  }
}

Offset _budgetCenter(WidgetTester tester) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.byKey(const Key('financial-story')),
  );
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final start = text.indexOf('бюджет');
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + 6),
      )
      .first;
  return paragraph.localToGlobal(box.toRect().center);
}

Future<void> _doubleTapBudget(WidgetTester tester) async {
  final center = _budgetCenter(tester);
  await tester.tapAt(center);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tapAt(center);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  await tester.pump();
}

Widget _reader(
  DictionaryProgress progress,
  SilentDictionaryAudio audio, {
  double scale = 1,
}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: true,
      textScaler: TextScaler.linear(scale),
    ),
    child: Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            FinancialStoryText(
              before: 'Наш ',
              term: 'бюджет',
              after: ' — 20 монет.',
              wordId: 'budget',
              style: AppTextStyles.story,
              onExplain: () => unawaited(
                explainDictionaryWord(
                  context,
                  progress: progress,
                  word: budgetWord,
                  audio: audio,
                ),
              ),
            ),
            TextButton(
              onPressed: () => showDictionaryScroll(
                context,
                progress: progress,
                audio: audio,
              ),
              child: const Text('Словарик'),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final body = FontLoader('PTSerif')
      ..addFont(rootBundle.load('assets/fonts/PTSerif-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PTSerif-Bold.ttf'));
    final title = FontLoader('Monomakh')
      ..addFont(rootBundle.load('assets/fonts/ofont.ru_Monomakh Unicode.ttf'));
    await Future.wait([body.load(), title.load()]);
  });

  testWidgets('a failed notes load never hides the definition', (tester) async {
    final storage = MemoryStorage()..value = '{bad json';
    final progress = DictionaryProgress(storage: storage);
    await tester.pumpWidget(_reader(progress, SilentDictionaryAudio()));
    await _doubleTapBudget(tester);
    expect(find.byKey(const Key('word-definition')), findsOneWidget);
    expect(find.byKey(const Key('word-added-notice')), findsNothing);
    expect(progress.loaded, isFalse);
    storage.value = null;
    await tester.tap(find.text('Сохранить ещё раз'));
    await tester.pumpAndSettle();
    expect(progress.words, {'budget'});
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'inline glyph glow preserves text metrics; only double tap adds once',
    (tester) async {
      final progress = DictionaryProgress(storage: MemoryStorage());
      final audio = SilentDictionaryAudio();
      await tester.pumpWidget(_reader(progress, audio));
      final text = tester.widget<Text>(
        find.byKey(const Key('financial-story')),
      );
      final span = text.textSpan! as TextSpan;
      final term = span.children![1] as TextSpan;
      expect(span.children!.whereType<WidgetSpan>(), isEmpty);
      expect(term.style!.fontSize, isNull);
      expect(term.style!.fontWeight, isNull);
      expect(
        term.style!.shadows!.every((shadow) => shadow.blurRadius > 0),
        isTrue,
      );
      await tester.tapAt(_budgetCenter(tester));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('word-definition')), findsNothing);
      await _doubleTapBudget(tester);
      expect(find.byKey(const Key('word-added-notice')), findsOneWidget);
      expect(progress.words, {'budget'});
      expect(audio.opens, 0);
      await tester.tap(find.byKey(const Key('close-explanation')));
      await tester.pumpAndSettle();
      await _doubleTapBudget(tester);
      expect(find.byKey(const Key('word-added-notice')), findsNothing);
      await tester.tap(find.byKey(const Key('explanation-open-dictionary')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dictionary-search')), findsOneWidget);
      expect(audio.opens, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('50 words scroll to the last entry without recording a read', (
    tester,
  ) async {
    final progress = DictionaryProgress(storage: MemoryStorage());
    await progress.load();
    await tester.pumpWidget(_reader(progress, SilentDictionaryAudio()));
    await tester.tap(find.text('Словарик'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('entry-economy')),
      500,
      scrollable: find.descendant(
        of: find.byKey(const Key('dictionary-list')),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 40,
    );
    expect(find.byKey(const Key('entry-economy')), findsOneWidget);
    expect(find.text('Прочитано 0 из 50 · ещё 50'), findsOneWidget);
    expect(progress.words, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unread search stays readable at 320px and 200 percent type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final progress = DictionaryProgress(storage: MemoryStorage());
    await progress.load();
    await tester.pumpWidget(
      _reader(progress, SilentDictionaryAudio(), scale: 2),
    );
    await tester.tap(find.text('Словарик'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-unread')));
    await tester.enterText(
      find.byKey(const Key('dictionary-search')),
      'кошелек',
    );
    await tester.pumpAndSettle();
    final heading = find.descendant(
      of: find.byKey(const Key('entry-wallet')),
      matching: find.text('Кошелёк'),
    );
    await tester.tap(heading);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('definition-wallet')));
    expect(progress.words, {'wallet'});
    expect(find.text('Прочитано 1 из 50 · ещё 49'), findsOneWidget);
    expect(find.byKey(const Key('definition-wallet')), findsOneWidget);
    await tester.ensureVisible(heading);
    await tester.tap(heading);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('entry-wallet')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed saving leaves the meaning available and can be retried', (
    tester,
  ) async {
    final storage = MemoryStorage()..fail = true;
    final progress = DictionaryProgress(storage: storage);
    await tester.pumpWidget(_reader(progress, SilentDictionaryAudio()));
    await _doubleTapBudget(tester);
    expect(find.byKey(const Key('word-definition')), findsOneWidget);
    expect(find.byKey(const Key('word-added-notice')), findsNothing);
    expect(progress.words, isEmpty);
    storage.fail = false;
    await tester.tap(find.text('Сохранить ещё раз'));
    await tester.pumpAndSettle();
    expect(progress.words, {'budget'});
    expect(find.byKey(const Key('word-added-notice')), findsOneWidget);
  });

  testWidgets(
    'Tugriki explains budget without advancing or changing purchases',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final progress = DictionaryProgress(storage: MemoryStorage());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TugrikiGameScreen(dictionaryProgress: progress),
        ),
      );
      // Follow the real story and fill the six coin pairs; no test-only stage API.
      for (
        var i = 0;
        i < 20 && find.byType(FinancialStoryText).evaluate().isEmpty;
        i++
      ) {
        await tester.tap(find.byType(StoryButton).first);
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(FinancialStoryText), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('financial-story')))
            .style!
            .fontSize,
        15.5,
      );
      await _doubleTapBudget(tester);
      expect(find.byKey(const Key('word-definition')), findsOneWidget);
      expect(progress.words, {'budget'});
      await tester.tap(find.byKey(const Key('close-explanation')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Выбрать товары в лоток ➔'), findsOneWidget);
      expect(find.byType(FinancialStoryText), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
