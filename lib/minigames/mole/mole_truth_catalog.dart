import 'dart:math';

import 'mole_truth_models.dart';
import 'mole_game_data.dart';

MoleTruthLine _plain(String id, String text, {String? value}) =>
    MoleTruthLine([MoleTruthSpan(id: id, printed: text, value: value)]);

MoleTruthLine _trick(
  String id,
  String printed,
  String truth,
  String explanation,
  MoleTruthKind kind, {
  String? value,
  String? truthValue,
}) => MoleTruthLine([
  MoleTruthSpan(
    id: id,
    printed: printed,
    truth: truth,
    explanation: explanation,
    kind: kind,
    value: value,
    truthValue: truthValue,
  ),
]);

/// Five compatible lesson families, four authored parameter sets each.
/// Prices and clauses are generated together, rather than shuffled separately.
final List<MoleTruthCase> moleTruthCatalog = List.unmodifiable([
  for (final (variant, item, price, shipping) in [
    (0, 'Мешок зерна', 8, 4),
    (1, 'Походный фонарь', 7, 5),
    (2, 'Моток верёвки', 9, 3),
    (3, 'Тёплый плед', 6, 6),
  ])
    MoleTruthCase(
      id: 'delivery-$variant',
      stepNo: 1,
      title: 'Доставка с довеском',
      documentTitle: 'Счёт за доставку',
      intro: '$item — $price, доставка — $shipping. Других услуг я не просил.',
      purchaseAssets: [
        [
          MoleAssets.grain,
          MoleAssets.lantern,
          MoleAssets.rope,
          MoleAssets.blanket,
        ][variant],
      ],
      agreement:
          '$item стоит ${moleCoinAmount(price)}. За доставку договорились отдать ${moleCoinAmount(shipping)}. Других услуг не заказывали.',
      lines: [
        _plain('buyer', 'Покупатель: Земелик'),
        _plain('item', item, value: '$price'),
        _trick(
          'delivery',
          'Доставка и сервис',
          'Доставка + лишний сбор',
          'Доставку посчитали дважды. По договорённости оплачивается только один сбор — ${moleCoinAmount(shipping)}.',
          MoleTruthKind.extraCharge,
          value: '${shipping * 2}',
          truthValue: '$shipping + $shipping',
        ),
        _plain('bill', 'ИТОГО', value: '${12 + shipping}'),
      ],
      billedTotal: 12 + shipping,
      fairTotal: price + shipping,
      serverAnswerCode: '12',
      verdictLabel: 'Оспорить лишний сбор',
      sellerReply: 'Ты прав: доставку я посчитал два раза. Убираю повторный сбор. Новый счёт — 12 монет.',
      lesson: 'Полная цена = товар + согласованная доставка.',
      hint: 'Сравни договорённость о доставке со строкой «Доставка и сервис».',
    ),
  for (final (variant, item, discount, count) in [
    (0, 'Фонарь', 6, 2),
    (1, 'Верёвка', 5, 3),
    (2, 'Плед', 7, 2),
    (3, 'Ключ', 4, 3),
  ])
    MoleTruthCase(
      id: 'offer-$variant',
      stepNo: 2,
      title: 'Скидка с условием',
      documentTitle: '$item по акции',
      intro:
          'Мне нужна одна вещь. Без акции она стоит 9 монет. Проверь скидку.',
      documentKind: MoleTruthDocumentKind.advertisement,
      purchaseAssets: [
        [
          MoleAssets.lantern,
          MoleAssets.rope,
          MoleAssets.blanket,
          MoleAssets.key,
        ][variant],
      ],
      agreement: 'Земелику нужен один товар. Обычная цена — 9 монет. Несколько вещей он брать не собирался.',
      lines: [
        _plain('item', 'Специальное предложение'),
        _trick(
          'price',
          '${moleCoinAmount(discount)} за штуку',
          '${moleCoinAmount(discount)} — только от $count шт.',
          'Скидка действует на набор из $count вещей. Цена одной без набора — 9 монет.',
          MoleTruthKind.condition,
        ),
        _plain('ordinary', 'Одна вещь без акции — 9 монет'),
        _trick(
          'quantity',
          'Выгодный набор для тебя',
          'За $count шт. заплатишь ${moleCoinAmount(discount * count)}',
          'Низкая цена за штуку не делает ненужный набор выгодным. Покупателю нужна одна вещь.',
          MoleTruthKind.substitution,
        ),
      ],
      billedTotal: discount * count,
      fairTotal: 9,
      serverAnswerCode: '9',
      verdictLabel: 'Попросить одну вещь',
      sellerReply: 'Условие акции стоило написать яснее. Убираю лишние вещи: одна стоит 9 монет.',
      lesson: 'Сравнивай полную стоимость с тем, что тебе нужно.',
      hint: 'Сколько вещей нужно Земелику и сколько вещей включили в набор?',
    ),
  for (final (variant, item, price, fee, service) in [
    (0, 'Фонарь', 11, 3, 'Упаковка'),
    (1, 'Мешок зерна', 13, 4, 'Страховка'),
    (2, 'Верёвка', 8, 2, 'Сервис'),
    (3, 'Плед', 16, 5, 'Доставка'),
  ])
    MoleTruthCase(
      id: 'gift-$variant',
      stepNo: 3,
      title: 'Подарок попал в счёт',
      documentTitle: 'Чек постоянного клиента',
      intro: '$item — $price монет. «$service» обещали бесплатно. Проверь чек.',
      purchaseAssets: [
        [
          MoleAssets.lantern,
          MoleAssets.grain,
          MoleAssets.rope,
          MoleAssets.blanket,
        ][variant],
      ],
      agreement:
          'Купили только «$item» за ${moleCoinAmount(price)}. Продавец предложил услугу «$service» бесплатно.',
      lines: [
        _plain('item', item, value: '$price'),
        _trick(
          'gift',
          '$service в подарок',
          'Платная услуга: $service',
          'Обещанный подарок оказался платным. Эти ${moleCoinAmount(fee)} не входят в согласованную покупку.',
          MoleTruthKind.extraCharge,
          value: '0',
          truthValue: '$fee',
        ),
        _plain('bill', 'ИТОГО', value: '${price + fee}'),
      ],
      billedTotal: price + fee,
      fairTotal: price,
      serverAnswerCode: 'ask',
      verdictLabel: 'Оспорить чек',
      sellerReply:
          'Да, подарок должен быть бесплатным. Убираю платную строку и выдаю новый чек на ${moleCoinAmount(price)}.',
      lesson: 'Проверяй, не включили ли «бесплатное» в общую сумму.',
      hint: 'Сложи стоимость покупки и сравни её с итогом. Откуда взялась разница?',
    ),
  for (final (variant, lantern, candle, grain) in [
    (0, 6, 2, 9),
    (1, 5, 4, 8),
    (2, 7, 3, 7),
    (3, 8, 3, 6),
  ])
    MoleTruthCase(
      id: 'arithmetic-$variant',
      stepNo: 4,
      title: 'Две уловки в одном чеке',
      documentTitle: 'Длинный чек',
      intro: 'Фонарь, свечка и зерно. Упаковку обещали бесплатно. Проверь чек.',
      purchaseAssets: const [MoleAssets.lantern, MoleAssets.grain],
      agreement:
          'Земелик купил фонарь за $lantern, свечку за $candle и зерно за ${moleCoinAmount(grain)}. Продавец обещал упаковку бесплатно; платную упаковку Земелик не заказывал.',
      lines: [
        _plain('lantern', 'Фонарь', value: '$lantern'),
        _plain('candle', 'Свечка', value: '$candle'),
        _plain('grain', 'Мешок зерна', value: '$grain'),
        _trick(
          'wrap',
          'Упаковка в подарок',
          'Платная упаковка',
          'Упаковку обещали бесплатно: в строке написано 0. Но в счёт спрятали 2 монеты. Убираем несогласованную плату.',
          MoleTruthKind.substitution,
          value: '0',
          truthValue: '2',
        ),
        _trick(
          'total',
          'ИТОГО',
          'ИТОГО',
          '$lantern + $candle + $grain + 2 = 19. Даже с упаковкой итог был завышен. Без неё получается 17.',
          MoleTruthKind.arithmetic,
          value: '${20 + variant}',
          truthValue: '19',
        ),
      ],
      billedTotal: 20 + variant,
      fairTotal: lantern + candle + grain,
      serverAnswerCode: '19',
      verdictLabel: 'Предъявить обе ошибки',
      sellerReply:
          'Упаковка лишняя, и сумму я завысил. Исправляю обе ошибки: $lantern + $candle + $grain = 17 монет.',
      lesson: 'Проверяй состав чека и сложение по отдельности.',
      hint: 'Здесь две проверки: что заказали и правильно ли сложили строки.',
    ),
  for (final (variant, item, promise, truth, condition, hiddenCondition, amount)
      in [
        (
          0,
          'Фонарь',
          'Получишь в подарок.',
          'Оформляешь покупку в кредит.',
          'Ничего возвращать не нужно.',
          'Вернёшь 18 монет через неделю.',
          18,
        ),
        (
          1,
          'Лопата',
          'Инструмент станет твоим.',
          'Это аренда инструмента.',
          'Можно пользоваться всегда.',
          'Верни через день. Аренда — 9 монет.',
          9,
        ),
        (
          2,
          'Банка мёда',
          'Состав: натуральный мёд.',
          'Состав: сахарный сироп, краситель.',
          'Хранить в прохладном месте.',
          'Хранить в прохладном месте.',
          14,
        ),
        (
          3,
          'Лесной журнал',
          'Один выпуск в подарок.',
          'Оформляется платная подписка.',
          'Это разовое предложение.',
          'Будут списывать по 8 монет в неделю.',
          8,
        ),
      ])
    MoleTruthCase(
      id: 'agreement-$variant',
      stepNo: 5,
      title: 'Слова меняют сделку',
      documentTitle: variant == 2 ? 'Этикетка на банке' : 'Условия сделки',
      intro: switch (variant) {
        0 => 'Лис обещал подарить мне фонарь. Проверь условия.',
        1 => 'Я покупаю лопату навсегда. Проверь, не дают ли её напрокат.',
        2 => 'Я выбрал натуральный мёд. Проверь этикетку.',
        _ => 'Мне обещали один бесплатный выпуск журнала. Проверь условия.',
      },
      documentKind: variant == 2
          ? MoleTruthDocumentKind.productLabel
          : MoleTruthDocumentKind.contract,
      agreement:
          'Земелик согласен только на обещанное: $item. На долг, аренду, замену товара или подписку он не соглашался.',
      lines: [
        _plain('subject', item),
        _trick(
          'action',
          promise,
          truth,
          variant == 2
              ? 'На банке обещан мёд, а в составе сироп с красителем. Это другой продукт.'
              : 'Смысл сделки изменился. Сравни обещание продавца с тем, что оказалось в условиях.',
          variant == 2 ? MoleTruthKind.substitution : MoleTruthKind.obligation,
        ),
        if (variant == 2)
          _plain('term', condition)
        else
          _trick(
            'term',
            condition,
            hiddenCondition,
            'В договоре появилось обязательство, которого не было в договорённости. Сначала попроси объяснить и исправить условия.',
            MoleTruthKind.condition,
          ),
        if (variant != 2) _plain('signature', 'Подпись: ______________'),
      ],
      billedTotal: amount,
      fairTotal: 0,
      serverAnswerCode: 'seller',
      verdictLabel: variant == 2 ? 'Показать подмену' : 'Оспорить условия',
      sellerReply: variant == 2
          ? 'В банке сироп, а не мёд. Ты прав: этот товар не подходит под заказ.'
          : 'Ты заметил подмену. Убираю неподходящие условия. Земелик ничего не подписывает и ничего не платит.',
      lesson: variant == 2
          ? 'Сравни название товара с его составом.'
          : 'Не подписывай то, что отличается от договорённости.',
      hint: variant == 2
          ? 'Сравни название на банке с тем, что написано в составе.'
          : 'Проверь действие и срок. Что получаешь ты, а что обещаешь продавцу?',
    ),
]);

List<MoleTruthCase> buildMoleTruthRun(int seed) {
  final random = Random(seed);
  return List.unmodifiable([
    for (var step = 1; step <= 5; step++)
      moleTruthCatalog[(step - 1) * 4 + random.nextInt(4)],
  ]);
}

/// A single five-task session: two classic checks and three truth-lens checks.
/// Rotating the two classic slots keeps all original scenarios reachable and
/// lets every generated family appear across repeat sessions.
Set<int> moleClassicSteps(int seed) {
  final first = seed % 5;
  return Set.unmodifiable({first, (first + 2) % 5});
}

/// Bounded polynomial hashing stays exactly representable in JS and is stable
/// across Android and Web (unlike a platform-dependent String.hashCode).
int moleTruthSeed(String assignmentId) {
  var hash = 0;
  for (final unit in assignmentId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}
