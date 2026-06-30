import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import Google Maps only if supported (compiled on all platforms, but only used on web/mobile)
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/order_websocket_service.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/hdk_preloader.dart';
import '../../delivery_staff/models/delivery_staff.dart';
import '../../delivery_staff/services/delivery_staff_service.dart';
import '../../settings/services/config_service.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import 'admin_order_detail_screen.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final OrderService _orderSvc = OrderService();
  final DeliveryStaffService _deliverySvc = DeliveryStaffService();

  List<Order> _orders = [];
  List<DeliveryStaff> _drivers = [];
  bool _loading = true;
  String? _error;

  Timer? _pollTimer;
  AdminOrderWebSocketService? _ws;
  bool _isBusy = false;

  // Multi-select for batch assignment
  final Set<int> _selectedOrderIds = {};
  bool _assignPanelOpen = false;

  // Kitchen location — loaded from SiteConfig, defaults to Sojat Road
  LatLng _kitchenLocation = const LatLng(25.861067, 73.749343);
  String _kitchenName = 'HDK Foods Kitchen';

  // Map state
  GoogleMapController? _mapController;
  final Set<Marker> _googleMarkers = {};
  final Set<Polyline> _googlePolylines = {};

  // Sidebar collapse state
  bool _sidebarCollapsed = false;

  // For Desktop Radar simulation: relative positions of drivers/customers
  final List<_SimulatedEntity> _simulatedEntities = [];
  double _radarAngle = 0.0;
  Timer? _radarAnimationTimer;

  bool get _useGoogleMap =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _loadKitchenConfig();
    _loadData();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadData(silent: true),
    );

    // Connect WebSocket
    _ws = AdminOrderWebSocketService();
    _ws!.connect();
    _ws!.stream.listen((msg) {
      if (msg['type'] == 'new_order' ||
          msg['type'] == 'order_update' ||
          msg['type'] == 'location_update') {
        _loadData(silent: true);
      }
    });

    if (!_useGoogleMap) {
      _startRadarAnimation();
    }
  }

  Future<void> _loadKitchenConfig() async {
    try {
      final data = await AdminConfigService().getConfig();
      if (mounted) {
        setState(() {
          _kitchenName = data['kitchen_name'] as String? ?? 'HDK Foods Kitchen';
          final lat =
              double.tryParse(data['kitchen_latitude']?.toString() ?? '') ??
              25.861067;
          final lng =
              double.tryParse(data['kitchen_longitude']?.toString() ?? '') ??
              73.749343;
          _kitchenLocation = LatLng(lat, lng);
        });
        _syncMapMarkers();
        _mapController?.animateCamera(CameraUpdate.newLatLng(_kitchenLocation));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ws?.dispose();
    _radarAnimationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startRadarAnimation() {
    _radarAnimationTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (mounted) {
        setState(() {
          _radarAngle = (_radarAngle + 0.03) % (2 * math.pi);
          // Gently move active simulated drivers to mimic traffic movement
          for (var entity in _simulatedEntities) {
            if (entity.isDriver && entity.isActiveTrip) {
              entity.moveTowardsDestination();
            }
          }
        });
      }
    });
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final allOrders = await _orderSvc.getAllOrders();
      final allDrivers = await _deliverySvc.getDeliveryStaff();

      if (mounted) {
        setState(() {
          // Unassigned queue: only 'preparing' (food is being made) + active out_for_delivery trips
          _orders = allOrders
              .where(
                (o) => ['preparing', 'out_for_delivery'].contains(o.status),
              )
              .toList();
          _drivers = allDrivers;

          _syncMapMarkers();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _syncMapMarkers() {
    if (_useGoogleMap) {
      _googleMarkers.clear();
      _googlePolylines.clear();

      // 1. Kitchen Marker
      _googleMarkers.add(
        Marker(
          markerId: const MarkerId('kitchen'),
          position: _kitchenLocation,
          infoWindow: InfoWindow(title: _kitchenName),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      // 2. Active Trips and Deliveries
      for (var order in _orders) {
        final destLat =
            order.address?.latitude ?? _kitchenLocation.latitude + 0.01;
        final destLng =
            order.address?.longitude ?? _kitchenLocation.longitude + 0.01;
        final dest = LatLng(destLat, destLng);

        if (order.status == 'out_for_delivery') {
          // Driver Marker (Green/Orange based on status)
          final driverLat = order.deliveryLatitude ?? _kitchenLocation.latitude;
          final driverLng =
              order.deliveryLongitude ?? _kitchenLocation.longitude;
          final driverLoc = LatLng(driverLat, driverLng);

          _googleMarkers.add(
            Marker(
              markerId: MarkerId('driver_${order.id}'),
              position: driverLoc,
              infoWindow: InfoWindow(title: 'Driver for #${order.orderNumber}'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
          );

          // Customer Pin
          _googleMarkers.add(
            Marker(
              markerId: MarkerId('cust_${order.id}'),
              position: dest,
              infoWindow: InfoWindow(
                title: 'Delivery for #${order.orderNumber}',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
            ),
          );

          // Path Line
          _googlePolylines.add(
            Polyline(
              polylineId: PolylineId('path_${order.id}'),
              points: [_kitchenLocation, driverLoc, dest],
              color: Colors.blueAccent,
              width: 3,
            ),
          );
        } else {
          // Unassigned Orders on Map (Yellow)
          _googleMarkers.add(
            Marker(
              markerId: MarkerId('unassigned_${order.id}'),
              position: dest,
              infoWindow: InfoWindow(
                title: 'Unassigned Order #${order.orderNumber}',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow,
              ),
            ),
          );
        }
      }
    } else {
      // Setup simulated radar markers
      _simulatedEntities.clear();

      // Unassigned destinations
      final rand = math.Random(42);
      for (var o in _orders.where((o) => o.status != 'out_for_delivery')) {
        // Place unassigned destinations in random polar coordinates around kitchen
        final dist = 0.3 + rand.nextDouble() * 0.5;
        final angle = rand.nextDouble() * 2 * math.pi;
        _simulatedEntities.add(
          _SimulatedEntity(
            id: o.id,
            label: '#${o.orderNumber}',
            relX: dist * math.cos(angle),
            relY: dist * math.sin(angle),
            isDriver: false,
            isActiveTrip: false,
          ),
        );
      }

      // Active Trips (drivers moving to customers)
      for (var o in _orders.where((o) => o.status == 'out_for_delivery')) {
        final dist = 0.5 + rand.nextDouble() * 0.3;
        final angle = rand.nextDouble() * 2 * math.pi;

        final destX = dist * math.cos(angle);
        final destY = dist * math.sin(angle);

        // Driver starts somewhere in between
        final progress = 0.2 + rand.nextDouble() * 0.6;
        final driverX = destX * progress;
        final driverY = destY * progress;

        // Customer
        _simulatedEntities.add(
          _SimulatedEntity(
            id: o.id,
            label: '#${o.orderNumber}',
            relX: destX,
            relY: destY,
            isDriver: false,
            isActiveTrip: true,
          ),
        );

        // Driver
        _simulatedEntities.add(
          _SimulatedEntity(
            id: o.id + 10000,
            label: 'Driver ${o.assignedDelivery}',
            relX: driverX,
            relY: driverY,
            destX: destX,
            destY: destY,
            isDriver: true,
            isActiveTrip: true,
          ),
        );
      }
    }
  }

  // --- Dispatch Assign Action (multi-order) ---

  Future<void> _assignDriverToOrders(
    List<Order> orders,
    DeliveryStaff driver,
  ) async {
    setState(() => _isBusy = true);
    int count = 0;
    try {
      for (final order in orders) {
        await _orderSvc.assignDelivery(order.id, driver.id);
        await _orderSvc.updateStatus(order.id, 'out_for_delivery');
        count++;
      }
      _loadData(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 1
                  ? 'Order #${orders.first.orderNumber} assigned to ${driver.name}'
                  : '$count orders assigned to ${driver.name}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _selectedOrderIds.clear();
          _assignPanelOpen = false;
        });
      }
    }
  }

  // --- Auto Assign Engine ---

  Future<void> _triggerAutoAssign() async {
    // Only auto-assign 'preparing' orders
    final unassigned = _orders
        .where((o) => o.assignedDelivery == null && o.status == 'preparing')
        .toList();
    if (unassigned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No preparing orders ready to dispatch.'),
          backgroundColor: _red,
        ),
      );
      return;
    }

    setState(() => _isBusy = true);

    // Available = drivers not currently out_for_delivery
    final busyDriverIds = _orders
        .where(
          (o) => o.status == 'out_for_delivery' && o.assignedDelivery != null,
        )
        .map((o) => o.assignedDelivery!)
        .toSet();

    final availableDrivers = _drivers
        .where((d) => !busyDriverIds.contains(d.id))
        .toList();

    if (availableDrivers.isEmpty) {
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All delivery partners are currently busy.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    int assignCount = 0;
    for (int i = 0; i < unassigned.length; i++) {
      if (i >= availableDrivers.length) break;
      final order = unassigned[i];
      final driver = availableDrivers[i];
      try {
        await _orderSvc.assignDelivery(order.id, driver.id);
        await _orderSvc.updateStatus(order.id, 'out_for_delivery');
        assignCount++;
      } catch (_) {}
    }

    await _loadData(silent: true);
    if (mounted) {
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Auto-Assign complete! Dispatched $assignCount orders.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $msg'), backgroundColor: _red),
    );
  }

  void _setSidebarCollapsed(bool collapsed) {
    if (_sidebarCollapsed == collapsed) return;
    setState(() => _sidebarCollapsed = collapsed);
  }

  void _handleSidebarSwipeEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -220) {
      _setSidebarCollapsed(true);
    } else if (velocity > 220) {
      _setSidebarCollapsed(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: HdkPreloader()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _surface,
        body: ErrorRetryWidget(error: _error!, onRetry: () => _loadData()),
      );
    }

    // Only 'preparing' orders are dispatachable (confirmed = kitchen hasn't started yet)
    final unassigned =
        _orders
            .where((o) => o.assignedDelivery == null && o.status == 'preparing')
            .toList()
          ..sort(
            (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
              b.createdAt ?? DateTime.now(),
            ),
          );

    final selectedOrders = unassigned
        .where((o) => _selectedOrderIds.contains(o.id))
        .toList();

    final activeTrips = _orders
        .where((o) => o.status == 'out_for_delivery')
        .toList();

    return Scaffold(
      backgroundColor: _surface,
      body: Row(
        children: [
          // 1. Collapsible Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            width: _sidebarCollapsed ? 0 : 300,
            decoration: const BoxDecoration(
              color: _card,
              border: Border(right: BorderSide(color: _stroke)),
            ),
            clipBehavior: Clip.hardEdge,
            child: _sidebarCollapsed
                ? const SizedBox.shrink()
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: _handleSidebarSwipeEnd,
                    child: SizedBox(
                      width: 300,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sidebar Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Dispatch Feed',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.refresh,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => _loadData(),
                                ),
                              ],
                            ),
                          ),

                          // Auto Assign Trigger Button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.bolt,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Auto-Assign Drivers',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: _isBusy ? null : _triggerAutoAssign,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: _stroke),

                          // Assign Panel (driver picker) or queue
                          if (_assignPanelOpen)
                            _buildAssignPanel(selectedOrders)
                          else
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Selection action bar
                                  if (_selectedOrderIds.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${_selectedOrderIds.length} selected',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () => setState(
                                              () => _selectedOrderIds.clear(),
                                            ),
                                            child: const Text(
                                              'Clear',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _red,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                              minimumSize: const Size(0, 34),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            onPressed: () => setState(
                                              () => _assignPanelOpen = true,
                                            ),
                                            child: Text(
                                              'Dispatch (${_selectedOrderIds.length})',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Main Queue List
                                  Expanded(
                                    child: ListView(
                                      children: [
                                        _buildSectionHeader(
                                          'Ready to Dispatch (${unassigned.length})',
                                        ),
                                        if (unassigned.isEmpty)
                                          _buildEmptyState(
                                            'No orders in preparation yet',
                                          )
                                        else
                                          ...unassigned.map(
                                            (o) => _buildOrderFeedItem(
                                              o,
                                              selected: _selectedOrderIds
                                                  .contains(o.id),
                                            ),
                                          ),

                                        const Divider(
                                          color: _stroke,
                                          height: 24,
                                        ),

                                        _buildSectionHeader(
                                          'Active Trips (${activeTrips.length})',
                                        ),
                                        if (activeTrips.isEmpty)
                                          _buildEmptyState(
                                            'No active trips on road',
                                          )
                                        else
                                          ...activeTrips.map(
                                            (o) => _buildActiveTripItem(o),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),

          // 2. Map Area with collapse toggle overlay
          Expanded(
            child: Stack(
              children: [
                _useGoogleMap ? _buildGoogleMap() : _buildRadarSimulation(),

                if (_sidebarCollapsed)
                  Positioned(
                    top: 0,
                    left: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: _handleSidebarSwipeEnd,
                      onTap: () => _setSidebarCollapsed(false),
                      child: Container(
                        width: 18,
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: Container(
                          width: 4,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Collapse / Expand toggle button
                Positioned(
                  top: 56,
                  left: 8,
                  child: GestureDetector(
                    onTap: () => _setSidebarCollapsed(!_sidebarCollapsed),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _stroke),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        _sidebarCollapsed
                            ? Icons.arrow_forward_ios_rounded
                            : Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),

                // Busy Loader
                if (_isBusy)
                  const Positioned(
                    top: 20,
                    right: 20,
                    child: Card(
                      color: _card,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: _red,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Syncing assignment...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Map Builders ---

  Widget _buildGoogleMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _kitchenLocation,
        zoom: 13.5,
      ),
      markers: _googleMarkers,
      polylines: _googlePolylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapType: MapType.normal,
      onMapCreated: (ctrl) {
        _mapController = ctrl;
      },
    );
  }

  Widget _buildRadarSimulation() {
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;
          final centerY = constraints.maxHeight / 2;
          final radius = math.min(centerX, centerY) * 0.8;

          return Stack(
            children: [
              CustomPaint(
                painter: _RadarGridPainter(angle: _radarAngle),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
              // Kitchen Center Dot
              Center(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _red.withValues(alpha: 0.8),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 10),
                ),
              ),
              // Render Entity positions
              ..._simulatedEntities.map((entity) {
                final posX = centerX + entity.relX * radius;
                final posY = centerY + entity.relY * radius;

                return Positioned(
                  left: posX - 12,
                  top: posY - 12,
                  child: Tooltip(
                    message: entity.label,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: entity.isDriver
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (entity.isDriver
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent)
                                    .withValues(alpha: 0.6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        entity.isDriver ? Icons.local_shipping : Icons.home,
                        size: 13,
                        color: Colors.black,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // --- Sidebar Component Builders ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: Text(
          msg,
          style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildOrderFeedItem(Order order, {bool selected = false}) {
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selectedOrderIds.remove(order.id);
        } else {
          _selectedOrderIds.add(order.id);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _red.withValues(alpha: 0.12) : _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _red : _stroke,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  color: selected ? _red : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: selected ? _red : Colors.grey.shade700,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              // Order Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '#${order.orderNumber}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '₹${order.totalAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            color: _red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.address?.lineOne ?? 'No Address Details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTripItem(Order order) {
    // Find driver name
    final driver = _drivers.firstWhere(
      (d) => d.id == order.assignedDelivery,
      orElse: () => DeliveryStaff(
        id: 0,
        name: 'Unknown Driver',
        phoneNumber: '',
        isDefaultDelivery: false,
      ),
    );

    return Card(
      color: _surface,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _stroke),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminOrderDetailScreen(orderId: order.id),
          ),
        ),
        title: Text(
          '#${order.orderNumber} ➔ ${driver.name}',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          order.address?.lineOne ?? 'Sojat Road',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        trailing: const Icon(
          Icons.local_shipping,
          color: Colors.greenAccent,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildAssignPanel(List<Order> selectedOrders) {
    final busyDriverIds = _orders
        .where(
          (o) => o.status == 'out_for_delivery' && o.assignedDelivery != null,
        )
        .map((o) => o.assignedDelivery!)
        .toSet();

    final available = _drivers
        .where((d) => !busyDriverIds.contains(d.id))
        .toList();
    final all = _drivers;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => setState(() => _assignPanelOpen = false),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pick a Delivery Partner',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${selectedOrders.length} order(s) will be dispatched',
                        style: GoogleFonts.poppins(color: _red, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Selected orders summary chips
          if (selectedOrders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: selectedOrders
                    .map(
                      (o) => Chip(
                        label: Text(
                          '#${o.orderNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor: _red.withValues(alpha: 0.2),
                        side: const BorderSide(color: _red),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ),

          const SizedBox(height: 8),
          const Divider(color: _stroke),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'Available Partners (${available.length} of ${all.length})',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

          Expanded(
            child: available.isEmpty
                ? _buildEmptyState('All partners are currently busy.')
                : ListView.builder(
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final driver = available[index];
                      // Count how many active trips this driver already has
                      final activeTripCount = _orders
                          .where(
                            (o) =>
                                o.status == 'out_for_delivery' &&
                                o.assignedDelivery == driver.id,
                          )
                          .length;
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _stroke),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: activeTripCount == 0
                                  ? Colors.green
                                  : Colors.orange,
                              child: Text(
                                driver.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver.name,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    activeTripCount == 0
                                        ? 'Available'
                                        : '$activeTripCount trip(s) active',
                                    style: TextStyle(
                                      color: activeTripCount == 0
                                          ? Colors.green
                                          : Colors.orange,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _red,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                minimumSize: const Size(0, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isBusy
                                  ? null
                                  : () => _assignDriverToOrders(
                                      selectedOrders,
                                      driver,
                                    ),
                              child: Text(
                                'Dispatch',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- Radar Paint Helper for Desktop Simulation ---

class _RadarGridPainter extends CustomPainter {
  final double angle;

  _RadarGridPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.8;

    final bgPaint = Paint()..color = Colors.black87;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF1F1F1F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric circles
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), linePaint);
    }

    // Draw grid lines
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      linePaint,
    );

    // Draw scanning sweep
    final sweepPaint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        [
          Colors.greenAccent.withValues(alpha: 0.15),
          Colors.greenAccent.withValues(alpha: 0.0),
        ],
        [0.0, 0.25],
        TileMode.clamp,
        angle,
        angle + math.pi / 2,
      );

    canvas.drawCircle(center, radius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) =>
      oldDelegate.angle != angle;
}

// Simulated data model helper
class _SimulatedEntity {
  final int id;
  final String label;
  double relX;
  double relY;
  final double? destX;
  final double? destY;
  final bool isDriver;
  final bool isActiveTrip;

  _SimulatedEntity({
    required this.id,
    required this.label,
    required this.relX,
    required this.relY,
    this.destX,
    this.destY,
    required this.isDriver,
    required this.isActiveTrip,
  });

  void moveTowardsDestination() {
    if (destX == null || destY == null) return;

    final dx = destX! - relX;
    final dy = destY! - relY;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance > 0.005) {
      relX += (dx / distance) * 0.002;
      relY += (dy / distance) * 0.002;
    }
  }
}
