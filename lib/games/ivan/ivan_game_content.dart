import 'ivan_game_models.dart';

const ivanDefaultPetName = 'Питомец';
const _root = 'assets/games/ivan';

abstract final class IvanAssets {
  static const ivan = '$_root/ivan.webp';
  static const stall = '$_root/stall.webp';
  static const backpack = '$_root/backpack.webp';
  static const shopBackground = 'assets/backgrounds/shop.webp';
}

abstract final class IvanCatalog {
  static const pies = IvanItem(
    id: 'pies',
    name: 'Пирожки',
    price: 3,
    assetPath: '$_root/pies.webp',
    categories: {IvanItemCategory.food},
  );
  static const warmShirtEasy = IvanItem(
    id: 'warm_shirt_easy',
    name: 'Тёплая рубаха',
    price: 4,
    assetPath: '$_root/warm_shirt.webp',
    categories: {IvanItemCategory.warmth},
  );
  static const warmShirtHard = IvanItem(
    id: 'warm_shirt_hard',
    name: 'Тёплая рубаха',
    price: 5,
    assetPath: '$_root/warm_shirt.webp',
    categories: {IvanItemCategory.warmth},
  );
  static const warmShirtFinal = IvanItem(
    id: 'warm_shirt_final',
    name: 'Тёплая рубаха',
    price: 4,
    assetPath: '$_root/warm_shirt.webp',
    categories: {IvanItemCategory.warmth},
  );
  static const map = IvanItem(
    id: 'map',
    name: 'Карта',
    price: 2,
    assetPath: '$_root/map.webp',
    categories: {IvanItemCategory.navigation},
  );
  static const mapHard = IvanItem(
    id: 'map_hard',
    name: 'Карта',
    price: 3,
    assetPath: '$_root/map.webp',
    categories: {IvanItemCategory.navigation},
  );
  static const magicMap = IvanItem(
    id: 'magic_map',
    name: 'Волшебная карта',
    price: 5,
    assetPath: '$_root/magic_map.webp',
    categories: {IvanItemCategory.navigation},
    isMagic: true,
  );
  static const rope = IvanItem(
    id: 'rope',
    name: 'Верёвка',
    price: 2,
    assetPath: '$_root/rope.webp',
    categories: {IvanItemCategory.traversal},
  );
  static const lollipopEasy = IvanItem(
    id: 'lollipop_easy',
    name: 'Леденец',
    price: 2,
    assetPath: '$_root/lollipop.webp',
  );
  static const lollipopFinal = IvanItem(
    id: 'lollipop_final',
    name: 'Леденец',
    price: 1,
    assetPath: '$_root/lollipop.webp',
  );
  static const goblet = IvanItem(
    id: 'golden_goblet',
    name: 'Золотой кубок',
    price: 5,
    assetPath: '$_root/golden_goblet.webp',
  );
  static const breadCheese = IvanItem(
    id: 'bread_cheese',
    name: 'Хлеб и сыр',
    price: 3,
    assetPath: '$_root/bread_cheese.webp',
    categories: {IvanItemCategory.food},
  );
  static const warmCloak = IvanItem(
    id: 'warm_cloak',
    name: 'Тёплый плащ',
    price: 5,
    assetPath: '$_root/warm_cloak.webp',
    categories: {IvanItemCategory.warmth},
  );
  static const candle = IvanItem(
    id: 'candle',
    name: 'Свечка',
    price: 2,
    assetPath: '$_root/candle.webp',
    categories: {IvanItemCategory.light},
  );
  static const flask = IvanItem(
    id: 'flask',
    name: 'Фляга с водой',
    price: 2,
    assetPath: '$_root/flask.webp',
    categories: {IvanItemCategory.water},
  );
  static const toyHorse = IvanItem(
    id: 'toy_horse',
    name: 'Игрушечный конь',
    price: 4,
    assetPath: '$_root/toy_horse.webp',
  );
  static const musicBox = IvanItem(
    id: 'music_box',
    name: 'Музыкальная шкатулка',
    price: 5,
    assetPath: '$_root/music_box.webp',
  );
  static const simpleBoots = IvanItem(
    id: 'simple_boots',
    name: 'Простые сапоги',
    price: 3,
    assetPath: '$_root/simple_boots.webp',
    categories: {IvanItemCategory.traversal},
  );
  static const sturdyBoots = IvanItem(
    id: 'sturdy_boots',
    name: 'Крепкие сапоги',
    price: 4,
    assetPath: '$_root/simple_boots.webp',
    categories: {IvanItemCategory.traversal},
  );
  static const speedBoots = IvanItem(
    id: 'speed_boots',
    name: 'Сапоги-скороходы',
    price: 7,
    assetPath: '$_root/speed_boots.webp',
    categories: {IvanItemCategory.traversal},
    isMagic: true,
  );
  static const magicWand = IvanItem(
    id: 'magic_wand',
    name: 'Волшебная палочка',
    price: 8,
    assetPath: '$_root/magic_wand.webp',
    isMagic: true,
  );
  static const lantern = IvanItem(
    id: 'lantern',
    name: 'Фонарь',
    price: 4,
    assetPath: '$_root/lantern.webp',
    categories: {IvanItemCategory.light},
  );
  static const firebirdFeather = IvanItem(
    id: 'firebird_feather',
    name: 'Перо Жар-птицы',
    price: 5,
    assetPath: '$_root/firebird_feather.webp',
    isMagic: true,
  );
}

String _displayName(String petName) =>
    petName.trim().isEmpty ? ivanDefaultPetName : petName.trim();

IvanLevelConfig ivanLevelFor(IvanLevelId id, {required String petName}) {
  final name = _displayName(petName);
  return switch (id) {
    IvanLevelId.easyOne => IvanLevelConfig(
      id: id,
      title: 'Первые сборы',
      budget: 10,
      taskText: 'Сначала выбери еду и тёплую одежду.',
      hintText: 'В дороге Иван проголодается и может замёрзнуть. Найди пирожки и тёплую рубаху.',
      successText:
          'Отлично! Еда и тёплая одежда собраны, а бюджет не превышен.',
      items: const [
        IvanCatalog.pies,
        IvanCatalog.warmShirtEasy,
        IvanCatalog.map,
        IvanCatalog.rope,
        IvanCatalog.lollipopEasy,
        IvanCatalog.goblet,
      ],
      requirements: const [
        IvanRequirement(label: 'еда', acceptedItemIds: {'pies'}),
        IvanRequirement(
          label: 'тёплая одежда',
          acceptedItemIds: {'warm_shirt_easy'},
        ),
      ],
      introLines: [
        IvanStoryLine(
          speaker: 'Иван-царевич',
          text:
              'Привет, $name! Я Иван-царевич. Собираюсь в путь-дорогу и буду рад твоей помощи.',
        ),
        const IvanStoryLine(
          speaker: 'Иван-царевич',
          text: 'Мне нужны еда и что-нибудь тёплое. Монет немного, поэтому сначала выберем самое необходимое.',
        ),
      ],
    ),
    IvanLevelId.easyTwo => IvanLevelConfig(
      id: id,
      title: 'Долгая дорога',
      budget: 12,
      taskText: 'Собери всё необходимое для долгой дороги.',
      hintText: 'Проверь четыре вещи: еду, тёплый плащ, воду и свечку для вечернего света.',
      successText: 'Теперь у Ивана есть еда, вода, тёплый плащ и свечка. Все покупки полезны.',
      items: const [
        IvanCatalog.breadCheese,
        IvanCatalog.warmCloak,
        IvanCatalog.candle,
        IvanCatalog.flask,
        IvanCatalog.toyHorse,
        IvanCatalog.musicBox,
      ],
      requirements: const [
        IvanRequirement(label: 'еда', acceptedItemIds: {'bread_cheese'}),
        IvanRequirement(
          label: 'тёплая одежда',
          acceptedItemIds: {'warm_cloak'},
        ),
        IvanRequirement(label: 'вода', acceptedItemIds: {'flask'}),
        IvanRequirement(label: 'свечка', acceptedItemIds: {'candle'}),
      ],
      introLines: const [
        IvanStoryLine(
          speaker: 'Иван-царевич',
          text: 'На этот раз путь будет дольше. Нужно заранее подумать, что пригодится днём и вечером.',
        ),
        IvanStoryLine(
          speaker: 'Иван-царевич',
          text: 'Помоги собрать еду, воду, тёплую одежду и источник света, не выходя за бюджет.',
        ),
      ],
    ),
    IvanLevelId.hardOne => IvanLevelConfig(
      id: id,
      title: 'Самостоятельные сборы',
      budget: 14,
      taskText: 'Выбери обязательные вещи и разумно распредели остаток.',
      hintText: 'Без еды, воды и тёплой рубахи отправляться нельзя. Остальное сравни по пользе и цене.',
      successText: 'Всё необходимое собрано. Ты внимательно сравнил покупки и уложился в бюджет.',
      items: const [
        IvanCatalog.pies,
        IvanCatalog.warmShirtHard,
        IvanCatalog.flask,
        IvanCatalog.mapHard,
        IvanCatalog.candle,
        IvanCatalog.rope,
        IvanCatalog.sturdyBoots,
        IvanCatalog.magicWand,
        IvanCatalog.goblet,
      ],
      requirements: const [
        IvanRequirement(label: 'еда', acceptedItemIds: {'pies'}),
        IvanRequirement(
          label: 'тёплая одежда',
          acceptedItemIds: {'warm_shirt_hard'},
        ),
        IvanRequirement(label: 'вода', acceptedItemIds: {'flask'}),
      ],
      introLines: [
        IvanStoryLine(
          speaker: 'Иван-царевич',
          text:
              'Привет, $name! Я Иван-царевич. Впереди серьёзное путешествие, и мне нужен внимательный советчик.',
        ),
        const IvanStoryLine(
          speaker: 'Иван-царевич',
          text: 'Сначала найди еду, воду и тёплую одежду. Затем реши, стоит ли брать что-нибудь ещё.',
        ),
      ],
    ),
    IvanLevelId.hardTwo => IvanLevelConfig(
      id: id,
      title: 'Путь через горы',
      budget: 15,
      taskText: 'Сравни обычные и волшебные вещи и собери всё для пути.',
      hintText: 'Нужны еда, вода, тепло, карта и вещь для трудного участка пути. Дорогая не всегда значит необходимая.',
      successText: 'Маршрут продуман: есть припасы, тепло, карта и помощь для трудного пути.',
      items: const [
        IvanCatalog.pies,
        IvanCatalog.warmShirtFinal,
        IvanCatalog.flask,
        IvanCatalog.simpleBoots,
        IvanCatalog.speedBoots,
        IvanCatalog.map,
        IvanCatalog.magicMap,
        IvanCatalog.candle,
        IvanCatalog.lantern,
        IvanCatalog.rope,
        IvanCatalog.lollipopFinal,
        IvanCatalog.firebirdFeather,
      ],
      requirements: const [
        IvanRequirement(label: 'еда', acceptedItemIds: {'pies'}),
        IvanRequirement(
          label: 'тёплая одежда',
          acceptedItemIds: {'warm_shirt_final'},
        ),
        IvanRequirement(label: 'вода', acceptedItemIds: {'flask'}),
        IvanRequirement(label: 'карта', acceptedItemIds: {'map', 'magic_map'}),
        IvanRequirement(
          label: 'вещь для трудного пути',
          acceptedItemIds: {'rope', 'simple_boots', 'speed_boots'},
        ),
      ],
      introLines: const [
        IvanStoryLine(
          speaker: 'Иван-царевич',
          text: 'Впереди незнакомая дорога и высокие горы. На прилавке есть обычные и волшебные товары.',
        ),
        IvanStoryLine(
          speaker: 'Иван-царевич',
          text: 'Сравни их цены и пользу. Мне нужны припасы, тепло, карта и вещь, которая поможет пройти трудный участок.',
        ),
      ],
    ),
  };
}

const ivanLearningText =
    'Сначала выбирай необходимое, затем сравнивай цены. Оставшиеся монеты необязательно тратить — их можно сохранить.';
