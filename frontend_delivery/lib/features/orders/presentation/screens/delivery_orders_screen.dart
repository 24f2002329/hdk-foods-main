import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/services/order_websocket_service.dart';
import 'package:hdk_core/hdk_core.dart';
import '../../data/repositories/order_repository.dart';
import '../../../navigation/presentation/screens/delivery_navigation_screen.dart';
import '../../../navigation/presentation/screens/payment_collection_screen.dart';
import '../../../auth/data/repositories/auth_service.dart';
import 'order_detail_screen.dart';
import '../../data/repositories/notification_service.dart';
import 'notification_screen.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen> {
  final OrderRepository _service = OrderRepository();
  List<Order> _orders = [];
  bool _loading = true;
  Timer? _timer;
  AdminOrderWebSocketService? _ws;
  StreamSubscription<RemoteMessage>? _fcmSub;

  // Rider stats & status
  bool _isOnline = true;
  List<int> _acceptedOrderIds = [];
  String _riderName = 'HDK Rider';
  bool _syncingOffline = false;
  int _unreadNotificationCount = 0;
  String? _error;

  // History filters
  String _timeFilter = 'All'; // All, Today, Yesterday
  String _paymentFilter = 'All'; // All, Cash, Online

  @override
  void initState() {
    super.initState();
    _loadRiderSettings();
    _load();

    // Poll every 12s as fallback
    _timer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _load(silent: true),
    );

    // WebSocket connect
    _ws = AdminOrderWebSocketService();
    _ws!.connect();
    _ws!.stream.listen((msg) {
      if (msg['type'] == 'delivery_update' || msg['type'] == 'order_update') {
        _load(silent: true);
      }
    });

    // FCM foreground listener
    _fcmSub = FirebaseMessaging.onMessage.listen((msg) {
      _load(silent: true);
      _handleIncomingOrderPush(msg);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ws?.dispose();
    _fcmSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRiderSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isOnline = prefs.getBool('rider_online_status') ?? true;
        _acceptedOrderIds = (prefs.getStringList('accepted_order_ids') ?? [])
            .map((e) => int.tryParse(e) ?? 0)
            .where((id) => id > 0)
            .toList();
      });

      // Fetch profile name
      final profile = await AuthService().me();
      if (profile.containsKey('name')) {
        setState(() {
          _riderName = profile['name'] ?? 'HDK Rider';
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() {
      _isOnline = value;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rider_online_status', value);
    } catch (_) {}
  }

  Future<void> _acceptOrder(int id) async {
    setState(() {
      _acceptedOrderIds.add(id);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final strList = _acceptedOrderIds.map((e) => e.toString()).toList();
      await prefs.setStringList('accepted_order_ids', strList);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order accepted! Head to the kitchen to pick up.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {}
  }

  Future<void> _pickUpOrder(int id) async {
    setState(() => _loading = true);
    try {
      await _service.updateStatus(id, 'out_for_delivery');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order picked up! Drive safely.'),
          backgroundColor: Colors.blue,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _syncOfflineDeliveries() async {
    if (_syncingOffline) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_delivered_orders') ?? [];
      if (pending.isEmpty) return;

      setState(() => _syncingOffline = true);
      int successCount = 0;
      for (String orderIdStr in List<String>.from(pending)) {
        final id = int.tryParse(orderIdStr);
        if (id != null) {
          try {
            await _service.updateStatus(id, 'delivered');
            pending.remove(orderIdStr);
            successCount++;
          } catch (_) {
            // Keep in queue if server is still unreachable
          }
        }
      }
      await prefs.setStringList('pending_delivered_orders', pending);
      if (successCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced $successCount offline deliveries to server!'),
            backgroundColor: Colors.green,
          ),
        );
        _load(silent: true);
      }
    } catch (_) {
    } finally {
      setState(() => _syncingOffline = false);
    }
  }

  // Caching helpers
  Map<String, dynamic> _orderToMap(Order o) {
    return {
      'id': o.id,
      'order_number': o.orderNumber,
      'user': o.customerId,
      'address': o.addressId,
      'status': o.status,
      'payment_method': o.paymentMethod,
      'payment_status': o.paymentStatus,
      'payment_session_id': o.paymentSessionId,
      'total_amount': o.totalAmount,
      'delivery_notes': o.deliveryNotes,
      'customer_name': o.customerName,
      'customer_phone': o.customerPhone,
      'coins_redeemed': o.coinsRedeemed,
      'coins_earned': o.coinsEarned,
      'address_detail': o.address == null
          ? null
          : {
              'label': o.address!.label,
              'house': o.address!.house,
              'street': o.address!.street,
              'landmark': o.address!.landmark,
              'city': o.address!.city,
              'pincode': o.address!.pincode,
              'latitude': o.address!.latitude,
              'longitude': o.address!.longitude,
            },
      'created_at': o.createdAt?.toIso8601String(),
    };
  }

  Future<void> _cacheOrdersLocally(List<Order> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maps = orders.map((o) => _orderToMap(o)).toList();
      await prefs.setString('cached_delivery_orders', json.encode(maps));
    } catch (_) {}
  }

  Future<List<Order>> _loadCachedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_delivery_orders');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final list = json.decode(cachedStr) as List;
        return list
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _navigate(Order o) async {
    if (o.address?.latitude == null || o.address?.longitude == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeliveryNavigationScreen(order: o)),
    );
    _load();
  }

  void _handleIncomingOrderPush(RemoteMessage msg) async {
    final orderIdStr = msg.data['order_id']?.toString();
    if (orderIdStr == null) return;
    final orderId = int.tryParse(orderIdStr);
    if (orderId == null) return;

    try {
      final order = await _service.getOrder(orderId);
      if (!mounted) return;

      final viewPressed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          backgroundColor: _panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LottieOr(
                asset: 'assets/animations/out_for_delivery.json',
                width: 180,
                height: 180,
                fallback: Icon(Icons.delivery_dining, size: 64, color: _red),
              ),
              const SizedBox(height: 16),
              const Text(
                'New Delivery Assigned!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order #${order.orderNumber}',
                style: const TextStyle(
                  color: _red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (order.address != null)
                Text(
                  order.address!.lineOne,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'View Order',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (viewPressed == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: order, role: 'delivery'),
          ),
        );
        _load();
      }
    } catch (_) {}
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    // Try sync pending offline deliveries if online
    await _syncOfflineDeliveries();

    try {
      final orders = await _service.getDeliveryOrders();
      await _cacheOrdersLocally(orders);

      int unread = 0;
      try {
        final res = await NotificationService().getNotifications();
        unread = res['unread_count'] as int;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _orders = orders;
          _unreadNotificationCount = unread;
          _loading = false;
          _error = null;
        });
      }
    } catch (e, st) {
      debugPrint('DeliveryOrdersScreen._load error: $e\n$st');

      // Network issue: Load from cache
      final cached = await _loadCachedOrders();
      if (mounted) {
        setState(() {
          if (cached.isNotEmpty) {
            _orders = cached;
            _error = null;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Displaying cached offline order data.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            _error = e.toString();
          }
          _loading = false;
        });
      }
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );
    _load(silent: true);
  }

  // Helper getters for statistics
  int get _todayCompletedCount {
    final now = DateTime.now();
    return _orders.where((o) {
      if (o.status != 'delivered' || o.createdAt == null) return false;
      final createdLocal = o.createdAt!.toLocal();
      return createdLocal.year == now.year &&
          createdLocal.month == now.month &&
          createdLocal.day == now.day;
    }).length;
  }

  double get _todayDistance {
    double total = 0.0;
    final now = DateTime.now();
    final todayDelivered = _orders.where((o) {
      if (o.status != 'delivered' || o.createdAt == null) return false;
      final createdLocal = o.createdAt!.toLocal();
      return createdLocal.year == now.year &&
          createdLocal.month == now.month &&
          createdLocal.day == now.day;
    }).toList();

    const double kitchenLat = 25.9233;
    const double kitchenLng = 73.6646;

    for (var o in todayDelivered) {
      if (o.address?.latitude != null && o.address?.longitude != null) {
        total +=
            Geolocator.distanceBetween(
              kitchenLat,
              kitchenLng,
              o.address!.latitude!,
              o.address!.longitude!,
            ) /
            1000.0;
      } else {
        total += 3.4; // Realistic fallback
      }
    }
    return total;
  }

  String get _achievementLevel {
    final completed = _todayCompletedCount;
    if (completed >= 15) return 'Elite Rider 🏆';
    if (completed >= 8) return 'Pro Rider 🔥';
    if (completed >= 3) return 'Active Rider ⚡';
    return 'Starter Rider 🌱';
  }

  // Active / Current Orders (Online mode only)
  List<Order> get _activeOrders {
    return _orders
        .where(
          (o) =>
              o.status != 'delivered' &&
              o.status != 'cancelled' &&
              o.status != 'rejected',
        )
        .toList();
  }

  // Past Orders with filter logic
  List<Order> get _filteredHistoryOrders {
    final history = _orders
        .where(
          (o) =>
              o.status == 'delivered' ||
              o.status == 'cancelled' ||
              o.status == 'rejected',
        )
        .toList();

    return history.where((o) {
      // 1. Time Filter
      if (_timeFilter == 'Today') {
        if (o.createdAt == null) return false;
        final now = DateTime.now();
        final createdLocal = o.createdAt!.toLocal();
        if (createdLocal.year != now.year ||
            createdLocal.month != now.month ||
            createdLocal.day != now.day) {
          return false;
        }
      } else if (_timeFilter == 'Yesterday') {
        if (o.createdAt == null) return false;
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final createdLocal = o.createdAt!.toLocal();
        if (createdLocal.year != yesterday.year ||
            createdLocal.month != yesterday.month ||
            createdLocal.day != yesterday.day) {
          return false;
        }
      }

      // 2. Payment Filter
      if (_paymentFilter == 'Cash') {
        if (o.paymentMethod != 'cod') return false;
      } else if (_paymentFilter == 'Online') {
        if (o.paymentMethod != 'online') return false;
      }

      return true;
    }).toList();
  }

  void _openSOSDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _red, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text(
              'Emergency SOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Quickly access emergency services, call the kitchen helpdesk, or share your live coordinates.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: const Text(
                    'Call Emergency (112)',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () => launchUrl(Uri.parse('tel:112')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[850],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.call, color: Colors.white),
                  label: const Text(
                    'Call Kitchen Helpdesk',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () => launchUrl(Uri.parse('tel:+919999988888')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.share_location, color: Colors.white),
                  label: const Text(
                    'Share Live Location',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      final pos = await Geolocator.getCurrentPosition();
                      final mapsUrl =
                          'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
                      await launchUrl(
                        Uri.parse(
                          'sms:?body=Emergency! Here is my live location: $mapsUrl',
                        ),
                      );
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not access current location.'),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Builder Methods
  Widget _buildGreetingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Hello, $_riderName 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _achievementLevel,
                    style: const TextStyle(
                      color: _red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isOnline ? Colors.greenAccent : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: _isOnline
                          ? [
                              BoxShadow(
                                color: Colors.greenAccent.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: _isOnline ? Colors.greenAccent : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _isOnline,
                  activeThumbColor: Colors.greenAccent,
                  activeTrackColor: Colors.greenAccent.withValues(alpha: 0.2),
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.grey.withValues(alpha: 0.2),
                  onChanged: _toggleOnlineStatus,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Completed',
            '$_todayCompletedCount',
            'Orders today',
            Icons.check_circle_outline,
            Colors.greenAccent,
          ),
          Container(width: 1, height: 40, color: _stroke),
          _buildStatItem(
            'Distance',
            '${_todayDistance.toStringAsFixed(1)} km',
            'Covered today',
            Icons.directions_run,
            Colors.blueAccent,
          ),
          Container(width: 1, height: 40, color: _stroke),
          _buildStatItem(
            'Rating',
            '4.9 ⭐',
            'Rider Rating',
            Icons.star_border,
            Colors.amberAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    String sub,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 9)),
      ],
    );
  }

  Widget _buildOrderCard(Order o) {
    final isDelivered = o.status == 'delivered';
    final isCancelled = o.status == 'cancelled' || o.status == 'rejected';
    final isAccepted = _acceptedOrderIds.contains(o.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDelivered
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : isCancelled
              ? Colors.redAccent.withValues(alpha: 0.3)
              : isAccepted
              ? Colors.blueAccent.withValues(alpha: 0.5)
              : _stroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID and Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${o.orderNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (isDelivered
                              ? Colors.greenAccent
                              : isCancelled
                              ? Colors.redAccent
                              : o.status == 'out_for_delivery'
                              ? Colors.blueAccent
                              : Colors.orangeAccent)
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isDelivered
                      ? 'Delivered'
                      : isCancelled
                      ? 'Cancelled'
                      : o.status == 'out_for_delivery'
                      ? 'Out for Delivery'
                      : 'Assigned',
                  style: TextStyle(
                    color: isDelivered
                        ? Colors.greenAccent
                        : isCancelled
                        ? Colors.redAccent
                        : o.status == 'out_for_delivery'
                        ? Colors.blueAccent
                        : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Items List
          ...o.items.map(
            (item) => Text(
              '${item.quantity}× ${item.productName}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),

          // Customer Notes Alert Box
          if (o.deliveryNotes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rider Note: ${o.deliveryNotes}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Address Card
          if (o.address != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, color: _red, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${o.address!.lineOne}, ${o.address!.lineTwo}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Navigation & Call Card Actions
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _stroke),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Open Maps
                      IconButton(
                        tooltip: 'Google Maps',
                        icon: const Icon(
                          Icons.map_outlined,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        onPressed: () {
                          if (o.address?.latitude != null &&
                              o.address?.longitude != null) {
                            launchUrl(
                              Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${o.address!.latitude},${o.address!.longitude}',
                              ),
                            );
                          }
                        },
                      ),
                      // Call Customer
                      IconButton(
                        tooltip: 'Call Customer',
                        icon: const Icon(
                          Icons.phone_iphone_rounded,
                          color: Colors.greenAccent,
                          size: 20,
                        ),
                        onPressed: () {
                          if (o.customerPhone.isNotEmpty) {
                            launchUrl(Uri.parse('tel:${o.customerPhone}'));
                          }
                        },
                      ),
                      // Call Kitchen
                      IconButton(
                        tooltip: 'Call Kitchen',
                        icon: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.orangeAccent,
                          size: 20,
                        ),
                        onPressed: () {
                          launchUrl(Uri.parse('tel:+919999988888'));
                        },
                      ),
                      // Internal Navigation
                      IconButton(
                        tooltip: 'Start Tracking',
                        icon: const Icon(
                          Icons.navigation_rounded,
                          color: _red,
                          size: 20,
                        ),
                        onPressed: () => _navigate(o),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Price & Time Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount: ₹${o.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                o.createdAt != null
                    ? DateFormat('hh:mm a').format(o.createdAt!.toLocal())
                    : '',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),

          // Cash on Delivery Indicator
          if (o.paymentMethod == 'cod' && o.paymentStatus != 'paid') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠ Collect Cash on Delivery',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          // One-Tap Actions for Active Deliveries
          if (!isDelivered && !isCancelled) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: _buildOneTapActionButton(o, isAccepted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOneTapActionButton(Order o, bool isAccepted) {
    if (o.status == 'confirmed' || o.status == 'preparing') {
      if (!isAccepted) {
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text(
            'Accept Delivery Request',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () => _acceptOrder(o.id),
        );
      } else {
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.takeout_dining_rounded, size: 18),
          label: const Text(
            'Picked Up (Start Delivery)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () => _pickUpOrder(o.id),
        );
      }
    } else if (o.status == 'out_for_delivery') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.sports_motorsports_rounded, size: 18),
        label: const Text(
          'Mark Delivered',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentCollectionScreen(order: o),
            ),
          );
          _load();
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActiveTab() {
    if (!_isOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.power_off_rounded,
                size: 64,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'You are Offline',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Toggle the Online switch at the top to start receiving active delivery orders.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _red),
                onPressed: () => _toggleOnlineStatus(true),
                child: const Text(
                  'Go Online',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activeList = _activeOrders;
    if (activeList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delivery_dining_rounded,
                size: 64,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Active Deliveries',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'New delivery assignments will appear here. Stay tuned!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: activeList.length,
      itemBuilder: (_, i) => _buildOrderCard(activeList[i]),
    );
  }

  Widget _buildHistoryTab() {
    final historyList = _filteredHistoryOrders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Time Filters
                _buildFilterChip(
                  'Time: All',
                  _timeFilter == 'All',
                  () => setState(() => _timeFilter = 'All'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Time: Today',
                  _timeFilter == 'Today',
                  () => setState(() => _timeFilter = 'Today'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Time: Yesterday',
                  _timeFilter == 'Yesterday',
                  () => setState(() => _timeFilter = 'Yesterday'),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 18, color: _stroke),
                const SizedBox(width: 12),
                // Payment Filters
                _buildFilterChip(
                  'Pay: All',
                  _paymentFilter == 'All',
                  () => setState(() => _paymentFilter = 'All'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Pay: Cash',
                  _paymentFilter == 'Cash',
                  () => setState(() => _paymentFilter = 'Cash'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Pay: Online',
                  _paymentFilter == 'Online',
                  () => setState(() => _paymentFilter = 'Online'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // List
        Expanded(
          child: historyList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_toggle_off_rounded,
                          size: 48,
                          color: Colors.grey.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Past Deliveries Found',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try changing your filters or check back later.',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: historyList.length,
                  itemBuilder: (_, i) => _buildOrderCard(historyList[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _red : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _red : _stroke),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          backgroundColor: _surface,
          title: const Text(
            'HDK Delivery Partner',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: _red),
                  onPressed: _openNotifications,
                ),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _red,
                        shape: BoxShape.circle,
                        border: Border.all(color: _surface, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$_unreadNotificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
          bottom: const TabBar(
            indicatorColor: _red,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Active Dashboard'),
              Tab(text: 'History'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openSOSDialog,
          backgroundColor: Colors.red,
          child: const Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Active Dashboard
            _loading
                ? const Center(child: HdkPreloader())
                : _error != null
                ? ErrorRetryWidget(error: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildGreetingCard(),
                        const SizedBox(height: 12),
                        if (_isOnline) ...[
                          _buildStatsRow(),
                          const SizedBox(height: 16),
                        ],
                        const Text(
                          'Current Deliveries',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildActiveTab(),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
            // Tab 2: History
            _loading
                ? const Center(child: HdkPreloader())
                : _error != null
                ? ErrorRetryWidget(error: _error!, onRetry: _load)
                : _buildHistoryTab(),
          ],
        ),
      ),
    );
  }
}
