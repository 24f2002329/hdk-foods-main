import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/notifications/notification_service.dart';
import '../../orders/screens/home_router.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final token = await TokenStorage.getAccessToken();
    if (!mounted) return;
    if (token != null) {
      NotificationService.uploadToken();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeRouter()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Center(
        child: Text(
          'HDK Delivery',
          style: GoogleFonts.poppins(
            color: const Color(0xFFFF1E1E),
            fontSize: 36,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
