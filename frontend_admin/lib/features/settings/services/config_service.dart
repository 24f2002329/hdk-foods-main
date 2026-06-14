import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/storage/token_storage.dart';

class AdminConfigService {
  static final String _base = ApiConfig.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw Exception('Not logged in');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> getConfig() async {
    final response = await http.get(Uri.parse('$_base/config/'), headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception('Failed to load config');
  }

  Future<void> updateConfig(Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$_base/config/'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to update: ${response.body}');
  }

  Future<List<dynamic>> getBanners() async {
    final response = await http.get(Uri.parse('$_base/config/banners/'), headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body) as List;
    throw Exception('Failed to load banners');
  }

  Future<Map<String, dynamic>> createBanner(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_base/config/banners/'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception('Failed to create banner: ${response.body}');
  }

  Future<void> updateBanner(int id, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$_base/config/banners/$id/'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to update banner');
  }

  Future<void> deleteBanner(int id) async {
    final response = await http.delete(
      Uri.parse('$_base/config/banners/$id/'),
      headers: await _headers(),
    );
    if (response.statusCode != 204) throw Exception('Failed to delete banner');
  }

  Future<int> broadcastNotification(String title, String body) async {
    final response = await http.post(
      Uri.parse('$_base/config/notify-all/'),
      headers: await _headers(),
      body: jsonEncode({'title': title, 'body': body}),
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body)['sent'] as num?)?.toInt() ?? 0;
    }
    throw Exception('Failed to send notification: ${response.body}');
  }
}
