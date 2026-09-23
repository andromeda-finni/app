import 'package:flutter/material.dart';

const kTugrikiQuestId = 'Q_TUGRIKI_CURRENCY';
const kTugrikiReward = 20;
const int kExchangeRate = 2; // 1 тугрик = 2 монетки

abstract final class TugrikiAssets {
  static const root = 'assets/minigames/tugriki';
  static const square = '$root/square.png';
  static const vorobeyNormal = '$root/vorobey_1.png';
  static const vorobeyHappy = '$root/vorobey_2.png';
  static const foreignMoney = '$root/foreign_money.png';
  static const foreignMoneyFront = '$root/foreign_money_front.png';
  static const foreignMoneyBag = '$root/foreign_money_bag.png';

  static const homeCoin = 'assets/icons/coin.png';
  static const catPlayful = 'assets/Cat/Base/playful.png';
  static const catStriped = 'assets/Cat/Red_collar/base/striped.png';
  static const paperBg = 'assets/backgrounds/paper.png';
}

/// Товар на сказочном рынке соседнего государства
class MarketGood {
  const MarketGood({
    required this.id,
    required this.name,
    required this.iconEmoji,
    required this.priceTugriki,
    this.assetIcon,
  });

  final String id;
  final String name;
  final String iconEmoji;
  final int priceTugriki;
  final String? assetIcon;

  int get priceCoins => priceTugriki * kExchangeRate;
}

/// Стандартный каталог товаров по сценарию game_tugriki.md
abstract final class MarketCatalog {
  static const bun = MarketGood(
    id: 'bun',
    name: 'Булочка',
    iconEmoji: '🥐',
    priceTugriki: 6,
    assetIcon: 'assets/icons/sweet.png',
  );

  static const soup = MarketGood(
    id: 'soup',
    name: 'Суп',
    iconEmoji: '🍲',
    priceTugriki: 4,
    assetIcon: 'assets/icons/bowl.png',
  );

  static const juice = MarketGood(
    id: 'juice',
    name: 'Сок',
    iconEmoji: '🧃',
    priceTugriki: 2,
    assetIcon: 'assets/icons/eat.png',
  );

  static const bunVariant2 = MarketGood(
    id: 'bun_v2',
    name: 'Булочка',
    iconEmoji: '🥐',
    priceTugriki: 3,
    assetIcon: 'assets/icons/sweet.png',
  );

  static const fruits = MarketGood(
    id: 'fruits',
    name: 'Фрукты',
    iconEmoji: '🍎',
    priceTugriki: 3,
    assetIcon: 'assets/icons/eat.png',
  );

  static const pie = MarketGood(
    id: 'pie',
    name: 'Пирожок',
    iconEmoji: '🥧',
    priceTugriki: 2,
    assetIcon: 'assets/icons/sweet.png',
  );
}

enum TugrikiGameStep {
  introScene,     // Вход на рынок, диалог Воробья и Грошика, знакомство с курсом
  variant1Single, // Вариант 1 — Булочка за 6 тугриков (расчет 6 x 2 = 12)
  variant1Mistake,// Разбор ошибки: 6 ячеек по 2 монетки (2+2+2+2+2+2=12)
  variant2Multi,  // Вариант 2 — Суп (4) + Сок (2) + Булочка (3) = 9 тугриков -> 18 монет
  variant3Budget, // Вариант 3 — Бюджет 20 монет, выбор покупок
  finalSummary,   // Финальная карточка и награда
}

class QuizOption {
  const QuizOption({
    required this.code,
    required this.label,
    required this.isCorrect,
  });

  final String code;
  final String label;
  final bool isCorrect;
}
