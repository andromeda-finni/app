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

/// Child-friendly descriptions of artifact effects shown in the store.
///
/// Only effects the server actually applies belong here: a card must never
/// promise a bonus the economy does not grant. Add an entry together with the
/// backend rule that implements it.
const Map<String, String> localArtifactBenefitDescriptions = {
  // quests/routes.ts raises the daily paid-quest limit while boots are worn.
  'boots': 'Пока надеты, открывают четвёртое задание за день.',
};

String? resolveItemArtwork({String? itemId, String? imageAsset}) {
  final preferred = imageAsset?.trim();
  if (preferred != null && preferred.isNotEmpty) return preferred;
  return itemId == null ? null : localItemArtwork[itemId];
}

String? resolveArtifactBenefitDescription(String itemId) =>
    localArtifactBenefitDescriptions[itemId];
