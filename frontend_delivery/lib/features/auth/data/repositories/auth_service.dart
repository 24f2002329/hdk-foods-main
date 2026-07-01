import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:hdk_core/hdk_core.dart';

class AuthService {
  static final String _baseUrl = "${ApiConfig.baseUrl}/auth";

  /// Login with phone number + password (staff-only, no Firebase OTP).
  Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/staff-login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await TokenStorage.saveTokens(
        access: data['access'],
        refresh: data['refresh'],
        role: data['role'],
      );
      return data;
    }

    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Login failed');
  }

  /// Fetch the current user's profile (id, name, phone_number, role).
  Future<Map<String, dynamic>> me() async {
    final token = await TokenStorage.getAccessToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/me/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load profile');
  }
}
