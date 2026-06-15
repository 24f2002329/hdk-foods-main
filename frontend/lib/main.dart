import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'core/config/api_config.dart';
import 'core/storage/token_storage.dart';
import 'features/address/screens/address_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/cart/services/cart_provider.dart';
import 'features/home/screens/home_screen.dart';
import 'features/checkout/screens/checkout_screen.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF1E1E),
            primary: const Color(0xFFFF1E1E),
            brightness: Brightness.dark,
          ),
          textTheme: GoogleFonts.poppinsTextTheme(
            ThemeData.dark().textTheme,
          ),
          scaffoldBackgroundColor: const Color(0xFF050505),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF050505),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF1E1E),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF111111),
            hintStyle: const TextStyle(color: Color(0xFF8F8F8F)),
            labelStyle: const TextStyle(color: Color(0xFFB8B8B8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFF1E1E)),
            ),
          ),
          useMaterial3: true,
        ),

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
