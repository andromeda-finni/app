import 'package:andromeda_app/dictionary/dictionary_catalog.dart';
import 'package:andromeda_app/dictionary/dictionary_terms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 50 approved titles resolve to their own explanation', () {
    for (final word in dictionaryCatalog) {
      final matches = matchDictionaryTerms(word.title);
      expect(matches.map((match) => match.word.id), [
        word.id,
      ], reason: word.title);
      expect(matches.single.start, 0);
      expect(matches.single.end, word.title.length);
    }
  });

  test('inflected game words resolve without stemming unrelated words', () {
    const examples = {
      'money': 'денег',
      'coin': 'монеток',
      'wallet': 'кошельке',
      'piggy_bank': 'копилку',
      'budget': 'бюджетом',
      'income': 'доходом',
      'expenses': 'расходов',
      'savings': 'накоплений',
      'goal': 'цели',
      'need': 'потребности',
      'want': 'желания',
      'economy': 'экономии',
      'reserve': 'запасе',
      'required_reserve': 'резерва',
      'balance': 'балансе',
      'price': 'цену',
      'cost': 'стоимостью',
      'total_cost': 'полной цене',
      'purchase': 'покупок',
      'product': 'товары',
      'service': 'услугу',
      'change': 'сдачу',
      'remainder': 'остатка',
      'discount': 'скидкой',
      'promotion': 'акции',
      'receipt': 'чеке',
      'delivery': 'доставку',
      'compare_prices': 'сравнением цен',
      'revenue': 'выручку',
      'profit': 'прибыли',
      'currency': 'валюты',
      'exchange_rate': 'курсу обмена',
      'exchange': 'обмене',
      'tugrik': 'тугриков',
      'loan': 'займа',
      'debt': 'долги',
      'repayment': 'возвратом долга',
      'risk': 'рисков',
      'credit': 'кредите',
      'rental': 'аренду',
      'subscription': 'подписку',
      'deal': 'сделки',
      'insurance': 'страхованием',
      'public_money': 'общих денег',
      'contribution': 'вкладом',
      'city_budget': 'городского бюджета',
      'taxes': 'налогами',
      'percent': 'процентов',
      'bonus': 'бонусом',
      'term': 'срока',
    };
    expect(examples.keys.toSet(), dictionaryWordIds);
    for (final entry in examples.entries) {
      expect(
        matchDictionaryTerms('«${entry.value}»!').map((match) => match.word.id),
        [entry.key],
        reason: entry.value,
      );
    }
    expect(
      matchDictionaryTerms('долгий ценник курсовой чеканить товарный'),
      isEmpty,
    );
    expect(
      matchDictionaryTerms('Надо, хочу, защита, цельный, запасной'),
      isEmpty,
    );
  });

  test('longest phrases win, including repeated words and line breaks', () {
    const text =
        'Полная стоимость и полная цена, цена. '
        'ГОРОДСКОЙ\nБЮДЖЕТ и бюджет; возврат долга и долг. Общие деньги.';
    expect(matchDictionaryTerms(text).map((match) => match.word.id), [
      'total_cost',
      'total_cost',
      'price',
      'city_budget',
      'budget',
      'repayment',
      'debt',
      'public_money',
    ]);
  });

  test('case and е/ё preserve original offsets and punctuation', () {
    const text =
        '🪙 В КОШЕЛЬКЕ: заём, заем, займ и взаймы — 10% или 5 %. Не 5%скидка.';
    final matches = matchDictionaryTerms(text);
    expect(matches.map((match) => text.substring(match.start, match.end)), [
      'КОШЕЛЬКЕ',
      'заём',
      'заем',
      'займ',
      'взаймы',
      '%',
      '%',
      '%',
      'скидка',
    ]);
  });
}
