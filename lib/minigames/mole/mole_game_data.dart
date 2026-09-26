import 'package:flutter/material.dart';

const kMoleQuestId = 'Q_MOLE_FINE_PRINT';

abstract final class MoleAssets {
  static const root = 'assets/minigames/mole';
  static const zemelik = '$root/zemelik.webp';
  static const house = '$root/mole_house.webp';
  static const shop = '$root/shop.webp';
  static const magnifier = '$root/magnifier.webp';
  static const scroll = '$root/scroll.webp';
  static const grain = '$root/grain.webp';
  static const lantern = '$root/lantern.webp';
  static const chest = '$root/chest.webp';
  static const key = '$root/key.webp';
  static const blanket = '$root/blanket.webp';
  static const rope = '$root/rope.webp';
  static const lollipop = '$root/lollipop.webp';
  static const giftWrap = '$root/gift_wrap.webp';
  static const dialogue = '$root/dialogue.webp';
}

enum MoleBoardKind { advertisement, receipt }

class MoleHotspot {
  const MoleHotspot({
    required this.position,
    required this.label,
    required this.detail,
  });

  /// Relative position on the inspection board, from 0 to 1 on each axis.
  final Offset position;
  final String label;
  final String detail;
}

class MoleReceiptLine {
  const MoleReceiptLine({required this.label, required this.amount});

  final String label;
  final int amount;
}

class MoleAnswer {
  const MoleAnswer(this.code, this.label);

  final String code;
  final String label;
}

class MoleQuestion {
  const MoleQuestion({
    required this.prompt,
    required this.answers,
    required this.correctCode,
    required this.successFeedback,
    required this.recoveryFeedback,
  });

  final String prompt;
  final List<MoleAnswer> answers;
  final String correctCode;
  final String successFeedback;
  final String recoveryFeedback;
}

class MoleEpisode {
  const MoleEpisode({
    required this.id,
    required this.title,
    required this.intro,
    required this.boardKind,
    required this.boardTitle,
    required this.boardSubtitle,
    required this.itemAsset,
    required this.hotspots,
    required this.questions,
    required this.successText,
    this.receiptLines = const [],
    this.supportAssets = const [],
  });

  final String id;
  final String title;
  final String intro;
  final MoleBoardKind boardKind;
  final String boardTitle;
  final String boardSubtitle;
  final String itemAsset;
  final List<MoleHotspot> hotspots;
  final List<MoleReceiptLine> receiptLines;
  final List<String> supportAssets;
  final List<MoleQuestion> questions;
  final String successText;
}

const moleEpisodes = <MoleEpisode>[
  MoleEpisode(
    id: 'grain_delivery',
    title: 'Скрытая доставка',
    intro: 'Я нашёл мешок зерна по отличной цене. Проверь мелкий текст: вдруг там спрятаны дополнительные расходы?',
    boardKind: MoleBoardKind.advertisement,
    boardTitle: 'Мешок зерна',
    boardSubtitle: '8 монет',
    itemAsset: MoleAssets.grain,
    hotspots: [
      MoleHotspot(
        position: Offset(0.66, 0.78),
        label: 'Условия доставки',
        detail: 'Доставка оплачивается отдельно: ещё 4 монеты.',
      ),
    ],
    questions: [
      MoleQuestion(
        prompt: 'Сколько монет нужно заплатить вместе с доставкой?',
        answers: [
          MoleAnswer('8', '8 монет'),
          MoleAnswer('12', '12 монет'),
          MoleAnswer('16', '16 монет'),
        ],
        correctCode: '12',
        successFeedback: 'Верно: 8 за зерно и 4 за доставку — всего 12.',
        recoveryFeedback:
            'Сложи цену мешка и стоимость доставки, которую нашли через лупу.',
      ),
    ],
    successText: 'Теперь я знаю полную стоимость и могу решить, подходит ли мне покупка.',
  ),
  MoleEpisode(
    id: 'lantern_offer',
    title: 'Фонарь по акции',
    intro: 'Волшебный фонарь обещают всего за 6 монет. Но мне нужен только один. Давай проверим условия акции.',
    boardKind: MoleBoardKind.advertisement,
    boardTitle: 'Волшебный фонарь',
    boardSubtitle: '6 монет по акции',
    itemAsset: MoleAssets.lantern,
    hotspots: [
      MoleHotspot(
        position: Offset(0.34, 0.72),
        label: 'Условие акции',
        detail: 'Цена 6 монет действует при покупке двух фонарей.',
      ),
      MoleHotspot(
        position: Offset(0.72, 0.82),
        label: 'Обычная цена',
        detail: 'Один фонарь без акции стоит 9 монет.',
      ),
    ],
    questions: [
      MoleQuestion(
        prompt: 'Сколько стоит один фонарь, если второй не нужен?',
        answers: [
          MoleAnswer('6', '6 монет'),
          MoleAnswer('9', '9 монет'),
          MoleAnswer('12', '12 монет'),
        ],
        correctCode: '9',
        successFeedback: 'Точно! Один фонарь стоит 9 монет.',
        recoveryFeedback: 'Цена 6 монет работает только при покупке двух фонарей. Найди обычную цену.',
      ),
    ],
    successText: 'Хорошо, что мы прочитали условия. Два дешёвых товара могут стоить дороже одного нужного.',
  ),
  MoleEpisode(
    id: 'extra_receipt_item',
    title: 'Лишняя строка в чеке',
    intro: 'Я купил зерно, фонарь и верёвку. Проверь чек и найди то, чего среди покупок не было.',
    boardKind: MoleBoardKind.receipt,
    boardTitle: 'Чек из лавки',
    boardSubtitle: 'Покупки для дома',
    itemAsset: MoleAssets.lollipop,
    supportAssets: [
      MoleAssets.grain,
      MoleAssets.lantern,
      MoleAssets.rope,
      MoleAssets.lollipop,
    ],
    receiptLines: [
      MoleReceiptLine(label: 'Мешок зерна', amount: 7),
      MoleReceiptLine(label: 'Фонарь', amount: 6),
      MoleReceiptLine(label: 'Верёвка', amount: 4),
      MoleReceiptLine(label: 'Леденец', amount: 3),
      MoleReceiptLine(label: 'Итого', amount: 20),
    ],
    hotspots: [
      MoleHotspot(
        position: Offset(0.54, 0.62),
        label: 'Лишняя покупка',
        detail: 'Леденец — 3 монеты. Крот его не покупал.',
      ),
    ],
    questions: [
      MoleQuestion(
        prompt: 'Какой товар попал в чек по ошибке?',
        answers: [
          MoleAnswer('grain', 'Мешок зерна'),
          MoleAnswer('rope', 'Верёвка'),
          MoleAnswer('lollipop', 'Леденец'),
        ],
        correctCode: 'lollipop',
        successFeedback: 'Да, леденца среди покупок не было.',
        recoveryFeedback: 'Сравни чек со списком покупок Крота.',
      ),
      MoleQuestion(
        prompt: 'Что Кроту лучше сделать?',
        answers: [
          MoleAnswer('ignore', 'Заплатить и ничего не говорить'),
          MoleAnswer('ask', 'Попросить продавца проверить чек'),
          MoleAnswer('throw', 'Выбросить чек'),
        ],
        correctCode: 'ask',
        successFeedback:
            'Верно. Ошибку должен проверить продавец и выдать правильный чек.',
        recoveryFeedback: 'Чек лучше сохранить и спокойно попросить продавца проверить ошибку.',
      ),
    ],
    successText: 'Продавец убрал лишний леденец. Теперь сумма верная.',
  ),
  MoleEpisode(
    id: 'wrong_total',
    title: 'Две ошибки',
    intro: 'В длинном чеке может быть несколько ошибок. Найди лишнюю услугу и проверь сложение.',
    boardKind: MoleBoardKind.receipt,
    boardTitle: 'Длинный чек',
    boardSubtitle: 'Фонарь, свечка и зерно',
    itemAsset: MoleAssets.giftWrap,
    supportAssets: [MoleAssets.lantern, MoleAssets.grain, MoleAssets.giftWrap],
    receiptLines: [
      MoleReceiptLine(label: 'Фонарь', amount: 6),
      MoleReceiptLine(label: 'Свечка', amount: 2),
      MoleReceiptLine(label: 'Мешок зерна', amount: 9),
      MoleReceiptLine(label: 'Подарочная упаковка', amount: 2),
      MoleReceiptLine(label: 'Итого', amount: 20),
    ],
    hotspots: [
      MoleHotspot(
        position: Offset(0.52, 0.62),
        label: 'Лишняя услуга',
        detail: 'Подарочная упаковка — 2 монеты. Крот её не просил.',
      ),
      MoleHotspot(
        position: Offset(0.62, 0.80),
        label: 'Ошибка в сумме',
        detail: 'Даже с упаковкой получается 19, а не 20 монет.',
      ),
    ],
    questions: [
      MoleQuestion(
        prompt: 'Что в чеке лишнее?',
        answers: [
          MoleAnswer('candle', 'Свечка'),
          MoleAnswer('wrap', 'Подарочная упаковка'),
          MoleAnswer('grain', 'Мешок зерна'),
        ],
        correctCode: 'wrap',
        successFeedback: 'Точно, упаковку Крот не заказывал.',
        recoveryFeedback: 'Вспомни, какие три вещи Крот назвал в начале.',
      ),
      MoleQuestion(
        prompt: 'Сколько получилось бы даже с лишней упаковкой?',
        answers: [
          MoleAnswer('17', '17 монет'),
          MoleAnswer('19', '19 монет'),
          MoleAnswer('20', '20 монет'),
        ],
        correctCode: '19',
        successFeedback: 'Верно: 6 + 2 + 9 + 2 = 19.',
        recoveryFeedback: 'Сложи четыре строки ещё раз по порядку.',
      ),
    ],
    successText:
        'Ты нашёл обе ошибки: лишнюю упаковку и неверную итоговую сумму.',
  ),
  MoleEpisode(
    id: 'two_error_challenge',
    title: 'Проверка для следопыта',
    intro: 'Последний чек сложнее. Найди две ошибки и выбери безопасный способ их исправить.',
    boardKind: MoleBoardKind.receipt,
    boardTitle: 'Чек перед дорогой',
    boardSubtitle: 'Плед, верёвка и ключ',
    itemAsset: MoleAssets.blanket,
    supportAssets: [
      MoleAssets.blanket,
      MoleAssets.rope,
      MoleAssets.key,
      MoleAssets.giftWrap,
    ],
    receiptLines: [
      MoleReceiptLine(label: 'Тёплый плед', amount: 4),
      MoleReceiptLine(label: 'Верёвка', amount: 4),
      MoleReceiptLine(label: 'Золотой ключ', amount: 5),
      MoleReceiptLine(label: 'Подарочная упаковка', amount: 3),
      MoleReceiptLine(label: 'Итого', amount: 18),
    ],
    hotspots: [
      MoleHotspot(
        position: Offset(0.50, 0.62),
        label: 'Первая ошибка',
        detail: 'Подарочную упаковку Крот не заказывал.',
      ),
      MoleHotspot(
        position: Offset(0.63, 0.80),
        label: 'Вторая ошибка',
        detail: 'С упаковкой сумма была бы 16, а не 18 монет.',
      ),
    ],
    questions: [
      MoleQuestion(
        prompt: 'Сколько получилось бы вместе с лишней упаковкой?',
        answers: [
          MoleAnswer('13', '13 монет'),
          MoleAnswer('16', '16 монет'),
          MoleAnswer('18', '18 монет'),
        ],
        correctCode: '16',
        successFeedback: 'Правильно: 4 + 4 + 5 + 3 = 16.',
        recoveryFeedback: 'Сложи цены всех четырёх строк, включая упаковку.',
      ),
      MoleQuestion(
        prompt: 'Как исправить чек?',
        answers: [
          MoleAnswer('pay', 'Заплатить 18 монет и уйти'),
          MoleAnswer('edit', 'Самому зачеркнуть строки'),
          MoleAnswer('seller', 'Попросить продавца проверить чек'),
        ],
        correctCode: 'seller',
        successFeedback:
            'Верно. Покупатель замечает ошибку, а продавец исправляет чек.',
        recoveryFeedback:
            'Не меняй чек сам. Покажи обе ошибки продавцу и попроси новый чек.',
      ),
    ],
    successText: 'Отличная проверка! Без упаковки Крот заплатит 13 монет и получит правильный чек.',
  ),
];
