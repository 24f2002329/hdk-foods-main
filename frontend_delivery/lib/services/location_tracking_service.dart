import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/storage/token_storage.dart';

class LocationTrackingService {
  Timer? _timer;
  final int orderId;

  LocationTrackingService({required this.orderId});

  Future<bool> _ensurePermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  Future<void> _postLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final token = await TokenStorage.getAccessToken();
      if (token == null) return;

      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/delivery-location/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        }),
      );
    } catch (_) {}
  }

  Future<void> start() async {
    final granted = await _ensurePermission();
    if (!granted) return;

    await _postLocation();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _postLocation());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
