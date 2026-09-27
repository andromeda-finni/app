import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/games/ivan/ivan_game_content.dart';
import 'package:andromeda_app/games/ivan/ivan_game_controller.dart';
import 'package:andromeda_app/games/ivan/ivan_game_models.dart';
import 'package:andromeda_app/games/ivan/ivan_game_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';

void main() {
  group('Ivan level rules', () {
    test('all four levels use the economy reward scale', () {
      expect(ivanLevelFor(IvanLevelId.easyOne, petName: 'Лучик').reward, 10);
      expect(ivanLevelFor(IvanLevelId.easyTwo, petName: 'Лучик').reward, 10);
      expect(ivanLevelFor(IvanLevelId.hardOne, petName: 'Лучик').reward, 12);
      expect(ivanLevelFor(IvanLevelId.hardTwo, petName: 'Лучик').reward, 12);
    });

    test('candle replaces tinderbox in every child-facing string', () {
      final allText = <String>[
        for (final id in IvanLevelId.values) ...[
          ivanLevelFor(id, petName: 'Лучик').taskText,
          ivanLevelFor(id, petName: 'Лучик').hintText,
          ivanLevelFor(id, petName: 'Лучик').successText,
          for (final line in ivanLevelFor(id, petName: 'Лучик').introLines)
            line.text,
          for (final item in ivanLevelFor(id, petName: 'Лучик').items)
            item.name,
        ],
      ].join(' ').toLowerCase();

      expect(allText, isNot(contains('огнив')));
      expect(
        ivanLevelFor(IvanLevelId.easyTwo, petName: 'Лучик').items,
        contains(IvanCatalog.candle),
      );
    });

    test('first level introduces Ivan and second level does not repeat it', () {
      final first = ivanLevelFor(IvanLevelId.easyOne, petName: 'Лучик');
      final second = ivanLevelFor(IvanLevelId.easyTwo, petName: 'Лучик');
      expect(first.introLines.first.text, contains('Привет, Лучик'));
      expect(
        second.introLines.map((line) => line.text).join(' '),
        isNot(contains('Привет')),
      );
    });

    test('selection requires essentials and stays inside the budget', () {
      final controller = IvanGameController(
        ivanLevelFor(IvanLevelId.easyOne, petName: 'Лучик'),
      );
      controller
        ..advanceIntro()
        ..advanceIntro()
        ..toggleItem('pies');
      var result = controller.checkSelection();
      expect(result.isSuccessful, isFalse);
      expect(result.missingRequirements, contains('тёплая одежда'));

      controller
        ..reviseSelection()
        ..toggleItem('warm_shirt_easy');
      result = controller.checkSelection();
      expect(result.isSuccessful, isTrue);
      expect(result.spent, 7);
    });

    test('removing an item refunds its price', () {
      final controller = IvanGameController(
        ivanLevelFor(IvanLevelId.hardTwo, petName: 'Лучик'),
      );
      controller
        ..advanceIntro()
        ..advanceIntro()
        ..toggleItem('speed_boots');
      expect(controller.spent, 7);
      controller.toggleItem('speed_boots');
      expect(controller.spent, 0);
      expect(controller.remaining, 15);
    });

    test('an unfinished track continues before a changed preference', () {
      expect(
        nextIvanLevel(
          completedQuestIds: {IvanLevelId.easyOne.questId},
          preferredDifficulty: IvanDifficulty.hard,
        ),
        IvanLevelId.easyTwo,
      );
    });
  });

  testWidgets('card shows image, name and price and hint opens', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const IvanGameScreen(
          initialLevel: IvanLevelId.easyOne,
          petName: 'Лучик',
          enableSequentialNext: false,
        ),
      ),
    );

    expect(find.textContaining('Привет, Лучик'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ivan-intro-continue-area')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ivan-intro-continue-area')));
    await tester.pumpAndSettle();

    expect(find.text('Пирожки'), findsOneWidget);
    expect(find.byKey(const ValueKey('ivan-item-pies')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ivan-hint-button')));
    await tester.pumpAndSettle();
    expect(find.text('Подсказка'), findsOneWidget);
    expect(find.textContaining('Иван проголодается'), findsOneWidget);
  });

  testWidgets('successful demo level shows learning card and reward value', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const IvanGameScreen(
          initialLevel: IvanLevelId.easyOne,
          petName: 'Лучик',
          enableSequentialNext: false,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('ivan-intro-continue-area')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ivan-intro-continue-area')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ivan-item-pies')));
    await tester.tap(find.byKey(const ValueKey('ivan-item-warm_shirt_easy')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ivan-check-selection')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ivan-dialogue-portrait')), findsNothing);
    expect(find.byKey(const ValueKey('ivan-result-card')), findsOneWidget);
    expect(find.text('Что важно запомнить'), findsOneWidget);
    expect(find.textContaining('награда 10 монет'), findsOneWidget);
  });

  testWidgets('shopping view fits a narrow phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const IvanGameScreen(
          initialLevel: IvanLevelId.hardTwo,
          enableSequentialNext: false,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('ivan-intro-continue-area')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ivan-intro-continue-area')));
    await tester.pump();

    expect(find.byKey(const ValueKey('ivan-product-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
