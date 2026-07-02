import 'package:flutter/material.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../accounts/data/repositories/user_service.dart';

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

    if (token != null) {
      // Returning user — check if they have a name yet.
      try {
        final user = await UserService().getCurrentUser();
        if (!mounted) return;
        if (user.name.trim().isEmpty) {
          AppRoutes.pushReplacementNameCollection(context);
        } else {
          AppRoutes.pushReplacementHome(context);
        }
      } catch (_) {
        if (mounted) AppRoutes.pushReplacementHome(context);
      }
    } else if (!hasCompletedOnboarding) {
      AppRoutes.pushReplacementOnboarding(context);
    } else {
      AppRoutes.pushReplacementHome(context);
    }
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1E1E).withValues(alpha: 0.30),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/hdk-logo.png',
              width: 112,
              height: 88,
              fit: BoxFit.contain,
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
