import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/order_websocket_service.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../../navigation/screens/delivery_navigation_screen.dart';
import 'order_detail_screen.dart';
import '../services/notification_service.dart';
import 'notification_screen.dart';
import '../../../../core/widgets/error_retry.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen> {
  final OrderService _service = OrderService();
  List<Order> _orders = [];
  bool _loading = true;
  Timer? _timer;
  AdminOrderWebSocketService? _ws;
  StreamSubscription<RemoteMessage>? _fcmSub;

  @override
  void initState() {
    super.initState();
    _load();

    // Poll every 12 s as a guaranteed fallback (covers the window before
    // the WebSocket / FCM listener kicks in after assignment).
    _timer = Timer.periodic(
        const Duration(seconds: 12), (_) => _load(silent: true));

    // WebSocket — real-time when daphne backend is live.
    _ws = AdminOrderWebSocketService();
    _ws!.connect();
    _ws!.stream.listen((msg) {
      if (msg['type'] == 'delivery_update' || msg['type'] == 'order_update') {
        _load(silent: true);
      }
    });

    // FCM foreground listener — reload immediately when a push arrives
    // while the app is open.  This is the primary trigger for assignment
    // notifications before WebSocket is available.
    _fcmSub = FirebaseMessaging.onMessage.listen((msg) {
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ws?.dispose();
    _fcmSub?.cancel();
    super.dispose();
  }

  Future<void> _navigate(Order o) async {
    if (o.address?.latitude == null || o.address?.longitude == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryNavigationScreen(order: o),
      ),
    );
    _load();
  }

  int _unreadNotificationCount = 0;
  String? _error;

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final orders = await _service.getDeliveryOrders();
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
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationScreen(),
      ),
    );
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('My Deliveries',
            style: TextStyle(fontWeight: FontWeight.w900)),
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
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _orders.isEmpty
                      ? const Center(
                          child: Text('No deliveries assigned',
                              style: TextStyle(color: Colors.grey, fontSize: 16)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (_, i) {
                        final o = _orders[i];
                        final isDelivered = o.status == 'delivered';
                        return GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(
                                    order: o, role: 'delivery'),
                              ),
                            );
                            _load();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _panel,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDelivered
                                    ? Colors.greenAccent.withValues(alpha: 0.4)
                                    : Colors.blueAccent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('#${o.orderNumber}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (isDelivered
                                                ? Colors.greenAccent
                                                : Colors.blueAccent)
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isDelivered
                                            ? 'Delivered'
                                            : 'Out for Delivery',
                                        style: TextStyle(
                                            color: isDelivered
                                                ? Colors.greenAccent
                                                : Colors.blueAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...o.items.map((item) => Text(
                                      '${item.quantity}× ${item.productName}',
                                      style: const TextStyle(
                                          color: Colors.grey),
                                    )),
                                if (o.customerName.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline,
                                          size: 13, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          o.customerName,
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12),
                                        ),
                                      ),
                                      if (o.customerPhone.isNotEmpty)
                                        GestureDetector(
                                          onTap: () => launchUrl(Uri.parse(
                                              'tel:${o.customerPhone}')),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.greenAccent
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.greenAccent
                                                      .withValues(alpha: 0.4)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.call_rounded,
                                                    color: Colors.greenAccent,
                                                    size: 12),
                                                SizedBox(width: 3),
                                                Text('Call',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.greenAccent,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        '₹${o.totalAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                      o.createdAt != null
                                          ? DateFormat('hh:mm a').format(
                                              o.createdAt!.toLocal())
                                          : '',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                                if (o.paymentMethod == 'cod' &&
                                    o.paymentStatus != 'paid') ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orangeAccent
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '⚠ Collect Cash on Delivery',
                                      style: TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                if (o.status == 'out_for_delivery' &&
                                    o.address?.latitude != null) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.navigation,
                                          size: 18),
                                      label: const Text('Navigate',
                                          style: TextStyle(
                                              fontWeight:
                                                  FontWeight.bold)),
                                      onPressed: () => _navigate(o),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
