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
/// These describe the designed bonuses so a child can understand the value of
/// a dream before choosing it. Some bonuses are still catalog-only and must be
/// wired to the backend separately before they affect gameplay.
const Map<String, String> localArtifactBenefitDescriptions = {
  'saucer': 'Перед заданием показывает, сколько энергии потратит питомец.',
  'vial': 'Один раз автоматически отменяет негативное событие.',
  'tablecloth': 'Два дня не даёт сытости питомца опуститься ниже 40%.',
  'horseshoe':
      'На следующее утро возвращает 10% монет за обязательные покупки.',
  'shield':
      'Перед опасной сделкой показывает признаки риска и один раз даёт '
      'отменить ошибку.',
  'purse':
      'Если в конце дня осталось хотя бы 10 монет, утром добавляет 2 монеты.',
  'boots':
      'Снижает расход энергии на задания на 10% и открывает четвёртое '
      'задание за день.',
};

String? resolveItemArtwork({String? itemId, String? imageAsset}) {
  final preferred = imageAsset?.trim();
  if (preferred != null && preferred.isNotEmpty) return preferred;
  return itemId == null ? null : localItemArtwork[itemId];
}

String? resolveArtifactBenefitDescription(String itemId) =>
    localArtifactBenefitDescriptions[itemId];
