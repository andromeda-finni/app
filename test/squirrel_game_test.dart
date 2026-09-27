import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/games/squirrel/squirrel_game_content.dart';
import 'package:andromeda_app/games/squirrel/squirrel_game_models.dart';
import 'package:andromeda_app/games/squirrel/squirrel_game_screen.dart';
import 'package:andromeda_app/games/squirrel/squirrel_level_controller.dart';
import 'package:andromeda_app/theme/app_theme.dart';

void main() {
  test('intro substitutes the child-created pet name', () {
    final lines = squirrelIntroLinesFor(SquirrelLevel.sorting, 'Плюша');
    expect(lines.join(' '), contains('Привет, Плюша! Я Белочка.'));
    expect(lines.join(' '), contains('Магазин'));
    expect(lines.join(' '), isNot(contains('Лесная ярмарка')));
    expect(lines.join(' '), isNot(contains('Привет, Грошик!')));
  });

  test('each mechanic has its own dialogue and lesson', () {
    final intros = {
      for (final level in SquirrelLevel.values)
        squirrelIntroLinesFor(level, 'Плюша').join(' '),
    };
    final successes = {
      for (final level in SquirrelLevel.values)
        squirrelPositiveLinesFor(level).join(' '),
    };
    final lessons = {
      for (final level in SquirrelLevel.values) squirrelLessonFor(level),
    };

    expect(intros, hasLength(SquirrelLevel.values.length));
    expect(successes, hasLength(SquirrelLevel.values.length));
    expect(lessons, hasLength(SquirrelLevel.values.length));
  });

  test('only the first level of each difficulty introduces Squirrel', () {
    expect(squirrelLevelIntroducesCharacter(SquirrelLevel.sorting), isTrue);
    expect(squirrelLevelIntroducesCharacter(SquirrelLevel.findOdd), isFalse);
    expect(squirrelLevelIntroducesCharacter(SquirrelLevel.conveyor), isTrue);
    expect(squirrelLevelIntroducesCharacter(SquirrelLevel.inspect), isFalse);

    for (final level in [SquirrelLevel.findOdd, SquirrelLevel.inspect]) {
      final lines = squirrelIntroLinesFor(
        level,
        'Плюша',
        introduce: squirrelLevelIntroducesCharacter(level),
      );
      expect(lines.join(' '), isNot(contains('Я Белочка')));
      expect(lines.join(' '), isNot(contains('Привет')));
    }
  });

  test('dialogue avoids the removed words', () {
    final allText = <String>[
      for (final level in SquirrelLevel.values) ...[
        ...squirrelIntroLinesFor(level, 'Плюша'),
        ...squirrelPositiveLinesFor(level),
        ...squirrelNegativeLinesFor(level),
        squirrelLessonFor(level),
      ],
    ].join(' ').toLowerCase();

    expect(allText, isNot(contains('гнил')));
    expect(allText, isNot(contains('лента')));
    expect(
      squirrelPositiveLinesFor(SquirrelLevel.inspect),
      contains('Теперь у меня есть все необходимое. Спасибо за помощь!'),
    );
  });

  test('sorting succeeds only when every good product is bought', () {
    final controller = SquirrelLevelController(
      level: SquirrelLevel.sorting,
      random: Random(1),
    );
    while (!controller.finished) {
      controller.decideSorting(buy: controller.current!.isGood);
    }
    expect(controller.success, isTrue);
    expect(controller.budget, 0);
    expect(controller.cart, hasLength(3));
  });

  test('all four mechanics can be completed successfully', () {
    final findOdd = SquirrelLevelController(
      level: SquirrelLevel.findOdd,
      random: Random(2),
    );
    while (!findOdd.finished) {
      findOdd.chooseFindOdd(findOdd.choices.firstWhere((item) => item.isGood));
    }

    final conveyor = SquirrelLevelController(
      level: SquirrelLevel.conveyor,
      random: Random(3),
    );
    conveyor.takeFromConveyor(
      squirrelProduct(
        SquirrelProductKind.mushroom,
        SquirrelProductQuality.good,
      ),
    );
    conveyor.takeFromConveyor(
      squirrelProduct(
        SquirrelProductKind.mushroom,
        SquirrelProductQuality.good,
      ),
    );
    conveyor.takeFromConveyor(
      squirrelProduct(SquirrelProductKind.berry, SquirrelProductQuality.good),
    );
    conveyor.takeFromConveyor(
      squirrelProduct(SquirrelProductKind.nut, SquirrelProductQuality.good),
    );

    final inspect = SquirrelLevelController(
      level: SquirrelLevel.inspect,
      random: Random(4),
    );
    while (!inspect.finished) {
      inspect.inspectCurrent();
      inspect.decideInspected(buy: inspect.current!.isGood);
    }

    expect(findOdd.success, isTrue);
    expect(conveyor.success, isTrue);
    expect(inspect.success, isTrue);
  });

  test('a spoiled conveyor purchase is a safe failed attempt', () {
    final controller = SquirrelLevelController(
      level: SquirrelLevel.conveyor,
      random: Random(5),
    );
    controller.takeFromConveyor(
      squirrelProduct(SquirrelProductKind.berry, SquirrelProductQuality.bad),
    );
    expect(controller.finished, isFalse);
    expect(controller.budget, 15);
    expect(controller.cart, hasLength(1));
    expect(controller.goodCounts[SquirrelProductKind.berry], 1);

    controller.takeFromConveyor(
      squirrelProduct(SquirrelProductKind.nut, SquirrelProductQuality.bad),
    );
    expect(controller.finished, isFalse);
    controller.takeFromConveyor(
      squirrelProduct(SquirrelProductKind.mushroom, SquirrelProductQuality.bad),
    );
    expect(controller.finished, isFalse);
    controller.takeFromConveyor(
      squirrelProduct(SquirrelProductKind.berry, SquirrelProductQuality.bad),
    );

    expect(controller.finished, isTrue);
    expect(controller.success, isFalse);
    expect(controller.budget, 0);
  });

  testWidgets('dialogue is paged and difficulty choice is not shown in game', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const SquirrelGameScreen(
          difficulty: SquirrelDifficulty.normal,
          petName: 'Буся',
          isDemo: true,
        ),
      ),
    );

    expect(find.textContaining('Привет, Буся!'), findsOneWidget);
    expect(find.text('Обычная'), findsNothing);
    expect(find.text('Сложная'), findsNothing);

    await tester.tap(find.textContaining('Нажми, чтобы продолжить'));
    await tester.pump();
    expect(find.textContaining('15 монеток'), findsOneWidget);
  });
}
