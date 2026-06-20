import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/google_places_service.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

class LocationPickerResult {
  final ResolvedPlace place;

  const LocationPickerResult({required this.place});
}

class LocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  final String initialAddress;

  const LocationPickerScreen({
    super.key,
    required this.initialLocation,
    this.initialAddress = '',
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final GooglePlacesService _placesService = GooglePlacesService();
  final TextEditingController _searchController = TextEditingController();

  GoogleMapController? _mapController;
  Timer? _searchDebounce;
  LatLng? _selectedLocation;
  ResolvedPlace? _selectedPlace;
  List<PlacePrediction> _predictions = [];
  bool _isSearching = false;
  bool _isResolving = false;
  bool _hasLocationPermission = false;
  bool _missingApiKey = false;

  static const LatLng _fallbackLocation = LatLng(22.5726, 88.3639);

  LatLng get _startLocation {
    if (widget.initialLocation.latitude.abs() > 0.000001 ||
        widget.initialLocation.longitude.abs() > 0.000001) {
      return widget.initialLocation;
    }

    return _fallbackLocation;
  }

  @override
  void initState() {
    super.initState();
    _selectedLocation = _startLocation;
    _searchController.text = widget.initialAddress;
    _missingApiKey = !_placesService.hasApiKey;
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _hasLocationPermission =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final predictions = await _placesService.autocomplete(
        query,
        locationBias: _selectedLocation,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _predictions = predictions;
      });
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isResolving = true;
      _predictions = [];
      _searchController.text = prediction.description;
    });

    try {
      final place = await _placesService.getPlaceDetails(prediction.placeId);
      await _moveTo(place.location, zoom: 17);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLocation = place.location;
        _selectedPlace = place;
      });
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isResolving = true;
    });

    try {
      await _checkLocationPermission();

      if (!_hasLocationPermission) {
        throw Exception('Location permission is required');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final location = LatLng(position.latitude, position.longitude);
      await _resolveLocation(location, moveCamera: true);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  Future<void> _resolveLocation(
    LatLng location, {
    bool moveCamera = false,
  }) async {
    if (moveCamera) {
      await _moveTo(location, zoom: 17);
    }

    setState(() {
      _selectedLocation = location;
      _selectedPlace = null;
    });

    try {
      final place = await _placesService.reverseGeocode(location);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPlace = place;
        if (_searchController.text.trim().isEmpty) {
          _searchController.text = place.formattedAddress;
        }
      });
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _moveTo(LatLng location, {double zoom = 16}) async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: zoom),
      ),
    );
  }

  Future<void> _confirmSelection() async {
    final location = _selectedLocation;
    if (location == null) {
      return;
    }

    setState(() {
      _isResolving = true;
    });

    try {
      final place =
          _selectedPlace ?? await _placesService.reverseGeocode(location);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, LocationPickerResult(place: place));
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedLocation = _selectedLocation ?? _startLocation;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          if (_missingApiKey)
            Container(
              color: const Color(0xFFB71C1C),
              alignment: Alignment.center,
              child: const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Google Maps API key is missing.\n'
                    'Run the app with:\n'
                    '--dart-define=GOOGLE_MAPS_API_KEY=your_key',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            )
          else
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: selectedLocation,
                zoom: 15,
              ),
              myLocationEnabled: _hasLocationPermission,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              markers: {
                Marker(
                  markerId: const MarkerId('selected-location'),
                  position: selectedLocation,
                  draggable: true,
                  onDragEnd: (location) {
                    _resolveLocation(location);
                  },
                ),
              },
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onTap: (location) {
                _resolveLocation(location);
              },
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filled(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: _panel,
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _stroke),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search delivery location',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: _mutedText,
                            ),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _brandRed,
                                      ),
                                    ),
                                  )
                                : null,
                            filled: true,
                            fillColor: _panel,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _stroke),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_predictions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 10, left: 58),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _stroke),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _predictions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: _stroke),
                        itemBuilder: (context, index) {
                          final prediction = _predictions[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.place_rounded,
                              color: _brandRed,
                            ),
                            title: Text(
                              prediction.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () => _selectPrediction(prediction),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 166,
            child: FloatingActionButton.small(
              heroTag: 'current-location',
              onPressed: _isResolving ? null : _useCurrentLocation,
              backgroundColor: _panel,
              foregroundColor: _brandRed,
              child: const Icon(Icons.gps_fixed_rounded),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _stroke),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.42),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedPlace?.formattedAddress ??
                          'Move the pin to your delivery location',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${selectedLocation.latitude.toStringAsFixed(6)}, '
                      '${selectedLocation.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isResolving ? null : _confirmSelection,
                      icon: _isResolving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: const Text('Confirm Location'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
