import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(
      key: "access",
      value: access,
    );

    await _storage.write(
      key: "refresh",
      value: refresh,
    );
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(
      key: "access",
    );
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(
      key: "refresh",
    );
  }

  static Future<void> logout() async {
    await _storage.delete(key: "access");
    await _storage.delete(key: "refresh");
    // Do not delete onboarding flag on logout
  }

  static Future<void> setOnboardingComplete() async {
    await _storage.write(
      key: "onboarding_complete",
      value: "true",
    );
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
