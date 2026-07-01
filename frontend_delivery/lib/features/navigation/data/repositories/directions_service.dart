import 'dart:convert';
import 'dart:io';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RouteResult {
  final List<LatLng> polylinePoints;
  final double distanceMeters;
  final int durationSeconds;

  const RouteResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class DirectionsService {
  static const String _apiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  final http.Client _client;
  DirectionsService({http.Client? client})
      : _client = client ?? http.Client();

  /// Fetches a driving route from [origin] to [destination].
  /// Returns null if no route exists (ZERO_RESULTS / NOT_FOUND).
  /// Throws [SocketException] or [Exception] on network/API errors.
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination':
            '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': _apiKey,
      },
    );

    final response = await _client.get(uri).timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Directions API error ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String? ?? '';

    if (status == 'ZERO_RESULTS' || status == 'NOT_FOUND') {
      return null;
    }

    if (status != 'OK') {
      throw Exception('Directions API: $status — '
          '${data['error_message'] ?? ''}');
    }

    final routes = data['routes'] as List? ?? [];
    if (routes.isEmpty) return null;

    final legs = (routes.first as Map)['legs'] as List? ?? [];
    if (legs.isEmpty) return null;

    final leg = legs.first as Map<String, dynamic>;
    final distanceMeters =
        ((leg['distance'] as Map?)?['value'] as num?)?.toDouble() ?? 0;
    final durationSeconds =
        ((leg['duration'] as Map?)?['value'] as num?)?.toInt() ?? 0;

    final encodedPolyline =
        ((routes.first as Map)['overview_polyline']
                    as Map?)?['points'] as String? ??
            '';

    final points = PolylinePoints()
        .decodePolyline(encodedPolyline)
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    return RouteResult(
      polylinePoints: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  /// Straight-line distance in metres between two coordinates.
  static double distanceBetween(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(
          a.latitude, a.longitude, b.latitude, b.longitude);
}
