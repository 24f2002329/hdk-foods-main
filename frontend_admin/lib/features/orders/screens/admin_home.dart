import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/error_retry.dart';
import '../../auth/screens/login_screen.dart';
import '../../orders/models/order.dart';
import '../../orders/services/order_service.dart';
import '../../delivery_staff/services/delivery_staff_service.dart';
import '../../orders/screens/admin_order_detail_screen.dart';
import '../../products/screens/product_management_screen.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);

// ─── Home shell ──────────────────────────────────────────────────────────────

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  static const _tabs = [
    _DashboardTab(),
    _PendingOrdersTab(),
    _AllOrdersTab(),
    _DeliveryStaffTab(),
    _AdminProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_index],
      bottomNavigationBar: NavigationBar(
        backgroundColor: _card,
        indicatorColor: _red.withValues(alpha: 0.15),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: _red),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.pending_outlined),
              selectedIcon: Icon(Icons.pending, color: _red),
              label: 'Pending'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: _red),
              label: 'All Orders'),
          NavigationDestination(
              icon: Icon(Icons.delivery_dining_outlined),
              selectedIcon: Icon(Icons.delivery_dining, color: _red),
              label: 'Delivery'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: _red),
              label: 'Profile'),
        ],
      ),
    );
  }
}

// ─── Dashboard tab ────────────────────────────────────────────────────────────

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final OrderService _svc = OrderService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _svc.getDashboard();
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                Text(label,
                    style: GoogleFonts.poppins(
                        color: Colors.grey, fontSize: 11)),
              ],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Dashboard',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: _red),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 8),
                      Text("Today's Overview",
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Live restaurant stats',
                          style: GoogleFonts.poppins(
                              color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 20),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        children: [
                          _statCard(
                            'Orders Today',
                            '${_data?['today_orders'] ?? 0}',
                            Icons.receipt_long,
                            Colors.blueAccent,
                          ),
                          _statCard(
                            'Pending',
                            '${_data?['pending_orders'] ?? 0}',
                            Icons.pending_outlined,
                            Colors.orangeAccent,
                          ),
                          _statCard(
                            'Out for Delivery',
                            '${_data?['active_deliveries'] ?? 0}',
                            Icons.delivery_dining,
                            Colors.purpleAccent,
                          ),
                          _statCard(
                            'Revenue',
                            '₹${double.tryParse('${_data?['today_revenue'] ?? 0}')?.toStringAsFixed(0) ?? '0'}',
                            Icons.currency_rupee,
                            Colors.greenAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ─── Pending orders tab ───────────────────────────────────────────────────────

class _PendingOrdersTab extends StatefulWidget {
  const _PendingOrdersTab();

  @override
  State<_PendingOrdersTab> createState() => _PendingOrdersTabState();
}

class _PendingOrdersTabState extends State<_PendingOrdersTab> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  final OrderService _svc = OrderService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = await _svc.getOrders();
      setState(() {
        _orders = all.where((o) => o.status == 'pending_confirmation').toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Pending Orders',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: _red),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : _orders.isEmpty
                  ? Center(
                      child: Text('No pending orders',
                          style: GoogleFonts.poppins(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _orders.length,
                        itemBuilder: (_, i) => _OrderCard(
                          order: _orders[i],
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminOrderDetailScreen(
                                    orderId: _orders[i].id)),
                            );
                            _load();
                          },
                        ),
                      ),
                    ),
    );
  }
}

// ─── All orders tab ───────────────────────────────────────────────────────────

class _AllOrdersTab extends StatefulWidget {
  const _AllOrdersTab();

  @override
  State<_AllOrdersTab> createState() => _AllOrdersTabState();
}

class _AllOrdersTabState extends State<_AllOrdersTab> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  final OrderService _svc = OrderService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final orders = await _svc.getOrders();
      setState(() { _orders = orders; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('All Orders',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: _red),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _orders.length,
                    itemBuilder: (_, i) => _OrderCard(
                      order: _orders[i],
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminOrderDetailScreen(
                                orderId: _orders[i].id),
                          ),
                        );
                        _load();
                      },
                    ),
                  ),
                ),
    );
  }
}

// ─── Delivery staff tab ───────────────────────────────────────────────────────

class _DeliveryStaffTab extends StatefulWidget {
  const _DeliveryStaffTab();

  @override
  State<_DeliveryStaffTab> createState() => _DeliveryStaffTabState();
}

class _DeliveryStaffTabState extends State<_DeliveryStaffTab> {
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = DeliveryStaffService();
      final list = await svc.getDeliveryStaff();
      setState(() {
        _staff = list
            .map((s) => {
                  'id': s.id,
                  'name': s.name,
                  'phone_number': s.phoneNumber,
                  'is_default_delivery': s.isDefaultDelivery,
                })
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _setDefault(int userId) async {
    try {
      final svc = DeliveryStaffService();
      await svc.setDefaultDelivery(userId);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Delivery Staff',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: _red),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : _staff.isEmpty
                  ? Center(
                      child: Text('No delivery staff found',
                          style: GoogleFonts.poppins(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _staff.length,
                      itemBuilder: (_, i) {
                        final s = _staff[i];
                        final isDefault = s['is_default_delivery'] == true;
                        return Card(
                          color: _card,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  isDefault ? _red : Colors.grey[800],
                              child: Text(
                                (s['name'] as String? ?? '?')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(s['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                if (isDefault) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('DEFAULT',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(s['phone_number'] ?? '',
                                style: const TextStyle(color: Colors.grey)),
                            trailing: isDefault
                                ? null
                                : TextButton(
                                    onPressed: () =>
                                        _setDefault(s['id'] as int),
                                    child: const Text('Set Default',
                                        style: TextStyle(color: _red)),
                                  ),
                          ),
                        );
                      },
                    ),
    );
  }
}

// ─── Profile tab ──────────────────────────────────────────────────────────────

class _AdminProfileTab extends StatefulWidget {
  const _AdminProfileTab();

  @override
  State<_AdminProfileTab> createState() => _AdminProfileTabState();
}

class _AdminProfileTabState extends State<_AdminProfileTab> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = OrderService();
      final data = await svc.getMe();
      if (mounted) setState(() { _profile = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await TokenStorage.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Profile',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: _red,
                    child: Icon(Icons.admin_panel_settings,
                        size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(_profile?['name'] ?? 'Admin',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  Text(_profile?['phone_number'] ?? '',
                      style: GoogleFonts.poppins(
                          color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('ADMIN',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFF2A2A2A)),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fastfood,
                          color: Colors.orangeAccent, size: 20),
                    ),
                    title: const Text('Manage Products',
                        style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Toggle menu availability',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.grey),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProductManagementScreen()),
                    ),
                  ),
                  const Divider(color: Color(0xFF2A2A2A)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900]),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Shared order card ────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  Color _statusColor(String s) {
    switch (s) {
      case 'pending_confirmation': return Colors.orange;
      case 'confirmed':
      case 'preparing': return Colors.blue;
      case 'ready_for_pickup': return Colors.purple;
      case 'out_for_delivery': return Colors.indigo;
      case 'delivered': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _card,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${order.orderNumber}',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      order.createdAt != null
                          ? DateFormat('MMM d, h:mm a').format(order.createdAt!)
                          : '',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(order.status)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: _statusColor(order.status),
                                width: 0.5),
                          ),
                          child: Text(
                            order.status
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: TextStyle(
                                color: _statusColor(order.status),
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (order.paymentMethod == 'online') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: order.paymentStatus == 'paid'
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              order.paymentStatus.toUpperCase(),
                              style: TextStyle(
                                  color: order.paymentStatus == 'paid'
                                      ? Colors.green
                                      : Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Rs ${order.totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                          color: _red,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
