import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../auth/screens/login_screen.dart';
import 'delivery_orders_screen.dart';
import 'pending_orders_screen.dart';
import 'profile_screen.dart';
import 'staff_dashboard_screen.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);

/// Reads the stored role and renders the correct bottom-nav shell.
/// This is the STAFF app — chef and delivery only.
/// Admin has a separate app (frontend_admin).
class HomeRouter extends StatefulWidget {
  const HomeRouter({super.key});

  @override
  State<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await TokenStorage.getRole();
    if (!mounted) return;
    if (role == null || (role != 'chef' && role != 'delivery')) {
      // Not a staff role — send back to login.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    setState(() => _role = role);
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: CircularProgressIndicator(color: _red)),
      );
    }

    return _role == 'chef' ? const _ChefHome() : const _DeliveryHome();
  }
}

// ─── Chef: Dashboard | Orders | Profile ──────────────────────────────────────

class _ChefHome extends StatefulWidget {
  const _ChefHome();

  @override
  State<_ChefHome> createState() => _ChefHomeState();
}

class _ChefHomeState extends State<_ChefHome> {
  int _index = 0;

  static const _tabs = [
    StaffDashboardScreen(),
    PendingOrdersScreen(role: 'chef'),
    StaffProfileScreen(),
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
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: _red),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu, color: _red),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: _red),
              label: 'Profile'),
        ],
      ),
    );
  }
}

// ─── Delivery: My Deliveries | Profile ───────────────────────────────────────

class _DeliveryHome extends StatefulWidget {
  const _DeliveryHome();

  @override
  State<_DeliveryHome> createState() => _DeliveryHomeState();
}

class _DeliveryHomeState extends State<_DeliveryHome> {
  int _index = 0;

  static const _tabs = [
    DeliveryOrdersScreen(),
    StaffProfileScreen(),
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
