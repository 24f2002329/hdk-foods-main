import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  Future<Map<String, dynamic>> uploadBannerImage(int bannerId, File imageFile) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw Exception('Not logged in');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/config/banners/$bannerId/upload-image/'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    final extension = imageFile.path.split('.').last.toLowerCase();
    String mimeType = 'image/jpeg';
    if (extension == 'png') {
      mimeType = 'image/png';
    } else if (extension == 'gif') {
      mimeType = 'image/gif';
    } else if (extension == 'webp') {
      mimeType = 'image/webp';
    } else if (extension == 'bmp') {
      mimeType = 'image/bmp';
    }

    final multipartFile = await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
      contentType: MediaType.parse(mimeType),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to upload banner image: ${response.body}');
  }

  Future<Map<String, dynamic>> getPrepConfig() async {
    final response = await http.get(Uri.parse('$_base/orders/admin/prep-config/'), headers: await _headers());
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception('Failed to load prep config');
  }

  Future<void> updatePrepConfig(Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$_base/orders/admin/prep-config/'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to update prep config: ${response.body}');
  }
}
