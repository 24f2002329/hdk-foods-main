import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:hdk_core/hdk_core.dart';

class SiteConfig {
  final String announcement;
  final bool isStoreOpen;
  final String storeOpenTime;
  final String storeCloseTime;
  final String storeClosedMsg;
  final bool showRatings;
  final int loyaltyCoinsPercentage;
  final String kitchenName;
  final double kitchenLat;
  final double kitchenLng;
  final String kitchenPhone;

  const SiteConfig({
    this.announcement = '',
    this.isStoreOpen = true,
    this.storeOpenTime = '08:00:00',
    this.storeCloseTime = '22:00:00',
    this.storeClosedMsg = "We're closed right now. See you soon!",
    this.showRatings = true,
    this.loyaltyCoinsPercentage = 10,
    this.kitchenName = 'HDK Foods Kitchen',
    this.kitchenLat = 25.861067,
    this.kitchenLng = 73.749343,
    this.kitchenPhone = '+918875775282',
  });

  factory SiteConfig.fromJson(Map<String, dynamic> json) => SiteConfig(
    announcement: json['announcement'] ?? '',
    isStoreOpen: json['is_store_open'] ?? true,
    storeOpenTime: json['store_open_time'] ?? '08:00:00',
    storeCloseTime: json['store_close_time'] ?? '22:00:00',
    storeClosedMsg: json['store_closed_msg'] ?? "We're closed right now.",
    showRatings: json['show_ratings'] ?? true,
    loyaltyCoinsPercentage: json['loyalty_coins_percentage'] ?? 10,
    kitchenName: json['kitchen_name'] ?? 'HDK Foods Kitchen',
    kitchenLat:
        double.tryParse(json['kitchen_latitude']?.toString() ?? '') ??
        25.861067,
    kitchenLng:
        double.tryParse(json['kitchen_longitude']?.toString() ?? '') ??
        73.749343,
    kitchenPhone: json['kitchen_phone'] ?? '+918875775282',
  );

  bool get isCurrentlyOpen {
    if (!isStoreOpen) return false;
    try {
      final now = DateTime.now();
      final open = _parseTime(storeOpenTime, now);
      final close = _parseTime(storeCloseTime, now);
      return now.isAfter(open) && now.isBefore(close);
    } catch (_) {
      return isStoreOpen;
    }
  }

  String get formattedOpenTime {
    try {
      final parts = storeOpenTime.split(':');
      final h = int.parse(parts[0]);
      final m = parts[1];
      final period = h >= 12 ? 'PM' : 'AM';
      final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$hour:$m $period';
    } catch (_) {
      return storeOpenTime;
    }
  }

  String get formattedCloseTime {
    try {
      final parts = storeCloseTime.split(':');
      final h = int.parse(parts[0]);
      final m = parts[1];
      final period = h >= 12 ? 'PM' : 'AM';
      final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$hour:$m $period';
    } catch (_) {
      return storeCloseTime;
    }
  }

  DateTime _parseTime(String t, DateTime ref) {
    final parts = t.split(':');
    return DateTime(
      ref.year,
      ref.month,
      ref.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}

class AppBanner {
  final int id;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String linkAction;

  const AppBanner({
    required this.id,
    required this.imageUrl,
    this.title = '',
    this.subtitle = '',
    this.linkAction = '',
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) => AppBanner(
    id: json['id'],
    imageUrl: json['image_url'] ?? '',
    title: json['title'] ?? '',
    subtitle: json['subtitle'] ?? '',
    linkAction: json['link_action'] ?? '',
  );
}

class ConfigService {
  static final String _base = ApiConfig.baseUrl;

  Future<SiteConfig> getConfig({bool fromCache = false}) async {
    if (fromCache) {
      final cached = await LocalCache.getJson('cached_site_config');
      if (cached != null) {
        return SiteConfig.fromJson(cached);
      }
      return const SiteConfig();
    }

    try {
      final response = await http
          .get(Uri.parse('$_base/config/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await LocalCache.setJson('cached_site_config', data);
        return SiteConfig.fromJson(data);
      }
    } catch (_) {
      final cached = await LocalCache.getJson('cached_site_config');
      if (cached != null) {
        return SiteConfig.fromJson(cached);
      }
    }
    return const SiteConfig();
  }

  Future<List<AppBanner>> getBanners({bool fromCache = false}) async {
    if (fromCache) {
      final cached = await LocalCache.getJson('cached_app_banners');
      if (cached != null && cached is List) {
        return cached.map((e) => AppBanner.fromJson(e)).toList();
      }
      return [];
    }

    try {
      final response = await http
          .get(Uri.parse('$_base/config/banners/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        await LocalCache.setJson('cached_app_banners', list);
        return list.map((e) => AppBanner.fromJson(e)).toList();
      }
    } catch (_) {
      final cached = await LocalCache.getJson('cached_app_banners');
      if (cached != null && cached is List) {
        return cached.map((e) => AppBanner.fromJson(e)).toList();
      }
    }
    return [];
  }
}
