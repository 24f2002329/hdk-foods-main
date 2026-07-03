import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hdk_core/hdk_core.dart';

/// Lightweight config service for the delivery app.
/// Fetches site-wide settings (kitchen phone, etc.) from the API.
class DeliveryConfigService {
  static final String _base = ApiConfig.baseUrl;

  /// Returns the kitchen phone number from the server config.
  /// Falls back to [fallback] if the request fails or the field is missing.
  static Future<String> getKitchenPhone({
    String fallback = '+918875775282',
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$_base/config/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['kitchen_phone'] as String?)?.trim().isNotEmpty == true
            ? data['kitchen_phone'] as String
            : fallback;
      }
    } catch (_) {}
    return fallback;
  }
}
