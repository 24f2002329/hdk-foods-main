import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'package:hdk_core/hdk_core.dart';
import 'features/address/screens/address_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/cart/services/cart_provider.dart';
import 'features/home/screens/home_screen.dart';
import 'features/checkout/screens/checkout_screen.dart';
import 'features/orders/screens/order_chat_screen.dart';
import 'features/orders/screens/order_tracking_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message — no UI actions here
}

Future<void> _initFCM() async {
  final messaging = FirebaseMessaging.instance;
  // Notification permission is requested during onboarding, after location permission.

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Upload token to backend if logged in
  final token = await messaging.getToken();
  if (token != null && await TokenStorage.isLoggedIn()) {
    try {
      final access = await TokenStorage.getAccessToken();
      await _uploadFcmToken(token, access!);
    } catch (_) {}
  }

  // Refresh token handler
  messaging.onTokenRefresh.listen((newToken) async {
    if (await TokenStorage.isLoggedIn()) {
      try {
        final access = await TokenStorage.getAccessToken();
        await _uploadFcmToken(newToken, access!);
      } catch (_) {}
    }
  });
}

Future<void> _uploadFcmToken(String fcmToken, String accessToken) async {
  try {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/fcm-token/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'fcm_token': fcmToken}),
    );
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initFCM();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupNotificationClickHandling();
  }

  void _setupNotificationClickHandling() {
    // 1. App in background/foreground when notification clicked
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    // 2. App terminated when notification clicked
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          _handleNotificationClick(message);
        });
      }
    });

    // 3. Foreground options presentation config
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _handleNotificationClick(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    if (type == 'chat') {
      final orderIdStr = data['order_id'];
      final orderNumber = data['order_number'] ?? '';
      if (orderIdStr != null) {
        final orderId = int.tryParse(orderIdStr.toString());
        if (orderId != null) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => OrderChatScreen(
                orderId: orderId,
                orderNumber: orderNumber,
              ),
            ),
          );
        }
      }
    } else if (type == 'order') {
      final orderIdStr = data['order_id'];
      if (orderIdStr != null) {
        final orderId = int.tryParse(orderIdStr.toString());
        if (orderId != null) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => OrderTrackingScreen(orderId: orderId),
            ),
          );
        }
      }
    } else {
      // Default: Go to active orders list / home
      _navigatorKey.currentState?.pushNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: HdkTheme.darkTheme,

        routes: {
          '/addresses': (_) => const AddressScreen(),
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const HomeScreen(),
          '/checkout': (_) => const CheckoutScreen(),
        },

        home: const SplashScreen(),
      ),
    );
  }
}
