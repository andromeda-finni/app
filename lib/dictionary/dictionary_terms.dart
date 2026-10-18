import 'dictionary_catalog.dart';

/// Authored Russian inflections, rather than stems: «долгий» is not «долг».
/// Search aliases such as «хочу», «надо» and «защита» are deliberately excluded
/// from inline matching because they also occur outside financial explanations.
const _forms = <String, String>{
  'money': 'деньги|денег|деньгам|деньгами|деньгах',
  'coin':
      'монет(?:а|ы|е|у|ой|ам|ами|ах)?|монетк(?:а|и|е|у|ой|ам|ами|ах)|монеток',
  'wallet': 'кошелек|кошельк(?:а|у|ом|е|и|ов|ам|ами|ах)',
  'piggy_bank': 'копилк(?:а|и|е|у|ой|ам|ами|ах)|копилок',
  'budget': 'бюджет(?:а|у|ом|е|ы|ов|ам|ами|ах)?',
  'income': 'доход(?:а|у|ом|е|ы|ов|ам|ами|ах)?',
  'expenses': 'расход(?:ы|ов|ам|ами|ах)|трат(?:а|ы|е|у|ой|ам|ами|ах)?',
  'savings': 'накоплени(?:я|й|ям|ями|ях)',
  'goal': 'цел(?:ь|и|ью|ей|ям|ями|ях)',
  'need': 'потребност(?:ь|и|ью|ей|ям|ями|ях)',
  'want': 'желани(?:е|я|ю|ем|и|й|ям|ями|ях)',
  'economy': 'экономи(?:я|и|ю|ей)',
  'reserve': 'запас(?:а|у|ом|е|ы|ов|ам|ами|ах)?',
  'required_reserve': 'резерв(?:а|у|ом|е|ы|ов|ам|ами|ах)?',
  'balance': 'баланс(?:а|у|ом|е|ы|ов|ам|ами|ах)?',
  'price': 'цен(?:а|ы|е|у|ой|ам|ами|ах)?',
  'cost': 'стоимост(?:ь|и|ью|ей|ям|ями|ях)',
  'total_cost':
      'полн(?:ая|ой|ую|ою)\\s+(?:цен(?:а|ы|е|у|ой)|стоимост(?:ь|и|ью))',
  'purchase': 'покупк(?:а|и|е|у|ой|ам|ами|ах)|покупок',
  'product': 'товар(?:а|у|ом|е|ы|ов|ам|ами|ах)?',
  'service': 'услуг(?:а|и|е|у|ой|ам|ами|ах)?',
  'change': 'сдач(?:а|и|е|у|ей)',
  'remainder': 'остаток|остатк(?:а|у|ом|е|и|ов|ам|ами|ах)',
  'discount': 'скидк(?:а|и|е|у|ой|ам|ами|ах)|скидок',
  'promotion': 'акци(?:я|и|ю|ей|й|ям|ями|ях)',
  'receipt': 'чек(?:а|у|ом|е|и|ов|ам|ами|ах)?',
  'delivery': 'доставк(?:а|и|е|у|ой|ам|ами|ах)|доставок',
  'compare_prices': 'сравнени(?:е|я|ю|ем|и)\\s+цен',
  'revenue': 'выручк(?:а|и|е|у|ой)',
  'profit': 'прибыл(?:ь|и|ью|ей|ям|ями|ях)',
  'currency': 'валют(?:а|ы|е|у|ой|ам|ами|ах)?',
  'exchange_rate': 'курс(?:а|у|ом|е|ы|ов|ам|ами|ах)?(?:\\s+(?:обмена|валют))?',
  'exchange': 'обмен(?:а|у|ом|е|ы|ов|ам|ами|ах)?',
  'tugrik': 'тугрик(?:а|у|ом|е|и|ов|ам|ами|ах)?',
  'loan': 'заем|займ(?:а|у|ом|е|ы|ов|ам|ами|ах)?|взаймы',
  'debt': 'долг(?:а|у|ом|е|и|ов|ам|ами|ах)?',
  'repayment': 'возврат(?:а|у|ом|е)?\\s+долг(?:а|ов)',
  'risk': 'риск(?:а|у|ом|е|и|ов|ам|ами|ах)?',
  'credit': 'кредит(?:а|у|ом|е|ы|ов|ам|ами|ах)?',
  'rental': 'аренд(?:а|ы|е|у|ой)',
  'subscription': 'подписк(?:а|и|е|у|ой|ам|ами|ах)|подписок',
  'deal': 'сделк(?:а|и|е|у|ой|ам|ами|ах)|сделок',
  'insurance':
      'страховк(?:а|и|е|у|ой|ам|ами|ах)|страховок|страховани(?:е|я|ю|ем|и)',
  'public_money':
      'общ(?:ие|их|им|ими)\\s+(?:деньги|денег|деньгам|деньгами|деньгах)',
  'contribution': 'вклад(?:а|у|ом|е|ы|ов|ам|ами|ах)?',
  'city_budget': 'городск(?:ой|ого|ому|им|ом)\\s+бюджет(?:а|у|ом|е)?',
  'taxes': 'налог(?:а|у|ом|е|и|ов|ам|ами|ах)?',
  'percent': 'процент(?:а|у|ом|е|ы|ов|ам|ами|ах)?',
  'bonus': 'бонус(?:а|у|ом|е|ы|ов|ам|ами|ах)?',
  'term': 'срок(?:а|у|ом|е|и|ов|ам|ами|ах)?',
};

final _patterns = {
  for (final word in dictionaryCatalog)
    word: RegExp(
      '(?<![a-zа-я0-9_])(?:${_forms[word.id] ?? RegExp.escape(normalizeDictionaryText(word.title))})(?![a-zа-я0-9_])',
    ),
};

class DictionaryTermMatch {
  const DictionaryTermMatch(this.word, this.start, this.end);

  final DictionaryWord word;
  final int start;
  final int end;
}

/// Offsets refer to the original text: case and е/ё stay exactly as authored.
/// At a shared position, a complete phrase wins over its component words.
List<DictionaryTermMatch> matchDictionaryTerms(String text) {
  final normalized = text.toLowerCase().replaceAll('ё', 'е');
  final candidates =
      <DictionaryTermMatch>[
        for (final entry in _patterns.entries)
          for (final match in entry.value.allMatches(normalized))
            DictionaryTermMatch(entry.key, match.start, match.end),
        for (final match in RegExp(r'(?<=\d)\s*%').allMatches(normalized))
          DictionaryTermMatch(
            dictionaryCatalog.singleWhere((word) => word.id == 'percent'),
            match.end - 1,
            match.end,
          ),
      ]..sort((a, b) {
        final position = a.start.compareTo(b.start);
        return position != 0 ? position : b.end.compareTo(a.end);
      });
  final result = <DictionaryTermMatch>[];
  var end = 0;
  for (final match in candidates) {
    if (match.start < end) continue;
    result.add(match);
    end = match.end;
  }
  return result;
}
