import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hdk_core/hdk_core.dart';

import 'core/notifications/notification_service.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: FirebaseConfig.options);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: FirebaseConfig.options);

  // Set up Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.init(navigatorKey);

  // Log App Open
  await HdkAnalytics.logAppOpen();

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
