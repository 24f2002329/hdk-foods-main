import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../../core/notifications/notification_service.dart';
import 'login_screen.dart';
import '../../orders/screens/admin_home.dart';

class AdminSplashScreen extends StatefulWidget {
  const AdminSplashScreen({super.key});

  @override
  State<AdminSplashScreen> createState() => _AdminSplashScreenState();
}

class _AdminSplashScreenState extends State<AdminSplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final token = await TokenStorage.getAccessToken();
    final role = await TokenStorage.getRole();
    if (!mounted) return;
    if (token != null && role == 'admin') {
      NotificationService.uploadToken();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminHome()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Center(
        child: Text('HDK Admin',
            style: GoogleFonts.poppins(
                color: const Color(0xFFFF1E1E),
                fontSize: 36,
                fontWeight: FontWeight.w900)),
      ),
    );
  }
}
