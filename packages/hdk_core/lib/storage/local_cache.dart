import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static SharedPreferences? _prefs;

  static Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> setString(String key, String value) async {
    await _init();
    await _prefs!.setString(key, value);
  }

  static Future<String?> getString(String key) async {
    await _init();
    return _prefs!.getString(key);
  }

  static Future<void> setJson(String key, dynamic value) async {
    await setString(key, jsonEncode(value));
  }

  static Future<dynamic> getJson(String key) async {
    final str = await getString(key);
    if (str == null) return null;
    try {
      return jsonDecode(str);
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(String key) async {
    await _init();
    await _prefs!.remove(key);
  }
}
