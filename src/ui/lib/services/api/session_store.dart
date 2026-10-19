import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SessionStore {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'refresh_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeRefreshToken(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      return;
    }
  }
}

class MemorySessionStore implements SessionStore {
  String? _token;

  @override
  Future<String?> readRefreshToken() async => _token;

  @override
  Future<void> writeRefreshToken(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
