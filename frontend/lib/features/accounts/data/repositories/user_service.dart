import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:hdk_core/hdk_core.dart';

class UserService {
  static final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw Exception('Please login again');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Fetch the current authenticated user's profile.
  Future<User> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/me/'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw Exception('Failed to load user profile');
  }

  /// Update the current user's name.
  Future<User> updateName(String name) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/me/'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw Exception('Failed to update name');
  }
}
