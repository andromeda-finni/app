/// Local catalog art keyed by the stable backend item id.
///
/// Future bundled product art only needs a new asset and one entry here. A
/// backend-provided `image_asset` still takes precedence when it is present.
const Map<String, String> localItemArtwork = {
  'saucer': 'assets/images/artifacts/saucer.png',
  'vial': 'assets/images/artifacts/vial.png',
  'tablecloth': 'assets/images/artifacts/tablecloth.png',
  'horseshoe': 'assets/images/artifacts/horseshoe.png',
  'shield': 'assets/images/artifacts/shield.png',
  'purse': 'assets/images/artifacts/purse.png',
  'boots': 'assets/images/artifacts/boots.png',
};

String? resolveItemArtwork({String? itemId, String? imageAsset}) {
  final preferred = imageAsset?.trim();
  if (preferred != null && preferred.isNotEmpty) return preferred;
  return itemId == null ? null : localItemArtwork[itemId];
}
