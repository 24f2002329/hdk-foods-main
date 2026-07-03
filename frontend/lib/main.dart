import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:hdk_core/hdk_core.dart';
import 'core/navigation/app_routes.dart';
import 'features/cart/presentation/providers/cart_provider.dart';
import 'features/home/presentation/providers/home_provider.dart';

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
      await _uploadFcmToken(token);
    } catch (_) {}
  }

  // Refresh token handler
  messaging.onTokenRefresh.listen((newToken) async {
    if (await TokenStorage.isLoggedIn()) {
      try {
        await _uploadFcmToken(newToken);
      } catch (_) {}
    }
  });
}

Future<void> _uploadFcmToken(String fcmToken) async {
  try {
    await ApiClient().post('fcm-token/', {'fcm_token': fcmToken});
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: FirebaseConfig.options);
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
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
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
          _navigatorKey.currentState?.pushNamed(
            AppRoutes.orderChat,
            arguments: {'orderId': orderId, 'orderNumber': orderNumber},
          );
        }
      }
    } else if (type == 'order') {
      final orderIdStr = data['order_id'];
      if (orderIdStr != null) {
        final orderId = int.tryParse(orderIdStr.toString());
        if (orderId != null) {
          _navigatorKey.currentState?.pushNamed(
            AppRoutes.orderTracking,
            arguments: orderId,
          );
        }
      }
    } else {
      // Default: Go to active orders list / home
      _navigatorKey.currentState?.pushNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: HdkTheme.darkTheme,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        initialRoute: AppRoutes.splash,
      ),
    );
  }
}
