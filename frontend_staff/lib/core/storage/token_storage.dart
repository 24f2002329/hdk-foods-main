import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveTokens({
    required String access,
    required String refresh,
    required String role,
  }) async {
    await _storage.write(key: 'access', value: access);
    await _storage.write(key: 'refresh', value: refresh);
    await _storage.write(key: 'role', value: role);
  }

  static Future<String?> getAccessToken() async =>
      _storage.read(key: 'access');

  static Future<String?> getRefreshToken() async =>
      _storage.read(key: 'refresh');

  static Future<String?> getRole() async => _storage.read(key: 'role');

  static Future<void> logout() async {
    await _storage.delete(key: 'access');
    await _storage.delete(key: 'refresh');
    await _storage.delete(key: 'role');
  }
}
