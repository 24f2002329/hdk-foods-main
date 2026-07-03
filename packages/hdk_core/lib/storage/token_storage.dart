import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'local_cache.dart';

class TokenStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveTokens({
    required String access,
    required String refresh,
    String? role,
  }) async {
    await _storage.write(key: 'access', value: access);
    await _storage.write(key: 'refresh', value: refresh);
    if (role != null) {
      await _storage.write(key: 'role', value: role);
    }
  }

  static Future<String?> getAccessToken() async => _storage.read(key: 'access');

  static Future<String?> getRefreshToken() async =>
      _storage.read(key: 'refresh');

  static Future<String?> getRole() async => _storage.read(key: 'role');

  static Future<void> logout() async {
    await _storage.delete(key: 'access');
    await _storage.delete(key: 'refresh');
    await _storage.delete(key: 'role');
    await LocalCache.remove('cached_user_profile');
  }

  static Future<void> setOnboardingComplete() async {
    await _storage.write(key: "onboarding_complete", value: "true");
  }

  static Future<bool> hasCompletedOnboarding() async {
    final value = await _storage.read(key: "onboarding_complete");
    return value == "true";
  }

  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: "access");
    return token != null && token.isNotEmpty;
  }
}
