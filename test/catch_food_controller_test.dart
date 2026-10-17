import 'dart:math';

import 'package:andromeda_app/minigames/catch_food/catch_food_board.dart';
import 'package:andromeda_app/minigames/catch_food/catch_food_controller.dart';
import 'package:andromeda_app/minigames/catch_food/catch_food_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

CatchFoodController game({int spoiledFoodPercent = 0}) => CatchFoodController(
  config: CatchFoodConfig(spoiledFoodPercent: spoiledFoodPercent),
  random: Random(17),
)..start();

void main() {
  test('only the matching bowl catches a piece, exactly once', () {
    final controller = game()..advance(const Duration(milliseconds: 600));
    controller.select(controller.pieces.first.lane);
    controller.advance(const Duration(milliseconds: 2400));
    expect(controller.score, 1);
    expect(controller.misses, 0);
    controller.advance(const Duration(milliseconds: 10));
    expect(controller.score, 1);
    expect(controller.pieces.any((piece) => piece.id == 0), isFalse);
  });

  test('a late switch inside the catching window still succeeds', () {
    final controller = game()..advance(const Duration(milliseconds: 600));
    final lane = controller.pieces.first.lane;
    controller.select(CatchLane.values[(lane.index + 1) % 4]);
    controller.advance(const Duration(milliseconds: 2500));
    expect(controller.score, 0);
    expect(controller.misses, 0);
    controller.select(lane);
    controller.advance(const Duration(milliseconds: 1));
    expect(controller.score, 1);
  });

  test('a wrong position misses only after the complete grace window', () {
    final controller = game()..advance(const Duration(milliseconds: 600));
    final lane = controller.pieces.first.lane;
    controller.select(CatchLane.values[(lane.index + 1) % 4]);
    controller.advance(const Duration(milliseconds: 2580));
    expect(controller.misses, 0);
    controller.advance(const Duration(milliseconds: 1));
    expect(controller.misses, 1);
    expect(controller.score, 0);
  });

  test('pause freezes pellets, fatigue and the active clock', () {
    final controller = game()..advance(const Duration(seconds: 1));
    final pieces = controller.pieces.length;
    controller.pause();
    controller.advance(const Duration(hours: 2));
    controller.select(CatchLane.upperRight);
    expect(controller.elapsedMs, 1000);
    expect(controller.pieces.length, pieces);
    expect(controller.phase, CatchFoodPhase.paused);
    controller.resume();
    controller.advance(const Duration(seconds: 1));
    expect(controller.elapsedMs, 2000);
  });

  test('catching spoiled food costs one mistake and never awards a point', () {
    final controller = game(spoiledFoodPercent: 100);
    while (controller.phase == CatchFoodPhase.playing) {
      if (controller.pieces.isNotEmpty) {
        controller.select(controller.pieces.first.lane);
      }
      controller.advance(const Duration(milliseconds: 8));
    }
    // The first piece is always fresh, even with spoiled-only test balancing.
    expect(controller.score, 1);
    expect(controller.misses, 3);
    expect(controller.result.reason, CatchFoodFinish.misses);
    expect(controller.lastSpoiledCatchUs, controller.lastMissUs);
    final lastMiss = controller.lastMissUs;
    controller.advance(const Duration(seconds: 5));
    expect(controller.misses, 3);
    expect(controller.lastMissUs, lastMiss);
  });

  test('spoiled food may be skipped through its whole catching window', () {
    final controller = game(spoiledFoodPercent: 100);
    while (controller.phase == CatchFoodPhase.playing) {
      if (controller.pieces.isNotEmpty) {
        final piece = controller.pieces.first;
        controller.select(
          piece.kind == FoodKind.fresh
              ? piece.lane
              : CatchLane.values[(piece.lane.index + 1) % 4],
        );
      }
      controller.advance(const Duration(milliseconds: 8));
    }
    expect(controller.score, 1);
    expect(controller.misses, 0);
    expect(controller.lastSpoiledCatchUs, isNegative);
    expect(controller.result.reason, CatchFoodFinish.tired);
  });

  test('a mixed run rewards fresh food while safely avoiding spoiled food', () {
    final controller = game(spoiledFoodPercent: 20);
    final freshIds = <int>{};
    final spoiledIds = <int>{};
    while (controller.phase == CatchFoodPhase.playing) {
      if (controller.pieces.isNotEmpty) {
        final piece = controller.pieces.first;
        (piece.kind == FoodKind.fresh ? freshIds : spoiledIds).add(piece.id);
        controller.select(
          piece.kind == FoodKind.fresh
              ? piece.lane
              : CatchLane.values[(piece.lane.index + 1) % 4],
        );
      }
      controller.advance(const Duration(milliseconds: 8));
    }
    expect(freshIds, isNotEmpty);
    expect(spoiledIds, isNotEmpty);
    expect(controller.score, greaterThan(20));
    expect(controller.misses, 0);
    expect(controller.result.reason, CatchFoodFinish.tired);
  });

  test('three misses end a run and the score is immutable afterwards', () {
    final controller = game();
    while (controller.phase == CatchFoodPhase.playing) {
      if (controller.pieces.isNotEmpty) {
        final lane = controller.pieces.first.lane;
        controller.select(CatchLane.values[(lane.index + 1) % 4]);
      }
      controller.advance(const Duration(milliseconds: 10));
    }
    expect(controller.misses, 3);
    expect(controller.result.reason, CatchFoodFinish.misses);
    final time = controller.elapsedMs;
    controller.advance(const Duration(minutes: 10));
    expect(controller.elapsedMs, time);
    expect(controller.misses, 3);
  });

  test('fatigue ends successful play at exactly sixty active seconds', () {
    final controller = game();
    while (controller.phase == CatchFoodPhase.playing) {
      if (controller.pieces.isNotEmpty) {
        controller.select(controller.pieces.first.lane);
      }
      controller.advance(const Duration(milliseconds: 8));
    }
    expect(controller.elapsedMs, 60000);
    expect(controller.result.reason, CatchFoodFinish.tired);
    expect(controller.misses, 0);
    expect(controller.score, greaterThan(40));
    expect(controller.remainingSeconds, 0);
  });

  test('a stalled frame cannot skip arrival resolution', () {
    final whole = game();
    final frames = game();
    whole.advance(const Duration(seconds: 5));
    for (var i = 0; i < 500; i++) {
      frames.advance(const Duration(milliseconds: 10));
    }
    expect(whole.score, frames.score);
    expect(whole.misses, frames.misses);
    expect(
      whole.pieces.map((piece) => piece.id),
      frames.pieces.map((piece) => piece.id),
    );
  });

  test(
    'manual finish works from pause and cannot restart the paid attempt',
    () {
      final controller = game()..advance(const Duration(seconds: 1));
      controller.pause();
      controller.stop();
      controller.start();
      expect(controller.phase, CatchFoodPhase.finished);
      expect(controller.result.reason, CatchFoodFinish.stopped);
      expect(controller.result.elapsedMs, 1000);
    },
  );

  test('malformed server configuration is rejected before play', () {
    expect(() => CatchFoodConfig.fromJson({}), throwsFormatException);
    expect(
      () => CatchFoodConfig.fromJson({
        'energyCost': 20,
        'durationMs': 60000,
        'maxMisses': 3,
        'travelMs': 2400,
        'firstSpawnMs': 600,
        'initialSpawnMs': 1300,
        'minimumSpawnMs': 1500,
        'catchWindowMs': 180,
        'spoiledFoodPercent': 20,
      }),
      throwsFormatException,
    );
  });

  test(
    'server percentage validates both limits and rejects malformed values',
    () {
      final json = {
        'energyCost': 20,
        'durationMs': 60000,
        'maxMisses': 3,
        'travelMs': 2400,
        'firstSpawnMs': 600,
        'initialSpawnMs': 1300,
        'minimumSpawnMs': 700,
        'catchWindowMs': 180,
        'spoiledFoodPercent': 20,
      };
      for (final percent in [0, 20, 100]) {
        expect(
          CatchFoodConfig.fromJson({...json, 'spoiledFoodPercent': percent})
              .spoiledFoodPercent,
          percent,
        );
      }
      for (final invalid in [-1, 101, 1.5, '20', null]) {
        expect(
          () => CatchFoodConfig.fromJson({
            ...json,
            'spoiledFoodPercent': invalid,
          }),
          throwsFormatException,
        );
      }
    },
  );

  for (final size in [
    const Size(320, 450),
    const Size(430, 600),
    const Size(390, 280),
  ]) {
    test('all four paths end inside their drawn bowl at $size', () {
      final layout = CatchFoodLayout(size);
      for (final lane in CatchLane.values) {
        final bowl = layout.bowl(lane);
        expect(bowl.dx, inExclusiveRange(0, size.width));
        expect(bowl.dy, inExclusiveRange(0, size.height));
        expect((layout.foodPosition(lane, 1) - bowl).distance, lessThan(1e-8));
        expect(layout.chuteRect(lane).top, greaterThanOrEqualTo(0));
      }
      expect(
        layout.bowl(CatchLane.upperLeft).dy,
        lessThan(layout.bowl(CatchLane.lowerLeft).dy - 20),
      );
      expect(
        layout.bowl(CatchLane.upperRight).dy,
        lessThan(layout.bowl(CatchLane.lowerRight).dy - 20),
      );
    });
  }
}
