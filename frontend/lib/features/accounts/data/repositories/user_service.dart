import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';

class UserService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch the current authenticated user's profile.
  Future<User> getCurrentUser() async {
    final response = await _apiClient.get('me/');

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw Exception('Failed to load user profile');
  }

  /// Update the current user's name.
  Future<User> updateName(String name) async {
    final response = await _apiClient.patch('me/', {'name': name});

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw Exception('Failed to update name');
  }
}
