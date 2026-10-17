import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_client.dart';

abstract interface class DictionaryStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Device-local notes, isolated by backend and the child's persistent pet ID.
/// No bearer token or shared anonymous fallback is used as a storage key.
class DeviceDictionaryStorage implements DictionaryStorage {
  DeviceDictionaryStorage({
    required this.apiClient,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient apiClient;
  final FlutterSecureStorage _storage;
  String? _scope;

  Future<String> _scopedKey(String key) async {
    if (_scope == null) {
      final pet = await apiClient.get('/pet');
      final id = pet['id'];
      if (id is! String || id.isEmpty) {
        throw const FormatException('Missing dictionary profile');
      }
      _scope = '${Uri.encodeComponent(apiClient.baseUrl)}.$id';
    }
    return '$key.$_scope';
  }

  @override
  Future<String?> read(String key) async =>
      _storage.read(key: await _scopedKey(key));

  @override
  Future<void> write(String key, String value) async =>
      _storage.write(key: await _scopedKey(key), value: value);
}
