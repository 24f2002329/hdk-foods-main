import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';

class KitchenConfig {
  final String name;
  final double latitude;
  final double longitude;

  const KitchenConfig({
    this.name = 'HDK Foods Kitchen',
    this.latitude = 25.861067,
    this.longitude = 73.749343,
  });

  factory KitchenConfig.fromJson(Map<String, dynamic> json) => KitchenConfig(
        name: json['kitchen_name'] ?? 'HDK Foods Kitchen',
        latitude: double.tryParse(json['kitchen_latitude']?.toString() ?? '') ?? 25.861067,
        longitude: double.tryParse(json['kitchen_longitude']?.toString() ?? '') ?? 73.749343,
      );
}

class DeliveryConfigService {
  static KitchenConfig? _cached;

  /// Fetches kitchen config from the public SiteConfig endpoint.
  /// Returns cached value if already loaded.
  static Future<KitchenConfig> getKitchenConfig() async {
    if (_cached != null) return _cached!;
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/config/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _cached = KitchenConfig.fromJson(jsonDecode(response.body));
        return _cached!;
      }
    } catch (_) {}
    return const KitchenConfig();
  }
}
