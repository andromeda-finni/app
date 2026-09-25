import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists an opaque bearer token on-device (see backend/README.md — the
/// server never stores the raw token, only its hash).
///
/// A parent and a child can share one device, switching through the role
/// gate, so each role keeps its token under its own key: signing in as the
/// parent must never overwrite or reuse the child's session.
class AuthStorage {
  AuthStorage({FlutterSecureStorage? storage})
    : this._(storage, 'child_auth_token');

  AuthStorage.parent({FlutterSecureStorage? storage})
    : this._(storage, 'parent_auth_token');

  AuthStorage._(FlutterSecureStorage? storage, this._tokenKey)
    : _storage = storage ?? const FlutterSecureStorage();

  final String _tokenKey;
  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
