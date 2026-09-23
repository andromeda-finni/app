import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the child's opaque bearer token on-device (see backend/README.md
/// — the server never stores the raw token, only its hash). The token lets the
/// startup gate request the authoritative onboarding progress from the server.
class AuthStorage {
  AuthStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'child_auth_token';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
