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

/// Child-friendly descriptions of the artifact effects shown in the store.
///
/// These strings are presentation only. They do not enable or calculate the
/// corresponding gameplay mechanics.
const Map<String, String> localArtifactBenefitDescriptions = {
  'saucer': 'Показывает, сколько энергии потребует каждое предстоящее задание.',
  'vial': 'Один раз спасает от непредвиденной сюжетной беды.',
  'tablecloth':
      'Два дня поддерживает сытость не ниже 40 и помогает экономить на еде.',
  'horseshoe': 'Возвращает 10% монет со всех обязательных покупок.',
  'shield':
      'Предупреждает перед опасной сделкой и даёт шанс от неё отказаться.',
  'purse': 'Если оставить к концу дня хотя бы 10 монет, утром добавит ещё 2.',
  'boots':
      'Снижает расход энергии на задания на 10% и открывает четвёртый квест.',
};

String? resolveItemArtwork({String? itemId, String? imageAsset}) {
  final preferred = imageAsset?.trim();
  if (preferred != null && preferred.isNotEmpty) return preferred;
  return itemId == null ? null : localItemArtwork[itemId];
}

String? resolveArtifactBenefitDescription(String itemId) =>
    localArtifactBenefitDescriptions[itemId];
