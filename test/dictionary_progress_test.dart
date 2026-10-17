import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:andromeda_app/dictionary/dictionary_progress.dart';
import 'package:andromeda_app/dictionary/dictionary_storage.dart';

class MemoryStorage implements DictionaryStorage {
  String? value;
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String next) async {
    if (gate != null) await gate!.future;
    if (fail) throw StateError('Storage unavailable');
    value = next;
  }
}

void main() {
  test('a word is saved once and stays remembered after reloading', () async {
    final storage = MemoryStorage();
    final notebook = DictionaryProgress(storage: storage);
    await notebook.load();
    expect(await notebook.remember('budget'), isTrue);
    expect(await notebook.remember('budget'), isFalse);
    final restored = DictionaryProgress(storage: storage);
    await restored.load();
    expect(restored.contains('budget'), isTrue);
    expect(await restored.remember('budget'), isFalse);
    expect(jsonDecode(storage.value!), {
      'version': 2,
      'words': ['budget'],
    });
  });

  test(
    'the earlier quest and onboarding records merge without new notices',
    () async {
      for (final slot in ['quest', 'onboarding']) {
        final storage = MemoryStorage()
          ..value = jsonEncode({
            'version': 1,
            'quest': slot == 'quest' ? ['budget'] : [],
            'onboarding': slot == 'onboarding' ? ['budget'] : [],
          });
        final notebook = DictionaryProgress(storage: storage);
        await notebook.load();
        expect(notebook.contains('budget'), isTrue);
        expect(await notebook.remember('budget'), isFalse);
      }
    },
  );

  test('rapid requests cannot produce two first-add notifications', () async {
    final storage = MemoryStorage()..gate = Completer<void>();
    final notebook = DictionaryProgress(storage: storage);
    await notebook.load();
    final first = notebook.remember('budget');
    expect(await notebook.remember('budget'), isFalse);
    storage.gate!.complete();
    expect(await first, isTrue);
  });

  test('overlapping reads of different words both survive reloading', () async {
    final storage = MemoryStorage()..gate = Completer<void>();
    final notebook = DictionaryProgress(storage: storage);
    await notebook.load();
    final first = notebook.remember('budget');
    final second = notebook.remember('taxes');
    storage.gate!.complete();
    expect(await Future.wait([first, second]), [true, true]);
    final restored = DictionaryProgress(storage: storage);
    await restored.load();
    expect(restored.words, {'budget', 'taxes'});
  });

  test(
    'a failed save can be retried without marking the word prematurely',
    () async {
      final storage = MemoryStorage()..fail = true;
      final notebook = DictionaryProgress(storage: storage);
      await notebook.load();
      expect(await notebook.remember('budget'), isFalse);
      expect(notebook.contains('budget'), isFalse);
      expect(notebook.error, isNotNull);
      storage.fail = false;
      expect(await notebook.remember('budget'), isTrue);
      expect(notebook.error, isNull);
    },
  );

  test(
    'the preview can be restarted without touching any game wallet',
    () async {
      final storage = MemoryStorage();
      final notebook = DictionaryProgress(storage: storage);
      await notebook.load();
      await notebook.remember('budget');
      expect(await notebook.reset(), isTrue);
      expect(notebook.words, isEmpty);
      expect(jsonDecode(storage.value!), {'version': 2, 'words': []});
    },
  );

  test('unknown terms and actions before loading are rejected', () async {
    final notebook = DictionaryProgress(storage: MemoryStorage());
    expect(await notebook.remember('budget'), isFalse);
    await notebook.load();
    expect(await notebook.remember('unknown-term'), isFalse);
    expect(notebook.words, isEmpty);
  });

  test('a corrupt record stays blocked until a successful reload', () async {
    final storage = MemoryStorage()..value = '{bad json';
    final notebook = DictionaryProgress(storage: storage);
    await notebook.load();
    expect(notebook.loaded, isFalse);
    expect(await notebook.remember('budget'), isFalse);
    storage.value = null;
    await notebook.load();
    expect(notebook.loaded, isTrue);
    expect(notebook.words, isEmpty);
  });
}
