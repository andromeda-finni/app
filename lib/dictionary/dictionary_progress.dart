import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'dictionary_storage.dart';
import 'dictionary_catalog.dart';

/// A personal reference notebook, independent of quests and the game economy.
class DictionaryProgress extends ChangeNotifier {
  DictionaryProgress({required this.storage});

  static const _storageKey = 'groshik.dictionary.v1';
  final DictionaryStorage storage;
  Set<String> _words = {};
  bool loaded = false;
  bool busy = false;
  String? error;
  bool _disposed = false;
  Future<void>? _loading;
  Future<void> _writeTail = Future.value();
  final Set<String> _pendingIds = {};

  bool contains(String id) => _words.contains(id);
  Set<String> get words => Set.unmodifiable(_words);

  Future<void> load() =>
      _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    loaded = false;
    error = null;
    try {
      final raw = await storage.read(_storageKey);
      final next = <String>{};
      if (raw != null) {
        final data = jsonDecode(raw);
        if (data is! Map<String, dynamic>) throw const FormatException();
        if (data['version'] == 1) {
          // Merge the earlier preview slots into one notebook. No coins migrate.
          next.addAll(_readWords(data['quest']));
          next.addAll(_readWords(data['onboarding']));
        } else if (data['version'] == 2) {
          next.addAll(_readWords(data['words']));
        } else {
          throw const FormatException();
        }
      }
      _words = next;
      loaded = true;
      error = null;
    } catch (_) {
      error = 'Не удалось прочитать словарик. Попробуй ещё раз.';
    }
    _notify();
  }

  Set<String> _readWords(dynamic value) {
    if (value is! List ||
        value.any((id) => id is! String || !dictionaryWordIds.contains(id))) {
      throw const FormatException();
    }
    return value.cast<String>().toSet();
  }

  /// True only for the first successfully saved explanation of this word.
  Future<bool> remember(String id) {
    if (!loaded ||
        !dictionaryWordIds.contains(id) ||
        contains(id) ||
        _pendingIds.contains(id)) {
      return Future.value(false);
    }
    _pendingIds.add(id);
    final result = _writeTail.then((_) => _persist({..._words, id}));
    _writeTail = result
        .then<void>((_) {})
        .whenComplete(() => _pendingIds.remove(id));
    return result;
  }

  /// Test support; the game does not expose a reset action to the child.
  Future<bool> reset() async {
    if (!loaded || busy || _pendingIds.isNotEmpty) return false;
    return _persist({});
  }

  Future<bool> _persist(Set<String> next) async {
    busy = true;
    error = null;
    _notify();
    try {
      await storage.write(
        _storageKey,
        jsonEncode({'version': 2, 'words': next.toList()..sort()}),
      );
      _words = next;
      return true;
    } catch (_) {
      error = 'Не удалось сохранить слово. Его объяснение всё равно доступно.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
