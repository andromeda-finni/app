import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'catch_food_controller.dart';
import 'catch_food_models.dart';

/// Measured from the approved PNGs, retained by the proportional WebP export.
/// Bowl positions also define the pellet paths, so every collision coincides
/// with the actual drawing rather than an unrelated invisible hit target.
class CatchFoodLayout {
  CatchFoodLayout(this.size);
  final Size size;

  static const _feet = {
    CatchLane.upperLeft: Offset(.53, .94),
    CatchLane.lowerLeft: Offset(.53, .94),
    CatchLane.upperRight: Offset(.52, .94),
    CatchLane.lowerRight: Offset(.53, .945),
  };
  static const _bowls = {
    CatchLane.upperLeft: Offset(.268, .126),
    CatchLane.lowerLeft: Offset(.239, .403),
    CatchLane.upperRight: Offset(.772, .121),
    CatchLane.lowerRight: Offset(.809, .419),
  };

  double get catSize {
    // Leave room above the raised bowl for a whole chute, also when large
    // system text reduces the height available to the game board.
    final roomForChutes = (size.height * .96 - size.width * .37 - 18) / .64;
    return math.min(
      math.min(size.width * .80, size.height * .78),
      math.max(48, roomForChutes),
    );
  }

  double get floor => size.height * .96;

  Rect catRect(CatchLane lane) => Rect.fromLTWH(
    size.width / 2 - _feet[lane]!.dx * catSize,
    floor - _feet[lane]!.dy * catSize,
    catSize,
    catSize,
  );

  Offset bowl(CatchLane lane) {
    final rect = catRect(lane);
    return rect.topLeft + _bowls[lane]! * catSize;
  }

  Rect chuteRect(CatchLane lane) {
    final target = bowl(lane);
    final width = lane.isLeft
        ? target.dx / .86
        : (size.width - target.dx) / .79;
    final height = width / 1.5;
    return Rect.fromLTWH(
      lane.isLeft ? 0 : size.width - width,
      target.dy - 14 - height * .87,
      width,
      height,
    );
  }

  Offset _onChute(CatchLane lane, Offset relative) {
    final rect = chuteRect(lane);
    return rect.topLeft +
        Offset(relative.dx * rect.width, relative.dy * rect.height);
  }

  Offset foodPosition(CatchLane lane, double progress) {
    final start = _onChute(lane, Offset(lane.isLeft ? .27 : .74, .40));
    final exit = _onChute(lane, Offset(lane.isLeft ? .86 : .21, .87));
    if (progress <= .8) {
      return Offset.lerp(start, exit, (progress / .8).clamp(0, 1))!;
    }
    final drop = ((progress - .8) / .2).clamp(0.0, 1.0);
    return Offset.lerp(exit, bowl(lane), drop * drop)!;
  }
}

class CatchFoodBoard extends StatelessWidget {
  const CatchFoodBoard({super.key, required this.controller});
  final CatchFoodController controller;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final layout = CatchFoodLayout(constraints.biggest);
        final selected = controller.selected;
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                '$catchFoodAssetRoot/pantry_background.webp',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
              for (final lane in CatchLane.values)
                Positioned.fromRect(
                  rect: layout.chuteRect(lane),
                  child: Image.asset(
                    '$catchFoodAssetRoot/chute_${lane.assetName}.webp',
                    fit: BoxFit.fill,
                  ),
                ),
              Positioned.fromRect(
                rect: layout.catRect(selected),
                child: Image.asset(
                  '$catchFoodAssetRoot/cat_catch_${selected.assetName}.webp',
                  key: ValueKey('catch-pose-${selected.assetName}'),
                  gaplessPlayback: true,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              for (final piece in controller.pieces) _food(layout, piece),
              if (controller.lastCatchLane != null &&
                  controller.elapsedUs - controller.lastCatchUs < 260000)
                Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center:
                        layout.bowl(controller.lastCatchLane!) -
                        const Offset(0, 18),
                    width: 82,
                    height: 82,
                  ),
                  child: Image.asset('$catchFoodAssetRoot/catch_sparkle.webp'),
                ),
              if (controller.lastMissLane != null &&
                  controller.elapsedUs - controller.lastMissUs < 420000)
                Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center: Offset(
                      layout.bowl(controller.lastMissLane!).dx,
                      layout.floor - 14,
                    ),
                    width: 64,
                    height: 64,
                  ),
                  child: Image.asset('$catchFoodAssetRoot/food_crumbs.webp'),
                ),
            ],
          ),
        );
      },
    ),
  );

  Widget _food(CatchFoodLayout layout, FoodPiece piece) {
    final progress = piece.progress(
      controller.elapsedUs,
      controller.config.travelMs,
    );
    final point = layout.foodPosition(piece.lane, progress);
    final size = (layout.size.width * .075).clamp(22.0, 34.0);
    return Positioned.fromRect(
      key: ValueKey('food-${piece.id}'),
      rect: Rect.fromCenter(center: point, width: size, height: size),
      child: Transform.rotate(
        angle: piece.kind == FoodKind.spoiled
            ? 0
            : progress * math.pi * (piece.lane.isLeft ? 2 : -2),
        child: Image.asset(
          '$catchFoodAssetRoot/food_${piece.kind == FoodKind.spoiled ? 'spoiled' : 'fish'}.webp',
        ),
      ),
    );
  }
}
