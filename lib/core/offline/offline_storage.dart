import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key-value storage for the offline cache and the action queue.
abstract interface class OfflineStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Device storage, the same plugin that already keeps the auth token: it is
/// available on Android and Web without a new dependency.
class DeviceOfflineStorage implements OfflineStorage {
  DeviceOfflineStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory storage for tests.
class MemoryOfflineStorage implements OfflineStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
