import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hdk_core/hdk_core.dart';

import 'core/notifications/notification_service.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.init(navigatorKey);
  runApp(HDKAdminApp(navigatorKey: navigatorKey));
}

class HDKAdminApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const HDKAdminApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HDK Admin',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: HdkTheme.darkTheme,
      home: const AdminSplashScreen(),
    );
  }
}
