import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/games/goldfish/goldfish_game_content.dart';
import 'package:andromeda_app/games/goldfish/goldfish_game_controller.dart';
import 'package:andromeda_app/games/goldfish/goldfish_game_models.dart';
import 'package:andromeda_app/games/goldfish/goldfish_game_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';

void main() {
  group('Goldfish level rules', () {
    test('rewards follow the economy scale', () {
      expect(GoldfishLevelId.normalOne.reward, 10);
      expect(GoldfishLevelId.normalTwo.reward, 10);
      expect(GoldfishLevelId.hardOne.reward, 12);
      expect(GoldfishLevelId.hardTwo.reward, 15);
    });

    test('the entered pet name appears in dialogue', () {
      final normal = goldfishLevelFor(
        GoldfishLevelId.normalOne,
        petName: 'Буся',
      );
      final hard = goldfishLevelFor(GoldfishLevelId.hardOne, petName: 'Буся');

      expect(
        normal.introLines.map((line) => line.text).join(' '),
        contains('Буся'),
      );
      expect(
        hard.introLines.map((line) => line.text).join(' '),
        contains('Буся'),
      );
    });

    test('only the first level of each difficulty introduces the story', () {
      for (final id in [GoldfishLevelId.normalOne, GoldfishLevelId.hardOne]) {
        expect(
          goldfishLevelFor(
            id,
            petName: 'Лучик',
          ).introLines.map((line) => line.text).join(' '),
          contains('Привет, Лучик'),
        );
      }

      for (final id in [GoldfishLevelId.normalTwo, GoldfishLevelId.hardTwo]) {
        expect(
          goldfishLevelFor(
            id,
            petName: 'Лучик',
          ).introLines.map((line) => line.text).join(' '),
          isNot(contains('Привет')),
        );
      }
    });

    test('every level has a valid basket', () {
      final validBaskets = <GoldfishLevelId, List<String>>{
        GoldfishLevelId.normalOne: ['roof_basic', 'bed_basic', 'window_basic'],
        GoldfishLevelId.normalTwo: [
          'roof_basic',
          'blanket_down',
          'window_basic',
        ],
        GoldfishLevelId.hardOne: [
          'roof_basic',
          'bed_basic',
          'window_basic',
          'blanket_down',
        ],
        GoldfishLevelId.hardTwo: [
          'roof_basic',
          'bed_basic',
          'window_basic',
          'shawl_down',
        ],
      };

      for (final entry in validBaskets.entries) {
        final controller = GoldfishGameController(
          goldfishLevelFor(entry.key, petName: 'Лучик'),
        );
        while (controller.phase == GoldfishGamePhase.intro) {
          controller.advanceDialogue();
        }
        for (final id in entry.value) {
          expect(controller.toggleOffer(id).changed, isTrue);
        }
        expect(
          controller.checkSelection().isSuccessful,
          isTrue,
          reason: '${entry.key}',
        );
      }
    });

    test('first hard level describes a thrifty practical selection', () {
      final controller = GoldfishGameController(
        goldfishLevelFor(GoldfishLevelId.hardOne, petName: 'Лучик'),
      );
      while (controller.phase == GoldfishGamePhase.intro) {
        controller.advanceDialogue();
      }
      for (final id in [
        'roof_basic',
        'bed_basic',
        'window_basic',
        'blanket_down',
      ]) {
        controller.toggleOffer(id);
      }

      expect(controller.checkSelection().isSuccessful, isTrue);
      final dialogue = controller.activeDialogue
          .map((line) => line.text)
          .join(' ');
      expect(dialogue, contains('сохранить часть монет'));
      expect(dialogue, isNot(contains('понаряднее')));
    });

    test(
      'first hard level mentions an ornate item only when one was bought',
      () {
        final controller = GoldfishGameController(
          goldfishLevelFor(GoldfishLevelId.hardOne, petName: 'Лучик'),
        );
        while (controller.phase == GoldfishGamePhase.intro) {
          controller.advanceDialogue();
        }
        for (final id in [
          'roof_basic',
          'bed_basic',
          'window_basic',
          'blanket_ornate',
        ]) {
          controller.toggleOffer(id);
        }

        expect(controller.checkSelection().isSuccessful, isTrue);
        final dialogue = controller.activeDialogue
            .map((line) => line.text)
            .join(' ');
        expect(dialogue, contains('понаряднее'));
      },
    );

    test('final hard level enforces a three-coin reserve', () {
      final controller = GoldfishGameController(
        goldfishLevelFor(GoldfishLevelId.hardTwo, petName: 'Лучик'),
      );
      while (controller.phase == GoldfishGamePhase.intro) {
        controller.advanceDialogue();
      }
      for (final id in [
        'roof_basic',
        'bed_basic',
        'window_basic',
        'shawl_down',
        'lamp',
      ]) {
        controller.toggleOffer(id);
      }
      expect(controller.remaining, 3);
      expect(controller.checkSelection().isSuccessful, isTrue);

      controller.replay();
      controller
        ..toggleOffer('roof_basic')
        ..toggleOffer('bed_basic')
        ..toggleOffer('window_ornate')
        ..toggleOffer('shawl_down')
        ..toggleOffer('lamp');
      final result = controller.checkSelection();
      expect(result.isSuccessful, isFalse);
      expect(result.isReserveTooSmall, isTrue);
    });

    test('unfinished track continues even if preference changes', () {
      expect(
        nextGoldfishLevel(
          completedQuestIds: {GoldfishLevelId.normalOne.questId},
          preferredDifficulty: GoldfishDifficulty.hard,
        ),
        GoldfishLevelId.normalTwo,
      );
    });
  });

  testWidgets('dialogue is paged and shows only the current speaker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const GoldfishGameScreen(
          initialLevel: GoldfishLevelId.normalOne,
          petName: 'Буся',
          enableSequentialNext: false,
        ),
      ),
    );

    expect(find.textContaining('Привет, Буся'), findsOneWidget);
    expect(find.bySemanticsLabel('Бабушка говорит'), findsOneWidget);
    expect(find.bySemanticsLabel('Дедушка говорит'), findsNothing);
    expect(find.text('Нормальный'), findsNothing);
    expect(find.text('Сложный'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('goldfish-dialogue-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Нам нужна новая крыша, кровать и окно.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('goldfish-dialogue-continue')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Золотая рыбка говорит'), findsOneWidget);
    expect(find.bySemanticsLabel('Бабушка говорит'), findsNothing);
  });

  testWidgets('successful purchase immediately shows the renovated home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const GoldfishGameScreen(
          initialLevel: GoldfishLevelId.normalOne,
          petName: 'Буся',
          enableSequentialNext: false,
        ),
      ),
    );

    for (var i = 0; i < 4; i++) {
      await tester.tap(
        find.byKey(const ValueKey('goldfish-dialogue-continue')),
      );
      await tester.pump();
    }
    for (final id in ['roof_basic', 'bed_basic', 'window_basic']) {
      await tester.tap(find.byKey(ValueKey('goldfish-item-$id')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('goldfish-check-selection')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('goldfish-home-renovated')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('goldfish-home-needs-repair')),
      findsNothing,
    );
  });

  testWidgets('insufficient coins use a storybook notice', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const GoldfishGameScreen(
          initialLevel: GoldfishLevelId.normalOne,
          enableSequentialNext: false,
        ),
      ),
    );

    for (var i = 0; i < 4; i++) {
      await tester.tap(
        find.byKey(const ValueKey('goldfish-dialogue-continue')),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('goldfish-item-roof_ornate')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goldfish-item-bed_ornate')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('goldfish-insufficient-coins-notice')),
      findsOneWidget,
    );
    expect(find.text('Не хватает 3 монет'), findsOneWidget);
    expect(find.text('Сравни цены и выбери товар подешевле.'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).behavior,
      SnackBarBehavior.floating,
    );
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(412, 732),
  ]) {
    testWidgets('shopping fits ${size.width.toInt()} logical pixels', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const GoldfishGameScreen(
            initialLevel: GoldfishLevelId.hardTwo,
            enableSequentialNext: false,
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(
          find.byKey(const ValueKey('goldfish-dialogue-continue')),
        );
        await tester.pump();
      }

      expect(
        find.byKey(const ValueKey('goldfish-product-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('goldfish-home-target')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
