import 'dart:math';

import 'catch_food_models.dart';

enum FoodKind { fresh, spoiled }

class FoodPiece {
  const FoodPiece({
    required this.id,
    required this.lane,
    required this.spawnUs,
    required this.kind,
  });

  final int id;
  final CatchLane lane;
  final int spawnUs;
  final FoodKind kind;

  double progress(int elapsedUs, int travelMs) =>
      (elapsedUs - spawnUs) / (travelMs * 1000);
}

/// The clock advances only through active play. Small fixed steps ensure a
/// slow frame cannot skip a catching window or register the same pellet twice.
class CatchFoodController {
  CatchFoodController({required this.config, Random? random})
    : _random = random ?? Random();

  final CatchFoodConfig config;
  final Random _random;
  final List<FoodPiece> _pieces = [];
  CatchFoodPhase phase = CatchFoodPhase.ready;
  CatchLane selected = CatchLane.lowerLeft;
  int elapsedUs = 0;
  int score = 0;
  int misses = 0;
  int _nextSpawnUs = 0;
  int _nextId = 0;
  CatchFoodFinish? finishReason;
  CatchLane? lastCatchLane;
  CatchLane? lastMissLane;
  int lastCatchUs = -1000000;
  int lastMissUs = -1000000;
  int lastSpoiledCatchUs = -1000000;

  List<FoodPiece> get pieces => List.unmodifiable(_pieces);
  int get elapsedMs => elapsedUs ~/ 1000;
  double get fatigue => (elapsedMs / config.durationMs).clamp(0, 1);
  int get remainingSeconds =>
      ((config.durationMs - elapsedMs) / 1000).ceil().clamp(0, 600);

  CatchFoodResult get result {
    if (phase != CatchFoodPhase.finished) {
      throw StateError('The attempt is still active');
    }
    return CatchFoodResult(
      score: score,
      misses: misses,
      elapsedMs: elapsedMs,
      reason: finishReason!,
    );
  }

  void start() {
    if (phase != CatchFoodPhase.ready) return;
    _nextSpawnUs = config.firstSpawnMs * 1000;
    phase = CatchFoodPhase.playing;
  }

  void select(CatchLane lane) {
    if (phase == CatchFoodPhase.playing) selected = lane;
  }

  void pause() {
    if (phase == CatchFoodPhase.playing) phase = CatchFoodPhase.paused;
  }

  void resume() {
    if (phase == CatchFoodPhase.paused) phase = CatchFoodPhase.playing;
  }

  void stop() {
    if (phase == CatchFoodPhase.playing || phase == CatchFoodPhase.paused) {
      finishReason = CatchFoodFinish.stopped;
      phase = CatchFoodPhase.finished;
    }
  }

  void advance(Duration delta) {
    if (phase != CatchFoodPhase.playing || delta.isNegative) return;
    var remaining = delta.inMicroseconds;
    while (remaining > 0 && phase == CatchFoodPhase.playing) {
      final step = min(remaining, 16000);
      _advanceStep(step);
      remaining -= step;
    }
  }

  void _advanceStep(int deltaUs) {
    elapsedUs = min(elapsedUs + deltaUs, config.durationMs * 1000);
    while (_nextSpawnUs <= elapsedUs &&
        _nextSpawnUs < config.durationMs * 1000) {
      _pieces.add(
        FoodPiece(
          id: _nextId,
          lane: CatchLane.values[_random.nextInt(CatchLane.values.length)],
          spawnUs: _nextSpawnUs,
          // Let the first piece teach catching before introducing avoidance.
          kind:
              _nextId > 0 &&
                  config.spoiledFoodPercent > 0 &&
                  _random.nextInt(100) < config.spoiledFoodPercent
              ? FoodKind.spoiled
              : FoodKind.fresh,
        ),
      );
      _nextId++;
      final difficulty = _nextSpawnUs / (config.durationMs * 1000);
      final intervalMs =
          config.initialSpawnMs -
          ((config.initialSpawnMs - config.minimumSpawnMs) * difficulty)
              .round();
      _nextSpawnUs += intervalMs * 1000;
    }
    final resolved = <FoodPiece>[];
    for (final piece in _pieces) {
      final age = elapsedUs - piece.spawnUs;
      if (age < config.travelMs * 1000) continue;
      if (piece.lane == selected) {
        if (piece.kind == FoodKind.spoiled) {
          lastSpoiledCatchUs = elapsedUs;
          _miss(piece.lane);
        } else {
          score++;
          lastCatchLane = piece.lane;
          lastCatchUs = elapsedUs;
        }
        resolved.add(piece);
      } else if (age > (config.travelMs + config.catchWindowMs) * 1000) {
        if (piece.kind == FoodKind.fresh) _miss(piece.lane);
        resolved.add(piece);
      }
      if (phase == CatchFoodPhase.finished) break;
    }
    _pieces.removeWhere(resolved.contains);
    if (phase == CatchFoodPhase.playing && elapsedMs >= config.durationMs) {
      finishReason = CatchFoodFinish.tired;
      phase = CatchFoodPhase.finished;
    }
  }

  void _miss(CatchLane lane) {
    misses++;
    lastMissLane = lane;
    lastMissUs = elapsedUs;
    if (misses >= config.maxMisses) {
      finishReason = CatchFoodFinish.misses;
      phase = CatchFoodPhase.finished;
    }
  }
}
