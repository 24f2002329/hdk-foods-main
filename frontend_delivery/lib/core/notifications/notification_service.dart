import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'package:hdk_core/hdk_core.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/data/repositories/order_service.dart';

const _kChannelId = 'hdkfoods_orders';
const _kChannelName = 'Order Alerts';

class NotificationService {
  static GlobalKey<NavigatorState>? navigatorKey;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // ── Init ─────────────────────────────────────────────────────────────────

  static Future<void> init(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;
    await _initLocal();

    // Foreground messages → show local banner
    FirebaseMessaging.onMessage.listen(_showLocal);

    // Background tap (app in background when user tapped)
    FirebaseMessaging.onMessageOpenedApp.listen((msg) => _handleTap(msg.data));

    // Terminated tap (app was killed)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      await Future.delayed(const Duration(milliseconds: 500));
      _handleTap(initial.data);
    }
  }

  // ── Token upload ──────────────────────────────────────────────────────────

  static Future<void> uploadToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      );
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _postToken(token);

      FirebaseMessaging.instance.onTokenRefresh.listen((t) => _postToken(t));
    } catch (_) {}
  }

  static Future<void> _postToken(String token) async {
    try {
      final access = await TokenStorage.getAccessToken();
      if (access == null) return;
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/fcm-token/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $access',
        },
        body: jsonEncode({'fcm_token': token}),
      );
    } catch (_) {}
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  static void _handleTap(Map<String, dynamic> data) async {
    final orderId = int.tryParse(data['order_id']?.toString() ?? '');
    if (orderId == null) return;
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return;
    try {
      final order = await OrderService().getOrder(orderId);
      if (!ctx.mounted) return;
      Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => OrderDetailScreen(order: order, role: 'delivery'),
      ));
    } catch (_) {}
  }

  // ── Local notifications ───────────────────────────────────────────────────

  static Future<void> _initLocal() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        try {
          if (response.payload != null) {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            _handleTap(data);
          }
        } catch (_) {
          final orderId = response.payload;
          if (orderId != null) _handleTap({'order_id': orderId});
        }
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kChannelId,
          _kChannelName,
          importance: Importance.high,
          enableVibration: true,
        ));
  }

  static Future<void> _showLocal(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    await _local.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
