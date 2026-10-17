import 'package:flutter_test/flutter_test.dart';
import 'package:andromeda_app/dictionary/dictionary_catalog.dart';

void main() {
  test('the approved catalogue has 50 complete, distinct entries', () {
    expect(dictionaryCatalog, hasLength(50));
    expect(dictionaryWordIds, hasLength(50));
    expect(dictionaryCatalog.map((word) => word.title).toSet(), hasLength(50));
    for (final word in dictionaryCatalog) {
      expect(word.definition.trim(), isNotEmpty, reason: word.id);
      expect(word.example.trim(), isNotEmpty, reason: word.id);
    }
  });

  test('search accepts case, ё variants and familiar alternative names', () {
    for (final query in {
      'кошелек': 'wallet',
      ' Полная цена ': 'total_cost',
      'ЗАЙМ': 'loan',
    }.entries) {
      expect(
        selectDictionaryWords(
          readIds: {},
          query: query.key,
        ).map((word) => word.id),
        [query.value],
      );
    }
  });

  test('read and unread filters partition the alphabetical catalogue', () {
    final readIds = {'budget', 'profit'};
    final read = selectDictionaryWords(
      readIds: readIds,
      filter: DictionaryFilter.read,
    );
    final unread = selectDictionaryWords(
      readIds: readIds,
      filter: DictionaryFilter.unread,
    );
    expect(read.map((word) => word.id).toSet(), readIds);
    expect(unread, hasLength(48));
    expect(unread.any((word) => readIds.contains(word.id)), isFalse);
    final all = selectDictionaryWords(readIds: readIds);
    final titles = all
        .map((word) => normalizeDictionaryText(word.title))
        .toList();
    expect(titles, [...titles]..sort());
  });
}
