import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';

class UserService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch the current authenticated user's profile.
  Future<User> getCurrentUser({bool fromCache = false}) async {
    if (fromCache) {
      final cached = await LocalCache.getJson('cached_user_profile');
      if (cached != null) {
        return User.fromJson(cached);
      }
      throw Exception('No cached user profile');
    }

    try {
      final response = await _apiClient.get('me/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await LocalCache.setJson('cached_user_profile', data);
        return User.fromJson(data);
      }
    } catch (_) {
      final cached = await LocalCache.getJson('cached_user_profile');
      if (cached != null) {
        return User.fromJson(cached);
      }
    }

    throw Exception('Failed to load user profile');
  }

  /// Update the current user's name.
  Future<User> updateName(String name) async {
    final response = await _apiClient.patch('me/', {'name': name});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await LocalCache.setJson('cached_user_profile', data);
      return User.fromJson(data);
    }

    throw Exception('Failed to update name');
  }

  /// Fetch the coin transactions for the current user.
  Future<Map<String, dynamic>> getCoinTransactions() async {
    final response = await _apiClient.get('me/coins/transactions/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['transactions'] as List?;
      final transactions = list
          ?.map((x) => CoinTransaction.fromJson(x as Map<String, dynamic>))
          .toList() ??
          [];
      return {
        'loyalty_coins': data['loyalty_coins'] ?? 0,
        'transactions': transactions,
      };
    }

    throw Exception('Failed to load coin transactions');
  }
}
