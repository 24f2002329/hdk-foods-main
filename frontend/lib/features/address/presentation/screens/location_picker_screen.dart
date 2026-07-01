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

  GoogleMapController? _mapController;
  Timer? _resolveDebounce;
  LatLng? _selectedLocation;
  ResolvedPlace? _selectedPlace;
  bool _isResolving = false;
  bool _hasLocationPermission = false;
  bool _missingApiKey = false;

  // Used only while we wait for GPS on a fresh add (no prior location).
  static const LatLng _worldCenter = LatLng(20.5937, 78.9629); // India centre

  bool get _hasValidInitialLocation =>
      widget.initialLocation.latitude.abs() > 0.000001 ||
      widget.initialLocation.longitude.abs() > 0.000001;

  @override
  void initState() {
    super.initState();
    _missingApiKey = !_placesService.hasApiKey;

    if (_hasValidInitialLocation) {
      // Editing an existing address — start at the saved pin.
      _selectedLocation = widget.initialLocation;
      _checkLocationPermission();
      if (!_missingApiKey) _resolveLocation(widget.initialLocation);
    } else {
      // New address — centre on world temporarily, then jump to GPS.
      _selectedLocation = _worldCenter;
      _checkLocationPermission().then((_) => _useCurrentLocation());
    }
  }

  @override
  void dispose() {
    _resolveDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    setState(() {
      _hasLocationPermission = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    });
    // Return so callers can chain .then((_) => ...).
  }

  void _onMarkerDragEnd(LatLng location) {
    _resolveDebounce?.cancel();
    _resolveDebounce = Timer(const Duration(milliseconds: 400), () {
      _resolveLocation(location);
    });
  }

  Future<void> _resolveLocation(LatLng location, {bool moveCamera = false}) async {
    setState(() {
      _selectedLocation = location;
      _selectedPlace = null;
      _isResolving = true;
    });

    if (moveCamera) {
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 17),
        ),
      );
    }

    try {
      final place = await _placesService.reverseGeocode(location);
      if (!mounted) return;
      setState(() => _selectedPlace = place);
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isResolving = true);
    try {
      await _checkLocationPermission();
      if (!_hasLocationPermission) throw Exception('Location permission is required');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final location = LatLng(position.latitude, position.longitude);
      await _resolveLocation(location, moveCamera: true);
    } catch (e) {
      _showMessage(e.toString());
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _confirmSelection() async {
    final location = _selectedLocation;
    if (location == null) return;

    setState(() => _isResolving = true);
    try {
      final place = _selectedPlace ?? await _placesService.reverseGeocode(location);
      if (!mounted) return;
      Navigator.pop(context, LocationPickerResult(place: place));
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedLocation = _selectedLocation ??
        (_hasValidInitialLocation ? widget.initialLocation : _worldCenter);

    if (_missingApiKey) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          title: const Text('Pick Location'),
          backgroundColor: _surface,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Google Maps API key is missing.\n\nRun the app with:\n--dart-define=GOOGLE_MAPS_API_KEY=your_key',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────
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
                onDragEnd: _onMarkerDragEnd,
              ),
            },
            onMapCreated: (c) => _mapController = c,
            onTap: (location) => _resolveLocation(location),
          ),

          // ── Back + hint bar ──────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _stroke),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_rounded,
                              color: _mutedText, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _isResolving
                                ? 'Finding address…'
                                : 'Tap or drag pin to set location',
                            style: const TextStyle(
                                color: _mutedText, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── GPS button ───────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 166,
            child: FloatingActionButton.small(
              heroTag: 'current-location',
              onPressed: _isResolving ? null : _useCurrentLocation,
              backgroundColor: _panel,
              foregroundColor: _brandRed,
              child: _isResolving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _brandRed),
                    )
                  : const Icon(Icons.gps_fixed_rounded),
            ),
          ),

          // ── Bottom address panel ─────────────────────────────────────
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
                    if (_isResolving)
                      const Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _brandRed),
                          ),
                          SizedBox(width: 10),
                          Text('Resolving address…',
                              style:
                                  TextStyle(color: _mutedText, fontSize: 14)),
                        ],
                      )
                    else
                      Text(
                        _selectedPlace?.formattedAddress.isNotEmpty == true
                            ? _selectedPlace!.formattedAddress
                            : 'Move the pin to your delivery location',
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
                      style: const TextStyle(color: _mutedText, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isResolving ? null : _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Confirm Location',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
