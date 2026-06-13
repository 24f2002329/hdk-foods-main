import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class GooglePlacesService {
  GooglePlacesService({http.Client? client})
    : _client = client ?? http.Client();

  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String _placesBaseUrl = 'https://places.googleapis.com/v1';
  static const String _geocodeBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  final http.Client _client;

  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? locationBias,
  }) async {
    _ensureApiKey();

    final query = input.trim();
    if (query.length < 3) {
      return [];
    }

    final body = <String, dynamic>{
      'input': query,
      'includedRegionCodes': ['in'],
      'languageCode': 'en',
      'regionCode': 'in',
    };

    if (locationBias != null) {
      body['locationBias'] = {
        'circle': {
          'center': {
            'latitude': locationBias.latitude,
            'longitude': locationBias.longitude,
          },
          'radius': 15000.0,
        },
      };
    }

    final response = await _client.post(
      Uri.parse('$_placesBaseUrl/places:autocomplete'),
      headers: const {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'suggestions.placePrediction.placeId,'
            'suggestions.placePrediction.text.text',
      },
      body: jsonEncode(body),
    );

    final data = _decodeResponse(response);
    final suggestions = data['suggestions'] as List? ?? [];

    return suggestions
        .map((item) => item['placePrediction'])
        .whereType<Map<String, dynamic>>()
        .map(PlacePrediction.fromJson)
        .where((prediction) => prediction.placeId.isNotEmpty)
        .toList();
  }

  Future<ResolvedPlace> getPlaceDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    _ensureApiKey();

    final queryParameters = {'languageCode': 'en', 'regionCode': 'in'};

    if (sessionToken != null) {
      queryParameters['sessionToken'] = sessionToken;
    }

    final uri = Uri.parse(
      '$_placesBaseUrl/places/$placeId',
    ).replace(queryParameters: queryParameters);

    final response = await _client.get(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'id,formattedAddress,location,addressComponents,displayName',
      },
    );

    return ResolvedPlace.fromPlacesJson(_decodeResponse(response));
  }

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
    final data = _decodeResponse(response);
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

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final error = data['error'];
    if (error is Map<String, dynamic>) {
      throw Exception(error['message'] ?? 'Google Maps request failed');
    }

    throw Exception('Google Maps request failed');
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

class PlacePrediction {
  final String placeId;
  final String description;

  const PlacePrediction({required this.placeId, required this.description});

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as Map<String, dynamic>? ?? {};

    return PlacePrediction(
      placeId: json['placeId']?.toString() ?? '',
      description: text['text']?.toString() ?? '',
    );
  }
}

class ResolvedPlace {
  final String name;
  final String formattedAddress;
  final String street;
  final String landmark;
  final String city;
  final String pincode;
  final LatLng location;

  const ResolvedPlace({
    required this.name,
    required this.formattedAddress,
    required this.street,
    required this.landmark,
    required this.city,
    required this.pincode,
    required this.location,
  });

  factory ResolvedPlace.fromPlacesJson(Map<String, dynamic> json) {
    final displayName = json['displayName'] as Map<String, dynamic>? ?? {};
    final location = json['location'] as Map<String, dynamic>? ?? {};
    final components = json['addressComponents'] as List? ?? [];

    return ResolvedPlace._fromComponents(
      name: displayName['text']?.toString() ?? '',
      formattedAddress: json['formattedAddress']?.toString() ?? '',
      latitude: _toDouble(location['latitude']),
      longitude: _toDouble(location['longitude']),
      components: components.whereType<Map<String, dynamic>>().toList(),
      longTextKey: 'longText',
    );
  }

  factory ResolvedPlace.fromGeocodeJson(
    Map<String, dynamic> json,
    LatLng fallbackLocation,
  ) {
    final location =
        (json['geometry'] as Map<String, dynamic>?)?['location']
            as Map<String, dynamic>?;
    final components = json['address_components'] as List? ?? [];

    return ResolvedPlace._fromComponents(
      name: '',
      formattedAddress: json['formatted_address']?.toString() ?? '',
      latitude: _toDouble(
        location?['lat'],
        fallback: fallbackLocation.latitude,
      ),
      longitude: _toDouble(
        location?['lng'],
        fallback: fallbackLocation.longitude,
      ),
      components: components.whereType<Map<String, dynamic>>().toList(),
      longTextKey: 'long_name',
    );
  }

  factory ResolvedPlace._fromComponents({
    required String name,
    required String formattedAddress,
    required double latitude,
    required double longitude,
    required List<Map<String, dynamic>> components,
    required String longTextKey,
  }) {
    String byType(String type) {
      for (final component in components) {
        final types = component['types'] as List? ?? [];
        if (types.map((item) => item.toString()).contains(type)) {
          return component[longTextKey]?.toString() ?? '';
        }
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
    final street = [
      route,
      sublocality,
      neighborhood,
    ].where((part) => part.trim().isNotEmpty).join(', ');

    return ResolvedPlace(
      name: name,
      formattedAddress: formattedAddress,
      street: street.isNotEmpty ? street : formattedAddress,
      landmark: name,
      city: city,
      pincode: pincode,
      location: LatLng(latitude, longitude),
    );
  }

  static double _toDouble(Object? value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
