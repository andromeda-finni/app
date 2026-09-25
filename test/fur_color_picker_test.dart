import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/core/pet_assets.dart';
import 'package:andromeda_app/onboarding/widgets/fur_color_picker.dart';

void main() {
  test('step 1 previews the exact grey cat before a colour is selected', () {
    expect(catAssetForFur(null), kBaseCatAsset);
    expect(kBaseCatAsset, furColorOptions.first.catAsset);

    for (final option in furColorOptions) {
      expect(catAssetForFur(option.id), contains('/base/'));
    }
  });
}
