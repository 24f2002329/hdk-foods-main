import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hdk_core/hdk_core.dart';
import '../services/directions_service.dart';
import 'payment_collection_screen.dart';

// ── Theme constants ───────────────────────────────────────────────────────────
const _kRed = Color(0xFFFF1E1E);
const _kSurface = Color(0xFF050505);
const _kPanel = Color(0xDD111111);
const _kStroke = Color(0xFF2A2A2A);
const _kMuted = Color(0xFFB8B8B8);

enum _ArrivalState {
  navigating,
  approaching,
  arrivedManual,
  arrivedAuto,
}

class DeliveryNavigationScreen extends StatefulWidget {
  final Order order;

  const DeliveryNavigationScreen({super.key, required this.order});

  @override
  State<DeliveryNavigationScreen> createState() =>
      _DeliveryNavigationScreenState();
}

class _DeliveryNavigationScreenState
    extends State<DeliveryNavigationScreen>
    with WidgetsBindingObserver {
  // ── Services ────────────────────────────────────────────────────────────────
  final DirectionsService _directionsService = DirectionsService();

  // ── Map ─────────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _destinationIcon;
  BitmapDescriptor? _driverIcon;

  // ── Location stream ─────────────────────────────────────────────────────────
  StreamSubscription<Position>? _positionSub;
  Position? _currentPosition;

  // ── Route state ─────────────────────────────────────────────────────────────
  List<LatLng> _routePoints = [];
  bool _routeLoading = false;
  bool _routeFailed = false;
  bool _fetchingSilently = false;

  // ── Arrival state machine ───────────────────────────────────────────────────
  _ArrivalState _arrivalState = _ArrivalState.navigating;
  bool _arrivedDialogShown = false;

  // ── HUD values ──────────────────────────────────────────────────────────────
  double _distanceMeters = 0;
  int _etaSeconds = 0;
  double _speedKmh = 0;

  // ── Computed destination ────────────────────────────────────────────────────
  LatLng get _destination => LatLng(
        widget.order.address!.latitude!,
        widget.order.address!.longitude!,
      );

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCustomMarkers().then((_) {
      _initMarkers();
    });
    _initLocationStream();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _positionSub?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _initLocationStream();
    }
  }

  Future<void> _loadCustomMarkers() async {
    try {
      final dest = await _getCustomMarker(Icons.home_rounded, const Color(0xFFFF1E1E));
      final driv = await _getCustomMarker(Icons.directions_bike_rounded, Colors.blueAccent);
      if (mounted) {
        setState(() {
          _destinationIcon = dest;
          _driverIcon = driv;
        });
      }
    } catch (_) {}
  }

  Future<BitmapDescriptor> _getCustomMarker(IconData iconData, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Background circle
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(const Offset(40, 40), 38, paint);

    // White border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(const Offset(40, 40), 38, borderPaint);

    // Icon
    final TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 44,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(40 - textPainter.width / 2, 40 - textPainter.height / 2));

    final ui.Image image = await pictureRecorder.endRecording().toImage(80, 80);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  Future<void> _launchNativeNavigation() async {
    final lat = _destination.latitude;
    final lng = _destination.longitude;
    final googleMapsUrl = 'google.navigation:q=$lat,$lng&mode=d';
    final fallbackUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl));
      } else {
        await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
    }
  }

  void _fitMapBounds() {
    if (_mapController == null) return;

    final dest = _destination;
    final pos = _currentPosition;

    if (pos != null) {
      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          pos.latitude < dest.latitude ? pos.latitude : dest.latitude,
          pos.longitude < dest.longitude ? pos.longitude : dest.longitude,
        ),
        northeast: LatLng(
          pos.latitude > dest.latitude ? pos.latitude : dest.latitude,
          pos.longitude > dest.longitude ? pos.longitude : dest.longitude,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
    } else {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(dest),
      );
    }
  }

  // ── Initialisation ──────────────────────────────────────────────────────────

  void _initMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('destination'),
        position: _destination,
        icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: widget.order.address?.label.isNotEmpty == true
              ? widget.order.address!.label
              : 'Delivery Address',
          snippet: widget.order.address?.lineOne,
        ),
      ),
    };
  }

  Future<void> _initLocationStream() async {
    final granted = await _requestPermission();
    if (!granted || !mounted) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showGpsDisabledDialog();
      return;
    }

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(
      _onPositionUpdate,
      onError: (e) {
        if (mounted) _showSnack('Location error: $e');
      },
    );
  }

  Future<bool> _requestPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (mounted) _showPermissionDeniedDialog();
      return false;
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  // ── Position updates ────────────────────────────────────────────────────────

  void _onPositionUpdate(Position pos) {
    if (!mounted) return;

    final driverLatLng = LatLng(pos.latitude, pos.longitude);
    final dist = DirectionsService.distanceBetween(driverLatLng, _destination);
    final speedMs = pos.speed < 0 ? 0.0 : pos.speed;

    // ETA: use measured speed or fall back to 30 km/h
    final effectiveSpeedMs = speedMs < (30 / 3.6) ? (30 / 3.6) : speedMs;
    final eta = (dist / effectiveSpeedMs).round();

    setState(() {
      _currentPosition = pos;
      _speedKmh = speedMs * 3.6;
      _distanceMeters = dist;
      _etaSeconds = eta;

      // Driver marker
      _markers = {
        ..._markers
            .where((m) => m.markerId.value != 'driver'),
        Marker(
          markerId: const MarkerId('driver'),
          position: driverLatLng,
          icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      };
    });

    // Camera follows driver
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(driverLatLng),
    );

    // Fetch initial route once we have a fix
    if (_routePoints.isEmpty && !_routeLoading && !_routeFailed) {
      _fetchRoute();
    }

    // Deviation check — recalculate if > 100m from route
    if (_routePoints.isNotEmpty) {
      final nearestDist = _distanceToNearestRoutePoint(driverLatLng);
      if (nearestDist > 100) {
        _fetchRoute(silent: true);
      }
    }

    // Arrival state machine
    _updateArrivalState(dist, pos.accuracy);
  }

  // ── Route fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchRoute({bool silent = false}) async {
    if (_routeLoading) return;
    final pos = _currentPosition;
    if (pos == null) return;

    if (!silent) setState(() => _routeLoading = true);
    _fetchingSilently = silent;

    const maxAttempts = 3;
    const delays = [0, 2, 4];

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: delays[attempt]));
      }
      if (!mounted) return;

      try {
        final origin = LatLng(pos.latitude, pos.longitude);
        final result = await _directionsService.getRoute(
          origin: origin,
          destination: _destination,
        );

        if (!mounted) return;

        if (result == null) {
          _showSnack('No route found — navigate manually');
          setState(() {
            _routeLoading = false;
            _routeFailed = true;
          });
          return;
        }

        setState(() {
          _routePoints = result.polylinePoints;
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: result.polylinePoints,
              color: Colors.blueAccent,
              width: 5,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          };
          _routeLoading = false;
          _routeFailed = false;
        });
        _fitMapBounds();
        return;
      } catch (e) {
        if (attempt == maxAttempts - 1) {
          if (!mounted) return;
          _showSnack('Route unavailable — navigate manually');
          setState(() {
            _routeLoading = false;
            _routeFailed = true;
          });
        }
      }
    }
  }

  // ── Route helpers ───────────────────────────────────────────────────────────

  double _distanceToNearestRoutePoint(LatLng driver) {
    if (_routePoints.isEmpty) return double.infinity;
    return _routePoints
        .map((p) => DirectionsService.distanceBetween(driver, p))
        .reduce(math.min);
  }

  // ── Arrival state machine ───────────────────────────────────────────────────

  void _updateArrivalState(double dist, double accuracy) {
    final newState = _computeArrivalState(dist, accuracy);
    if (newState == _arrivalState) return;

    // Only advance — no rollback
    if (newState.index < _arrivalState.index) return;

    setState(() => _arrivalState = newState);

    if (newState == _ArrivalState.arrivedAuto && !_arrivedDialogShown) {
      _arrivedDialogShown = true;
      _positionSub?.cancel();
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showArrivedDialog());
    }
  }

  _ArrivalState _computeArrivalState(double dist, double accuracy) {
    if (dist > 30) return _ArrivalState.navigating;
    if (dist > 15) return _ArrivalState.approaching;
    if (accuracy <= 10) return _ArrivalState.arrivedAuto;
    return _ArrivalState.arrivedManual;
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  void _showArrivedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 48),
            SizedBox(height: 12),
            Text(
              "You've Arrived!",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20),
            ),
          ],
        ),
        content: Text(
          'You have reached ${widget.order.address?.lineOne ?? "the delivery address"}.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB8B8B8)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black87,
              minimumSize: const Size(200, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _goToPayment();
            },
            child: const Text('Collect Payment',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmDialog() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Stop Navigation?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your delivery is in progress. Are you sure you want to leave?',
          style: TextStyle(color: Color(0xFFB8B8B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay',
                style: TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              Navigator.pop(context);
            },
            child: const Text('Leave',
                style: TextStyle(color: Color(0xFFFF1E1E))),
          ),
        ],
      ),
    );
  }

  void _showGpsDisabledDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('GPS Disabled',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Please enable location services to use navigation.',
          style: TextStyle(color: Color(0xFFB8B8B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Location Permission Required',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'HDK Delivery needs location permission for in-app navigation. '
          'Please grant it in app settings.',
          style: TextStyle(color: Color(0xFFB8B8B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _goToPayment() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PaymentCollectionScreen(order: widget.order),
      ),
    );
  }

  void _onManualArrival() {
    _positionSub?.cancel();
    _showArrivedDialog();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatEta(int seconds) {
    if (seconds < 60) return '< 1 min';
    final mins = (seconds / 60).ceil();
    if (mins < 60) return '~$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '~${h}h ${m}m';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasAddress = widget.order.address?.latitude != null &&
        widget.order.address?.longitude != null;

    if (!hasAddress) {
      return Scaffold(
        backgroundColor: _kSurface,
        appBar: AppBar(
          title: const Text('Navigation'),
          backgroundColor: _kSurface,
        ),
        body: const Center(
          child: Text(
            'Delivery address has no GPS coordinates.\n'
            'Please use the manual navigation option.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirmDialog();
      },
      child: Scaffold(
        backgroundColor: _kSurface,
        body: Stack(
          children: [
            // ── Map ─────────────────────────────────────────────────────
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _destination,
                zoom: 15,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (c) {
                _mapController = c;
                Future.delayed(const Duration(milliseconds: 200), () {
                  _fitMapBounds();
                });
              },
            ),

            // ── Route loading spinner ────────────────────────────────────
            if (_routeLoading && !_fetchingSilently)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kPanel,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.blueAccent),
                        ),
                        SizedBox(width: 8),
                        Text('Calculating route…',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Back button ──────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton.filled(
                  onPressed: _showExitConfirmDialog,
                  style: IconButton.styleFrom(
                    backgroundColor: _kPanel,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
            ),

            // ── Re-center button ──────────────────────────────────────────
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton.filled(
                    onPressed: _fitMapBounds,
                    style: IconButton.styleFrom(
                      backgroundColor: _kPanel,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.center_focus_strong_rounded),
                  ),
                ),
              ),
            ),

            // ── Approaching banner ───────────────────────────────────────
            if (_arrivalState == _ArrivalState.approaching)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(60, 0, 12, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orangeAccent
                                .withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              color: Colors.black87, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You are approaching the delivery location.',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Bottom HUD ───────────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomHud(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomHud() {
    final isManualArrival =
        _arrivalState == _ArrivalState.arrivedManual;

    return Container(
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: _kStroke)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _kStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Metrics row
              if (_currentPosition != null)
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: [
                    _MetricChip(
                      icon: Icons.route_rounded,
                      label: 'Distance',
                      value: _formatDistance(_distanceMeters),
                      color: Colors.blueAccent,
                    ),
                    _MetricChip(
                      icon: Icons.schedule_rounded,
                      label: 'ETA',
                      value: _formatEta(_etaSeconds),
                      color: Colors.greenAccent,
                    ),
                    _MetricChip(
                      icon: Icons.speed_rounded,
                      label: 'Speed',
                      value:
                          '${_speedKmh.toStringAsFixed(0)} km/h',
                      color: Colors.amberAccent,
                    ),
                  ],
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kRed),
                      ),
                      SizedBox(width: 10),
                      Text('Waiting for GPS…',
                          style: TextStyle(
                              color: _kMuted, fontSize: 14)),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Address label
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: _kRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.order.address?.lineOne ??
                            'Delivery address',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _launchNativeNavigation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_rounded, color: Colors.blueAccent, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Open Maps',
                              style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // I've Arrived button — prominent when arrivedManual
              if (isManualArrival)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black87,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text(
                      "I've Arrived",
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16),
                    ),
                    onPressed: _onManualArrival,
                  ),
                )
              else
                TextButton.icon(
                  onPressed: _onManualArrival,
                  icon: const Icon(Icons.flag_rounded,
                      color: _kMuted, size: 16),
                  label: const Text(
                    "I've Arrived",
                    style: TextStyle(color: _kMuted, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Metric chip ───────────────────────────────────────────────────────────────
class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
