/// Local catalog art keyed by the stable backend item id.
///
/// Future bundled product art only needs a new asset and one entry here. A
/// backend-provided `image_asset` still takes precedence when it is present.
const Map<String, String> localItemArtwork = {
  'saucer': 'assets/images/artifacts/saucer.webp',
  'vial': 'assets/images/artifacts/vial.webp',
  'tablecloth': 'assets/images/artifacts/tablecloth.webp',
  'horseshoe': 'assets/images/artifacts/horseshoe.webp',
  'shield': 'assets/images/artifacts/shield.webp',
  'purse': 'assets/images/artifacts/purse.webp',
  'boots': 'assets/images/artifacts/boots.webp',
};

/// Existing shop illustrations keyed by the backend catalog id.
///
/// Keeping this mapping next to the artifact catalog prevents presentation
/// widgets from inventing product ids or duplicating asset knowledge.
const Map<String, String> localPurchaseArtwork = {
  'FOOD_APPLE': 'assets/shop/items/apple.webp',
  'FOOD_CARROT': 'assets/shop/items/carrot.webp',
  'PET_MEAL': 'assets/icons/bowl.webp',
  'TOY_BALL': 'assets/icons/ball.webp',
  'CANDY': 'assets/icons/sweet.webp',
  // Test fixtures use these legacy ids to exercise the same products.
  'food': 'assets/icons/bowl.webp',
  'ball': 'assets/icons/ball.webp',
  'candy': 'assets/icons/sweet.webp',
};

/// Child-friendly descriptions of artifact effects shown in the store.
///
/// Each text states what the server actually does (see useArtifact call
/// sites in backend/src/modules): a card must never promise a bonus the
/// economy does not grant. Change the text together with the rule.
const Map<String, String> localArtifactBenefitDescriptions = {
  'saucer': 'На карте подсказывает, сколько монет принесёт задание.',
  'vial': 'Один раз автоматически отменяет беду с питомцем и лечит его.',
  'tablecloth':
      'Каждое утро поднимает сытость питомца до 40%, если она ниже. '
      'Хватает на четыре дня.',
  'horseshoe': 'Сразу возвращает 10% монет за покупки из раздела «Надо».',
  'shield':
      'Перед опасной сделкой показывает признаки риска и один раз даёт '
      'отменить ошибку.',
  'purse':
      'Если в конце дня осталось хотя бы 10 монет, утром добавляет 2 монеты.',
  'boots': 'Пока надеты, открывают четвёртое задание за день.',
};

String? resolveItemArtwork({String? itemId, String? imageAsset}) {
  final preferred = imageAsset?.trim();
  if (preferred != null && preferred.isNotEmpty) return preferred;
  return itemId == null ? null : localItemArtwork[itemId];
}

String? resolveArtifactBenefitDescription(String itemId) =>
    localArtifactBenefitDescriptions[itemId];

String? resolvePurchaseArtwork(String itemId) => localPurchaseArtwork[itemId];
