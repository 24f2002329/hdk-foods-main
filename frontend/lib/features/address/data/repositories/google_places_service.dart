import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class GooglePlacesService {
  GooglePlacesService({http.Client? client})
      : _client = client ?? http.Client();

  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String _geocodeBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  final http.Client _client;

  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  Future<ResolvedPlace> reverseGeocode(LatLng location) async {
    _ensureApiKey();

    final uri = Uri.parse(_geocodeBaseUrl).replace(
      queryParameters: {
        'latlng': '${location.latitude},${location.longitude}',
        'key': _apiKey,
        'language': 'en',
        'region': 'in',
      },
    );

    final response = await _client.get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final status = data['status']?.toString() ?? '';
    if (status != 'OK') {
      throw Exception(data['error_message'] ?? 'Could not resolve address');
    }

    final results = data['results'] as List? ?? [];
    if (results.isEmpty) {
      throw Exception('No address found for this location');
    }

    return ResolvedPlace.fromGeocodeJson(results.first, location);
  }

  void _ensureApiKey() {
    if (!hasApiKey) {
      throw Exception(
        'Missing GOOGLE_MAPS_API_KEY. Run with '
        '--dart-define=GOOGLE_MAPS_API_KEY=your_key',
      );
    }
  }
}

class ResolvedPlace {
  final String formattedAddress;
  final String street;
  final String landmark;
  final String city;
  final String pincode;
  final LatLng location;

  const ResolvedPlace({
    required this.formattedAddress,
    required this.street,
    required this.landmark,
    required this.city,
    required this.pincode,
    required this.location,
  });

  factory ResolvedPlace.fromGeocodeJson(
    Map<String, dynamic> json,
    LatLng fallbackLocation,
  ) {
    final locationMap =
        (json['geometry'] as Map<String, dynamic>?)?['location']
            as Map<String, dynamic>?;
    final components = json['address_components'] as List? ?? [];

    String byType(String type) {
      for (final c in components.whereType<Map<String, dynamic>>()) {
        final types = (c['types'] as List? ?? []).map((t) => t.toString());
        if (types.contains(type)) return c['long_name']?.toString() ?? '';
      }
      return '';
    }

    final route = byType('route');
    final sublocality = byType('sublocality_level_1').isNotEmpty
        ? byType('sublocality_level_1')
        : byType('sublocality');
    final neighborhood = byType('neighborhood');
    final city = byType('locality').isNotEmpty
        ? byType('locality')
        : byType('administrative_area_level_3');
    final pincode = byType('postal_code');
    final street = [route, sublocality, neighborhood]
        .where((p) => p.trim().isNotEmpty)
        .join(', ');

    final lat = _toDouble(locationMap?['lat'],
        fallback: fallbackLocation.latitude);
    final lng = _toDouble(locationMap?['lng'],
        fallback: fallbackLocation.longitude);

    return ResolvedPlace(
      formattedAddress: json['formatted_address']?.toString() ?? '',
      street: street.isNotEmpty ? street : json['formatted_address'] ?? '',
      landmark: '',
      city: city,
      pincode: pincode,
      location: LatLng(lat, lng),
    );
  }

  static double _toDouble(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
