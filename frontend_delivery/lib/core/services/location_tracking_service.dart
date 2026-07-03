import 'dart:async';
import 'package:geolocator/geolocator.dart';
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
      final body = heartbeat
          ? {'heartbeat': true}
          : {'latitude': pos.latitude, 'longitude': pos.longitude};

      await ApiClient().post('orders/$orderId/delivery-location/', body);
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
      if (speed > 0.1) {
        delay = const Duration(seconds: 5);
      } else {
        delay = const Duration(seconds: 30);
      }
      await Future.delayed(delay);
    }
  }

  void stop() {
    _isRunning = false;
  }
}
