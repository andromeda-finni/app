import 'package:andromeda_app/core/auth_storage.dart';

/// In-memory stand-in for AuthStorage in widget tests. The real
/// implementation talks to a platform-channel secure-storage plugin, which
/// has nothing to answer it in a plain `flutter_test` run and hangs forever
/// instead of failing fast — this avoids ever touching that channel.
class FakeAuthStorage implements AuthStorage {
  FakeAuthStorage({String? initialToken}) : _token = initialToken;

  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<void> clearToken() async => _token = null;
}
