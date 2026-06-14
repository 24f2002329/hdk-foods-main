import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../auth/screens/login_screen.dart';
import 'delivery_orders_screen.dart';
import 'profile_screen.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);

/// Splash-routes based on stored role. Delivery role only.
class HomeRouter extends StatefulWidget {
  const HomeRouter({super.key});

  @override
  State<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final role = await TokenStorage.getRole();
    if (!mounted) return;
    if (role != 'delivery') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: CircularProgressIndicator(color: _red)),
      );
    }
    return const _DeliveryHome();
  }
}

class _DeliveryHome extends StatefulWidget {
  const _DeliveryHome();

  @override
  State<_DeliveryHome> createState() => _DeliveryHomeState();
}

class _DeliveryHomeState extends State<_DeliveryHome> {
  int _index = 0;

  static const _tabs = [
    DeliveryOrdersScreen(),
    DeliveryProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_index],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF111111),
        indicatorColor: _red.withValues(alpha: 0.15),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.delivery_dining_outlined),
              selectedIcon: Icon(Icons.delivery_dining, color: _red),
              label: 'Deliveries'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: _red),
              label: 'Profile'),
        ],
      ),
    );
  }
}
