import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:hdk_core/hdk_core.dart';

class LocationTrackingService {
  final int orderId;
  bool _isRunning = false;

  LocationTrackingService({required this.orderId});

  Future<bool> _ensurePermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  Future<void> _postLocation({
    required bool heartbeat,
    required Position pos,
  }) async {
    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null) return;

      final body = heartbeat
          ? {'heartbeat': true}
          : {'latitude': pos.latitude, 'longitude': pos.longitude};

      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/delivery-location/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    } catch (_) {}
  }

  Future<void> start() async {
    final granted = await _ensurePermission();
    if (!granted) return;

    _isRunning = true;
    _runLoop();
  }

  Future<void> _runLoop() async {
    while (_isRunning) {
      double speed = 0.0;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        speed = pos.speed; // speed is in meters/second

        // Speed conversion: 15 km/h = 4.167 m/s
        // Driving (> 15 km/h, i.e., > 4.167 m/s): Send every 10s
        // Walking/slow (< 15 km/h, i.e., <= 4.167 m/s but > 0.1 m/s): Send every 20s
        // Stationary (<= 0.1 m/s): Send heartbeat every 60s
        bool isStationary = speed <= 0.1;

        await _postLocation(heartbeat: isStationary, pos: pos);
      } catch (_) {}

      Duration delay;
      if (speed > 4.167) {
        delay = const Duration(seconds: 10);
      } else if (speed > 0.1) {
        delay = const Duration(seconds: 20);
      } else {
        delay = const Duration(seconds: 60);
      }

      await Future.delayed(delay);
    }
  }

  void stop() {
    _isRunning = false;
  }
}
