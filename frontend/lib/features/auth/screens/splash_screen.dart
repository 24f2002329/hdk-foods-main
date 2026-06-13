import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../home/screens/home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    final token = await TokenStorage.getAccessToken();
    final hasCompletedOnboarding = await TokenStorage.hasCompletedOnboarding();

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Widget nextScreen;
    if (token != null) {
      nextScreen = const HomeScreen();
    } else if (!hasCompletedOnboarding) {
      nextScreen = const OnboardingScreen();
    } else {
      nextScreen = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => nextScreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF050505),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SplashLogo(),
              SizedBox(height: 28),
              Text(
                'Fresh. Fast. Homemade.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 34),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  color: Color(0xFFFF1E1E),
                  backgroundColor: Color(0xFF1E1E1E),
                  minHeight: 4,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 112,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFF1E1E),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1E1E).withValues(alpha: 0.30),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: const Text(
            'HDK',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'FOODS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'CLOUD KITCHEN',
          style: TextStyle(
            color: Color(0xFFB8B8B8),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
