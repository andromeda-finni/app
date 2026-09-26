import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/games/turnip/turnip_game_controller.dart';
import 'package:andromeda_app/games/turnip/turnip_game_models.dart';

void main() {
  test('tray order is shuffled once per round', () {
    final controller = TurnipGameController(
      difficulty: TurnipDifficulty.normal,
      random: Random(7),
    );

    final firstRound = controller.trayCharacters.toList();
    expect(firstRound, unorderedEquals(TurnipCharacter.values));
    expect(firstRound, isNot(equals(TurnipCharacter.values)));

    controller.restart();
    expect(controller.trayCharacters, unorderedEquals(TurnipCharacter.values));
    expect(controller.trayCharacters, isNot(equals(firstRound)));
  });

  test('normal version accepts every unique helper in any order', () {
    final controller = TurnipGameController(
      difficulty: TurnipDifficulty.normal,
    );
    controller.advanceIntro(pageCount: 1);

    final order = [
      TurnipCharacter.mouse,
      TurnipCharacter.cat,
      TurnipCharacter.zhuchka,
      TurnipCharacter.granddaughter,
      TurnipCharacter.grandmother,
    ];

    for (final character in order.take(order.length - 1)) {
      expect(controller.place(character), TurnipPlacementResult.accepted);
    }
    expect(controller.place(order.last), TurnipPlacementResult.completed);
    expect(controller.placedCharacters, order);
    expect(controller.phase, TurnipGamePhase.pulling);

    controller.finishPulling();
    expect(controller.phase, TurnipGamePhase.completed);
    expect(controller.result.questId, turnipQuestId);
    expect(controller.result.rewardAmount, 10);
  });

  test('hard version keeps progress and rejects a helper out of order', () {
    final controller = TurnipGameController(difficulty: TurnipDifficulty.hard);
    controller.advanceIntro(pageCount: 1);

    expect(
      controller.place(TurnipCharacter.mouse),
      TurnipPlacementResult.rejected,
    );
    expect(controller.placedCharacters, isEmpty);
    expect(controller.wrongAttempts, 1);
    expect(controller.expectedCharacter, TurnipCharacter.grandmother);

    expect(
      controller.place(TurnipCharacter.grandmother),
      TurnipPlacementResult.accepted,
    );
    expect(controller.placedCharacters, [TurnipCharacter.grandmother]);
    expect(controller.result.questId, turnipQuestId);
    expect(controller.result.rewardAmount, 12);
  });

  test('hard version reveals the hint after three consecutive mistakes', () {
    final controller = TurnipGameController(difficulty: TurnipDifficulty.hard);
    controller.advanceIntro(pageCount: 1);

    for (var attempt = 0; attempt < 3; attempt++) {
      controller.place(TurnipCharacter.mouse);
    }

    expect(controller.hintVisible, isTrue);
    expect(controller.hintUsed, isTrue);
    expect(controller.wrongAttempts, 3);
  });

  test('a duplicate helper cannot be counted twice', () {
    final controller = TurnipGameController(
      difficulty: TurnipDifficulty.normal,
    );
    controller.advanceIntro(pageCount: 1);

    expect(
      controller.place(TurnipCharacter.grandmother),
      TurnipPlacementResult.accepted,
    );
    expect(
      controller.place(TurnipCharacter.grandmother),
      TurnipPlacementResult.ignored,
    );
    expect(controller.placedCharacters, [TurnipCharacter.grandmother]);
  });

  test('replay keeps the external version and starts at the playfield', () {
    final controller = TurnipGameController(difficulty: TurnipDifficulty.hard);
    controller.advanceIntro(pageCount: 1);
    controller.place(TurnipCharacter.mouse);
    controller.showHint();

    controller.restart();

    expect(controller.difficulty, TurnipDifficulty.hard);
    expect(controller.phase, TurnipGamePhase.playing);
    expect(controller.placedCharacters, isEmpty);
    expect(controller.wrongAttempts, 0);
    expect(controller.hintVisible, isFalse);
  });
}
