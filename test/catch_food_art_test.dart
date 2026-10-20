import 'package:andromeda_app/minigames/catch_food/catch_food_entry_card.dart';
import 'package:andromeda_app/minigames/catch_food/catch_food_models.dart';
import 'package:andromeda_app/onboarding/widgets/fur_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every selectable coat has eight distinct bundled mini-game sprites',
    () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final bundled = manifest.listAssets().toSet();
      final coats = furColorOptions
          .map((option) => CatchFoodCoat.fromFur(option.id))
          .toSet();
      expect(coats, CatchFoodCoat.values.toSet());
      final paths = <String>{};
      for (final coat in coats) {
        expect(coat.catAssets, hasLength(8));
        for (final path in coat.catAssets) {
          expect(bundled, contains(path), reason: 'Missing sprite: $path');
          expect(
            paths.add(path),
            isTrue,
            reason: 'Coats share a cat sprite: $path',
          );
        }
      }
      expect(paths, hasLength(24));
    },
  );

  test('missing or unknown fur IDs preserve all striped poses', () {
    for (final value in [null, '', 'FUR_UNKNOWN', 'FUR_GRAY']) {
      expect(CatchFoodCoat.fromFur(value), CatchFoodCoat.striped);
      expect(
        CatchFoodCoat.fromFur(value).catAssets,
        CatchFoodCoat.striped.catAssets,
      );
    }
  });

  for (final entry in [
    ('FUR_GRAY', CatchFoodCoat.striped),
    ('FUR_ORANGE', CatchFoodCoat.orange),
    ('FUR_WHITE', CatchFoodCoat.white),
  ]) {
    testWidgets('home entry uses ${entry.$1} without a separate poster', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CatchFoodEntryCard(onTap: () {}, furOptionId: entry.$1),
            ),
          ),
        ),
      );
      final paths = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => (image.image as AssetImage).assetName)
          .toSet();
      expect(paths, contains(entry.$2.catAsset('idle')));
      expect(paths, contains('$catchFoodAssetRoot/pantry_background.webp'));
      expect(paths, isNot(contains('$catchFoodAssetRoot/game_entry.webp')));
    });
  }
}
