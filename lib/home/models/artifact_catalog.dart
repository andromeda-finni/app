class ArtifactDefinition {
  const ArtifactDefinition({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.rarity,
    required this.ability,
    required this.wearable,
  });

  final String id;
  final String name;
  final String assetPath;
  final String rarity;
  final String ability;
  final bool wearable;
}

const artifactCatalog = <ArtifactDefinition>[
  ArtifactDefinition(
    id: 'shield',
    name: 'Богатырский щит',
    assetPath: 'assets/artifacts/items/01-bogatyr-shield.png',
    rarity: 'EPIC',
    ability: 'Отражает аферы и ошибочные импульсивные сделки.',
    wearable: true,
  ),
  ArtifactDefinition(
    id: 'boots',
    name: 'Сапоги-скороходы',
    assetPath: 'assets/artifacts/items/02-speed-boots.png',
    rarity: 'LEGENDARY',
    ability: 'Открывают четвёртый слот заданий на карте.',
    wearable: true,
  ),
  ArtifactDefinition(
    id: 'purse',
    name: 'Кошель-самотряс',
    assetPath: 'assets/artifacts/items/03-magic-purse.png',
    rarity: 'LEGENDARY',
    ability: 'Даёт 2 бонусные монеты утром, если сохранён остаток от 10.',
    wearable: true,
  ),
  ArtifactDefinition(
    id: 'tablecloth',
    name: 'Скатерть-самобранка',
    assetPath: 'assets/artifacts/items/04-magic-tablecloth.png',
    rarity: 'EPIC',
    ability: 'Удерживает сытость не ниже 40 в течение четырёх активных дней.',
    wearable: false,
  ),
  ArtifactDefinition(
    id: 'saucer',
    name: 'Серебряное блюдечко',
    assetPath: 'assets/artifacts/items/05-silver-saucer-apple.png',
    rarity: 'RARE',
    ability: 'Открывает точный прогноз выгоды заданий.',
    wearable: false,
  ),
  ArtifactDefinition(
    id: 'vial',
    name: 'Склянка с живой водой',
    assetPath: 'assets/artifacts/items/06-living-water-vial.png',
    rarity: 'RARE',
    ability: 'Один раз автоматически отменяет форс-мажор и восстанавливает здоровье.',
    wearable: false,
  ),
  ArtifactDefinition(
    id: 'horseshoe',
    name: 'Золотая подкова',
    assetPath: 'assets/artifacts/items/07-golden-horseshoe.png',
    rarity: 'EPIC',
    ability: 'Возвращает 10% от покупок категории «Надо».',
    wearable: false,
  ),
];

String canonicalArtifactId(String value) {
  final id = value.toLowerCase();
  for (final definition in artifactCatalog) {
    if (id == definition.id || id.endsWith('_${definition.id}')) {
      return definition.id;
    }
  }
  return id;
}

ArtifactDefinition? artifactDefinition(String itemId) {
  final id = canonicalArtifactId(itemId);
  for (final definition in artifactCatalog) {
    if (definition.id == id) return definition;
  }
  return null;
}
