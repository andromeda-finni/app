import 'goldfish_game_models.dart';

const goldfishDefaultPetName = 'Питомец';
const _root = 'assets/games/goldfish';

abstract final class GoldfishAssets {
  static const goldfish = '$_root/goldfish.webp';
  static const grandma = '$_root/grandma.webp';
  static const grandpa = '$_root/grandpa.webp';
  static const homeBeforePortrait = '$_root/home_before_portrait.webp';
  static const homeAfterPortrait = '$_root/home_after_portrait.webp';
  static const homeBeforeSquare = '$_root/home_before_square.webp';
  static const homeAfterSquare = '$_root/home_after_square.webp';
}

GoldfishOffer _offer(
  String id,
  String name,
  int price,
  String asset, {
  Set<GoldfishCategory> categories = const {},
  bool decorative = false,
}) => GoldfishOffer(
  id: id,
  name: name,
  price: price,
  assetPath: '$_root/$asset',
  categories: categories,
  decorative: decorative,
);

String _displayName(String petName) =>
    petName.trim().isEmpty ? goldfishDefaultPetName : petName.trim();

GoldfishLevelConfig goldfishLevelFor(
  GoldfishLevelId id, {
  required String petName,
}) {
  final name = _displayName(petName);
  return switch (id) {
    GoldfishLevelId.normalOne => GoldfishLevelConfig(
      id: id,
      title: 'Самое необходимое',
      budget: 12,
      taskText: 'Выбери крышу, кровать и окно.',
      hintText: 'Сначала найди по одному предмету из трёх важных категорий: крышу, кровать и окно.',
      learningText: 'Когда денег немного, сначала покупают самое необходимое.',
      offers: [
        _offer(
          'roof_basic',
          'Прочная крыша',
          5,
          'roof_basic.webp',
          categories: const {GoldfishCategory.roof},
        ),
        _offer(
          'roof_ornate',
          'Расписная крыша',
          8,
          'roof_ornate.webp',
          categories: const {GoldfishCategory.roof},
          decorative: true,
        ),
        _offer(
          'bed_basic',
          'Простая кровать',
          4,
          'bed_basic.webp',
          categories: const {GoldfishCategory.bed},
        ),
        _offer(
          'bed_ornate',
          'Резная кровать',
          7,
          'bed_ornate.webp',
          categories: const {GoldfishCategory.bed},
          decorative: true,
        ),
        _offer(
          'window_basic',
          'Деревянное окно',
          3,
          'window_basic.webp',
          categories: const {GoldfishCategory.window},
        ),
        _offer(
          'window_ornate',
          'Расписное окно',
          6,
          'window_ornate.webp',
          categories: const {GoldfishCategory.window},
          decorative: true,
        ),
      ],
      requirements: const [
        GoldfishRequirement(
          label: 'крыша',
          acceptedItemIds: {'roof_basic', 'roof_ornate'},
        ),
        GoldfishRequirement(
          label: 'кровать',
          acceptedItemIds: {'bed_basic', 'bed_ornate'},
        ),
        GoldfishRequirement(
          label: 'окно',
          acceptedItemIds: {'window_basic', 'window_ornate'},
        ),
      ],
      introLines: [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Привет, $name! Посмотри, нашему домику срочно нужен ремонт.',
        ),
        const GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Нам нужна новая крыша, кровать и окно.',
        ),
        const GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Я подарила вам 12 монет. Но сначала нужно выбрать самое необходимое.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text:
              '$name, пожалуйста, помоги нам купить всё нужное и уложиться в бюджет!',
        ),
      ],
      successLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Теперь крыша не протекает, спать удобно и в доме снова есть окно!',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'Даже ни одной лишней монеты не потратили.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Ты сначала выбрал необходимое и правильно распределил деньги. Молодец!',
        ),
      ],
      missingLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Очень красиво получилось, но для домика чего-то важного не хватает.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Сначала купи всё необходимое, а потом выбирай украшения.',
        ),
      ],
      budgetLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'Ой! У нас столько монет нет.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Сравни цены и попробуй ещё раз.',
        ),
      ],
    ),
    GoldfishLevelId.normalTwo => GoldfishLevelConfig(
      id: id,
      title: 'Готовимся к холодам',
      budget: 14,
      taskText: 'Подготовь домик к зиме.',
      hintText: 'Нужны крыша, окно и тёплая вещь. Желание можно купить только после важных вещей.',
      learningText: 'Если после важных покупок остались деньги, часть можно потратить на то, что хочется.',
      offers: [
        _offer(
          'roof_basic',
          'Прочная крыша',
          5,
          'roof_basic.webp',
          categories: const {GoldfishCategory.roof},
        ),
        _offer(
          'roof_ornate',
          'Нарядная крыша',
          8,
          'roof_ornate.webp',
          categories: const {GoldfishCategory.roof},
          decorative: true,
        ),
        _offer(
          'blanket_down',
          'Пуховое одеяло',
          4,
          'blanket_down.webp',
          categories: const {GoldfishCategory.warmth},
        ),
        _offer(
          'cover_silk',
          'Шёлковое покрывало',
          7,
          'cover_silk.webp',
          categories: const {GoldfishCategory.desire},
          decorative: true,
        ),
        _offer(
          'window_basic',
          'Деревянное окно',
          3,
          'window_basic.webp',
          categories: const {GoldfishCategory.window},
        ),
        _offer(
          'window_ornate',
          'Расписное окно',
          5,
          'window_ornate.webp',
          categories: const {GoldfishCategory.window},
          decorative: true,
        ),
        _offer(
          'lollipop',
          'Большой леденец',
          2,
          'lollipop.webp',
          categories: const {GoldfishCategory.desire},
          decorative: true,
        ),
        _offer(
          'vase_basic',
          'Декоративная ваза',
          3,
          'vase_basic.webp',
          categories: const {GoldfishCategory.desire},
          decorative: true,
        ),
      ],
      requirements: const [
        GoldfishRequirement(
          label: 'крыша',
          acceptedItemIds: {'roof_basic', 'roof_ornate'},
        ),
        GoldfishRequirement(
          label: 'тёплая вещь',
          acceptedItemIds: {'blanket_down'},
        ),
        GoldfishRequirement(
          label: 'окно',
          acceptedItemIds: {'window_basic', 'window_ornate'},
        ),
      ],
      introLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Скоро зима! Помоги нам подготовить домик к холодам.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'Нужны тёплое одеяло, хорошая крыша и окно, чтобы ветер не задувал.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'У вас есть 14 монет. Сначала выбери важные вещи, а затем проверь остаток.',
        ),
      ],
      successLines: [
        const GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Теперь зимой нам будет тепло!',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'На всё необходимое хватило монет. Спасибо, $name!',
        ),
      ],
      missingLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Покупки красивые, но они не помогут полностью подготовиться к холоду.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Посмотри, какая обязательная вещь ещё не выбрана.',
        ),
      ],
      budgetLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'На все эти товары монет не хватает.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Сравни цены и замени дорогой вариант более доступным.',
        ),
      ],
    ),
    GoldfishLevelId.hardOne => GoldfishLevelConfig(
      id: id,
      title: 'Красиво или разумно?',
      budget: 17,
      taskText: 'Закрой четыре потребности и сравни варианты.',
      hintText: 'Проверь четыре категории: крыша, кровать, окно и тёплая вещь. Правильных наборов несколько.',
      learningText: 'Разумная покупка не всегда самая дешёвая. Главное, чтобы денег хватило на всё необходимое.',
      offers: [
        _offer(
          'roof_basic',
          'Прочная крыша',
          5,
          'roof_basic.webp',
          categories: const {GoldfishCategory.roof},
        ),
        _offer(
          'roof_ornate',
          'Расписная крыша',
          7,
          'roof_ornate.webp',
          categories: const {GoldfishCategory.roof},
          decorative: true,
        ),
        _offer(
          'bed_basic',
          'Простая кровать',
          4,
          'bed_basic.webp',
          categories: const {GoldfishCategory.bed},
        ),
        _offer(
          'bed_ornate',
          'Резная кровать',
          6,
          'bed_ornate.webp',
          categories: const {GoldfishCategory.bed},
          decorative: true,
        ),
        _offer(
          'window_basic',
          'Деревянное окно',
          3,
          'window_basic.webp',
          categories: const {GoldfishCategory.window},
        ),
        _offer(
          'window_ornate',
          'Расписное окно',
          5,
          'window_ornate.webp',
          categories: const {GoldfishCategory.window},
          decorative: true,
        ),
        _offer(
          'blanket_down',
          'Пуховое одеяло',
          3,
          'blanket_down.webp',
          categories: const {GoldfishCategory.warmth},
        ),
        _offer(
          'blanket_ornate',
          'Нарядное одеяло',
          5,
          'blanket_ornate.webp',
          categories: const {GoldfishCategory.warmth},
          decorative: true,
        ),
        _offer(
          'frame_gold',
          'Золотая рамка',
          3,
          'frame_gold.webp',
          categories: const {GoldfishCategory.desire},
          decorative: true,
        ),
        _offer(
          'vase_basic',
          'Ваза',
          2,
          'vase_basic.webp',
          categories: const {GoldfishCategory.desire},
          decorative: true,
        ),
      ],
      requirements: const [
        GoldfishRequirement(
          label: 'крыша',
          acceptedItemIds: {'roof_basic', 'roof_ornate'},
        ),
        GoldfishRequirement(
          label: 'кровать',
          acceptedItemIds: {'bed_basic', 'bed_ornate'},
        ),
        GoldfishRequirement(
          label: 'окно',
          acceptedItemIds: {'window_basic', 'window_ornate'},
        ),
        GoldfishRequirement(
          label: 'тёплая вещь',
          acceptedItemIds: {'blanket_down', 'blanket_ornate'},
        ),
      ],
      introLines: [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text:
              'Привет, $name! Помоги Бабушке и Дедушке подготовить домик к холодам.',
        ),
        const GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Нам нужны кровать, крыша, окно и тёплое одеяло.',
        ),
        const GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'Можно купить и красивые вещи, но у нас всего 17 монет.',
        ),
        const GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Сравни цены: на чём-то можно сэкономить, а одну вещь выбрать понаряднее.',
        ),
      ],
      successLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'Всё нужное куплено!',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'И даже одну вещь удалось выбрать понаряднее.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Отличное решение. Главное, что денег хватило на всё необходимое.',
        ),
      ],
      missingLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Похоже, одной важной вещи для дома всё ещё нет.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Проверь четыре обязательные категории и измени покупки.',
        ),
      ],
      budgetLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Каждая вещь хороша сама по себе, но вместе они стоят слишком дорого.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'Попробуй заменить что-нибудь на более простой вариант.',
        ),
      ],
    ),
    GoldfishLevelId.hardTwo => GoldfishLevelConfig(
      id: id,
      title: 'Домик и запас на зиму',
      budget: 20,
      minimumReserve: 3,
      taskText: 'Купи нужное и оставь не меньше 3 монет.',
      hintText: 'На покупки можно потратить не больше 17 монет. Нужны крыша, кровать, окно и тёплая вещь.',
      learningText: 'Не всегда нужно тратить все деньги сразу. Часть полезно оставить в запасе.',
      offers: [
        _offer(
          'bed_basic',
          'Простая кровать',
          4,
          'bed_basic.webp',
          categories: const {GoldfishCategory.bed},
        ),
        _offer(
          'bed_ornate',
          'Резная кровать',
          7,
          'bed_ornate.webp',
          categories: const {GoldfishCategory.bed},
          decorative: true,
        ),
        _offer(
          'roof_basic',
          'Прочная крыша',
          4,
          'roof_basic.webp',
          categories: const {GoldfishCategory.roof},
        ),
        _offer(
          'roof_ornate',
          'Расписная крыша',
          7,
          'roof_ornate.webp',
          categories: const {GoldfishCategory.roof},
          decorative: true,
        ),
        _offer(
          'window_basic',
          'Простое окно',
          3,
          'window_basic.webp',
          categories: const {GoldfishCategory.window},
        ),
        _offer(
          'window_ornate',
          'Расписное окно',
          5,
          'window_ornate.webp',
          categories: const {GoldfishCategory.window},
          decorative: true,
        ),
        _offer(
          'shawl_down',
          'Пуховый платок',
          3,
          'shawl_down.webp',
          categories: const {GoldfishCategory.warmth},
        ),
        _offer(
          'shawl_ornate',
          'Нарядный платок',
          5,
          'shawl_ornate.webp',
          categories: const {GoldfishCategory.warmth},
          decorative: true,
        ),
        _offer(
          'lamp',
          'Лампа',
          3,
          'lamp.webp',
          categories: const {GoldfishCategory.extra},
        ),
        _offer(
          'music_box',
          'Музыкальная шкатулка',
          5,
          'music_box.webp',
          categories: const {GoldfishCategory.desire},
          decorative: true,
        ),
        _offer(
          'vase_gold',
          'Золотая ваза',
          6,
          'vase_gold.webp',
          categories: const {GoldfishCategory.desire},
          decorative: true,
        ),
      ],
      requirements: const [
        GoldfishRequirement(
          label: 'крыша',
          acceptedItemIds: {'roof_basic', 'roof_ornate'},
        ),
        GoldfishRequirement(
          label: 'кровать',
          acceptedItemIds: {'bed_basic', 'bed_ornate'},
        ),
        GoldfishRequirement(
          label: 'окно',
          acceptedItemIds: {'window_basic', 'window_ornate'},
        ),
        GoldfishRequirement(
          label: 'тёплая вещь',
          acceptedItemIds: {'shawl_down', 'shawl_ornate'},
        ),
      ],
      introLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Золотая рыбка дала нам 20 монет. Впереди зима, и дому нужны важные вещи.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'Не хочется потратить всё сразу. Вдруг потом понадобятся дрова или еда?',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'Купи всё необходимое и постарайся оставить хотя бы 3 монеты в запасе.',
        ),
      ],
      successLines: [
        const GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Теперь дома тепло и уютно.',
        ),
        const GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'И три монеты ещё остались на случай, если зимой что-нибудь понадобится.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text:
              'Ты сделал покупки и оставил деньги в запасе. Отличная работа, $name!',
        ),
      ],
      missingLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandma,
          text: 'Для дома всё ещё не хватает одной необходимой вещи.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Сначала закрой все обязательные потребности, а затем проверь остаток.',
        ),
      ],
      budgetLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'На все выбранные вещи монет не хватает.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Замени дорогую покупку более доступной.',
        ),
      ],
      reserveLines: const [
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.grandpa,
          text: 'Всё нужное мы купили, но в запасе осталось меньше трёх монет.',
        ),
        GoldfishStoryLine(
          speaker: GoldfishSpeaker.goldfish,
          text: 'Замени одну покупку более дешёвой, чтобы сохранить хотя бы 3 монеты.',
        ),
      ],
    ),
  };
}
