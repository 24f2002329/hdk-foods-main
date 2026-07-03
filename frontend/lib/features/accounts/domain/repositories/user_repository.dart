import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';

abstract class UserRepository {
  static UserRepository? _instance;
  static UserRepository get instance => _instance ??= HttpUserRepository();
  static set instance(UserRepository value) => _instance = value;

  Future<User> getCurrentUser({bool fromCache = false});
  Future<User> updateName(String name);
  Future<Map<String, dynamic>> getCoinTransactions();
}

class HttpUserRepository implements UserRepository {
  final ApiClient _apiClient = ApiClient();

  @override
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

  @override
  Future<User> updateName(String name) async {
    final response = await _apiClient.patch('me/', {'name': name});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await LocalCache.setJson('cached_user_profile', data);
      return User.fromJson(data);
    }

    throw Exception('Failed to update name');
  }

  @override
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
