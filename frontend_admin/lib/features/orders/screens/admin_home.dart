import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/error_retry.dart';
import '../../auth/screens/login_screen.dart';
import '../../delivery_staff/models/delivery_staff.dart';
import '../../delivery_staff/services/delivery_staff_service.dart';
import '../../orders/models/order.dart';
import '../../orders/services/order_service.dart';
import '../../orders/screens/admin_order_detail_screen.dart';
import '../../products/models/product.dart';
import '../../products/services/product_service.dart';
import '../../settings/screens/site_config_screen.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

// ─── Shell ────────────────────────────────────────────────────────────────────

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int i) {
    setState(() => _index = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (i) => setState(() => _index = i),
        children: const [
          _DashboardTab(),
          _ActiveOrdersTab(),
          _OrdersTab(),
          _ProductsTab(),
          SiteConfigScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: _card,
        indicatorColor: _red.withValues(alpha: 0.15),
        selectedIndex: _index,
        onDestinationSelected: _onNavTap,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: _red),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.bolt_outlined),
              selectedIcon: Icon(Icons.bolt, color: _red),
              label: 'Active'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: _red),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.fastfood_outlined),
              selectedIcon: Icon(Icons.fastfood, color: _red),
              label: 'Products'),
          NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune, color: _red),
              label: 'Settings'),
        ],
      ),
    );
  }
}

// ─── Dashboard ────────────────────────────────────────────────────────────────

// ─── Period filter definition ─────────────────────────────────────────────────

const _periods = [
  ('today', 'Today'),
  ('7d', '7 Days'),
  ('30d', '30 Days'),
  ('3m', '3 Months'),
  ('year', 'This Year'),
];

// ─── Dashboard ────────────────────────────────────────────────────────────────

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _period = 'today';
  final OrderService _svc = OrderService();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
        const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final data = await _svc.getDashboard(period: _period);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted && !silent) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  void _setPeriod(String p) {
    if (_period == p) return;
    setState(() { _period = p; _loading = true; _error = null; });
    _load();
  }

  String get _periodLabel =>
      _periods.firstWhere((p) => p.$1 == _period).$2;

  String _fmt(String key) {
    final v = _data?[key];
    if (v == null) return '0';
    final n = double.tryParse('$v') ?? 0;
    return n.toStringAsFixed(0);
  }

  void _drill({
    required String title,
    required List<String> statuses,
    bool periodScoped = true,
  }) {
    final startDate = _data?['start_date'] as String?;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardOrdersScreen(
          title: title,
          statuses: statuses,
          startDate: periodScoped ? startDate : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _periods.map((p) {
                final selected = _period == p.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(p.$2),
                    selected: selected,
                    onSelected: (_) => _setPeriod(p.$1),
                    selectedColor: _red.withValues(alpha: 0.2),
                    checkmarkColor: _red,
                    labelStyle: TextStyle(
                      color: selected ? _red : Colors.grey,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    backgroundColor: _card,
                    side: BorderSide(
                        color: selected ? _red : _stroke),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _red,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 4),
                      Text('$_periodLabel Overview',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      Text(
                        _period == 'today'
                            ? DateFormat('EEEE, MMM d').format(DateTime.now())
                            : 'Tap a card to view orders',
                        style: GoogleFonts.poppins(
                            color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.25,
                        children: [
                          _StatCard(
                            label: 'Total Orders',
                            value: _fmt('total_orders'),
                            icon: Icons.receipt_long,
                            color: Colors.blueAccent,
                            onTap: () => _drill(
                              title: 'Orders — $_periodLabel',
                              statuses: const [
                                'pending_confirmation', 'confirmed',
                                'preparing', 'ready_for_pickup',
                                'out_for_delivery', 'delivered',
                                'cancelled', 'rejected',
                              ],
                            ),
                          ),
                          _StatCard(
                            label: 'Needs Action',
                            value: _fmt('pending_orders'),
                            icon: Icons.notification_important_outlined,
                            color: Colors.orangeAccent,
                            subtitle: 'Live',
                            onTap: () => _drill(
                              title: 'Needs Action',
                              statuses: const ['pending_confirmation'],
                              periodScoped: false,
                            ),
                          ),
                          _StatCard(
                            label: 'In Progress',
                            value: _fmt('in_progress'),
                            icon: Icons.restaurant,
                            color: Colors.amberAccent,
                            subtitle: 'Live',
                            onTap: () => _drill(
                              title: 'In Progress',
                              statuses: const [
                                'confirmed', 'preparing', 'ready_for_pickup'
                              ],
                              periodScoped: false,
                            ),
                          ),
                          _StatCard(
                            label: 'Out for Delivery',
                            value: _fmt('active_deliveries'),
                            icon: Icons.delivery_dining,
                            color: Colors.purpleAccent,
                            subtitle: 'Live',
                            onTap: () => _drill(
                              title: 'Out for Delivery',
                              statuses: const ['out_for_delivery'],
                              periodScoped: false,
                            ),
                          ),
                          _StatCard(
                            label: 'Delivered',
                            value: _fmt('delivered_count'),
                            icon: Icons.check_circle_outline,
                            color: Colors.tealAccent,
                            onTap: () => _drill(
                              title: 'Delivered — $_periodLabel',
                              statuses: const ['delivered'],
                            ),
                          ),
                          _StatCard(
                            label: 'Revenue',
                            value:
                                '₹${double.tryParse('${_data?['revenue'] ?? 0}')?.toStringAsFixed(0) ?? '0'}',
                            icon: Icons.currency_rupee,
                            color: Colors.greenAccent,
                            onTap: () => _drill(
                              title: 'Paid Orders — $_periodLabel',
                              statuses: const ['delivered'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ── Tappable stat card ────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 14),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  Row(children: [
                    Expanded(
                      child: Text(label,
                          style: GoogleFonts.poppins(
                              color: Colors.grey, fontSize: 10)),
                    ),
                    if (subtitle != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(subtitle!,
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 8,
                                fontWeight: FontWeight.bold)),
                      ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dashboard drill-down orders screen ───────────────────────────────────────

class DashboardOrdersScreen extends StatefulWidget {
  final String title;
  final List<String> statuses;
  final String? startDate;

  const DashboardOrdersScreen({
    super.key,
    required this.title,
    required this.statuses,
    this.startDate,
  });

  @override
  State<DashboardOrdersScreen> createState() =>
      _DashboardOrdersScreenState();
}

class _DashboardOrdersScreenState extends State<DashboardOrdersScreen> {
  final OrderService _svc = OrderService();
  List<Order> _orders = [];
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
      final all = await _svc.getAllOrders();
      DateTime? since;
      if (widget.startDate != null) {
        since = DateTime.tryParse(widget.startDate!);
      }
      final filtered = all.where((o) {
        if (!widget.statuses.contains(o.status)) return false;
        if (since != null && o.createdAt != null) {
          return !o.createdAt!.isBefore(since);
        }
        return true;
      }).toList();
      if (mounted) setState(() { _orders = filtered; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text(widget.title,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${_orders.length}',
                    style: const TextStyle(
                        color: _red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : _orders.isEmpty
                  ? Center(
                      child: Text('No orders',
                          style: GoogleFonts.poppins(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _red,
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

// ─── Orders (unified with filter) ────────────────────────────────────────────

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final OrderService _svc = OrderService();
  List<Order> _all = [];
  bool _loading = true;
  String? _error;
  String _filter = 'pending';
  Timer? _timer;

  static const _filters = [
    ('pending', 'Pending'),
    ('active', 'Active'),
    ('all', 'All'),
    ('delivered', 'Delivered'),
    ('rejected', 'Rejected'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_filter == 'pending') _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final orders = await _svc.getAllOrders();
      if (mounted) setState(() { _all = orders; _loading = false; });
    } catch (e) {
      if (mounted && !silent) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Order> get _filtered {
    switch (_filter) {
      case 'pending':
        return _all.where((o) => o.status == 'pending_confirmation').toList();
      case 'active':
        return _all.where((o) =>
            ['confirmed', 'preparing', 'ready_for_pickup', 'out_for_delivery']
                .contains(o.status)).toList();
      case 'delivered':
        return _all.where((o) => o.status == 'delivered').toList();
      case 'rejected':
        return _all.where((o) => o.status == 'rejected').toList();
      default:
        return _all;
    }
  }

  Future<void> _quickConfirm(Order order) async {
    final prepTime = await showDialog<int>(
      context: context,
      builder: (_) => _PrepTimeDialog(),
    );
    if (prepTime == null) return;
    try {
      await _svc.confirmOrder(order.id, prepTime);
      _load(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _quickReject(Order order) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(),
    );
    if (reason == null) return;
    try {
      await _svc.rejectOrder(order.id, reason);
      _load(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Orders',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _red), onPressed: _load),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _filters.map((f) {
                final selected = _filter == f.$1;
                final count = _filterCount(f.$1);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(count > 0 ? '${f.$2} ($count)' : f.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f.$1),
                    selectedColor: _red.withValues(alpha: 0.2),
                    checkmarkColor: _red,
                    labelStyle: TextStyle(
                      color: selected ? _red : Colors.grey,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    backgroundColor: _card,
                    side: BorderSide(color: selected ? _red : _stroke),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: filtered.isEmpty
                      ? Center(
                          child: Text('No orders',
                              style: GoogleFonts.poppins(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final order = filtered[i];
                            return _OrderCard(
                              order: order,
                              showQuickActions:
                                  order.status == 'pending_confirmation',
                              onConfirm: () => _quickConfirm(order),
                              onReject: () => _quickReject(order),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminOrderDetailScreen(
                                        orderId: order.id),
                                  ),
                                );
                                _load();
                              },
                            );
                          },
                        ),
                ),
    );
  }

  int _filterCount(String filter) {
    switch (filter) {
      case 'pending':
        return _all.where((o) => o.status == 'pending_confirmation').length;
      case 'active':
        return _all.where((o) =>
            ['confirmed', 'preparing', 'ready_for_pickup', 'out_for_delivery']
                .contains(o.status)).length;
      case 'delivered':
        return _all.where((o) => o.status == 'delivered').length;
      case 'rejected':
        return _all.where((o) => o.status == 'rejected').length;
      default:
        return _all.length;
    }
  }
}

// ─── Active Orders ────────────────────────────────────────────────────────────

class _ActiveOrdersTab extends StatefulWidget {
  const _ActiveOrdersTab();

  @override
  State<_ActiveOrdersTab> createState() => _ActiveOrdersTabState();
}

class _ActiveOrdersTabState extends State<_ActiveOrdersTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final OrderService _svc = OrderService();
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  static const _activeStatuses = [
    'pending_confirmation', 'confirmed', 'preparing',
    'ready_for_pickup', 'out_for_delivery',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final all = await _svc.getAllOrders();
      if (mounted) {
        setState(() {
          _orders = all.where((o) => _activeStatuses.contains(o.status)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _quickConfirm(Order order) async {
    final prepTime = await showDialog<int>(context: context, builder: (_) => _PrepTimeDialog());
    if (prepTime == null) return;
    try {
      await _svc.confirmOrder(order.id, prepTime);
      _load(silent: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _quickReject(Order order) async {
    final reason = await showDialog<String>(context: context, builder: (_) => _RejectDialog());
    if (reason == null) return;
    try {
      await _svc.rejectOrder(order.id, reason);
      _load(silent: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  List<Order> _group(List<String> statuses) =>
      _orders.where((o) => statuses.contains(o.status)).toList();

  Future<void> _openDetail(Order order) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(orderId: order.id)));
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pending   = _group(['pending_confirmation']);
    final inKitchen = _group(['confirmed', 'preparing']);
    final ready     = _group(['ready_for_pickup']);
    final onWay     = _group(['out_for_delivery']);
    final total = _orders.length;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Row(
          children: [
            Text('Active Orders',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            if (total > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _red, borderRadius: BorderRadius.circular(12)),
                child: Text('$total',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _red), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : total == 0
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_outline, color: Colors.grey, size: 64),
                        const SizedBox(height: 12),
                        Text('All caught up!',
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('No active orders right now.',
                            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _red,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        children: [
                          if (pending.isNotEmpty)
                            _Section(
                              title: 'Needs Action',
                              count: pending.length,
                              color: Colors.orangeAccent,
                              children: pending.map((o) => _OrderCard(
                                order: o,
                                showQuickActions: true,
                                onConfirm: () => _quickConfirm(o),
                                onReject: () => _quickReject(o),
                                onTap: () => _openDetail(o),
                              )).toList(),
                            ),
                          if (inKitchen.isNotEmpty)
                            _Section(
                              title: 'In Kitchen',
                              count: inKitchen.length,
                              color: Colors.amberAccent,
                              children: inKitchen.map((o) => _OrderCard(
                                order: o,
                                onTap: () => _openDetail(o),
                              )).toList(),
                            ),
                          if (ready.isNotEmpty)
                            _Section(
                              title: 'Ready for Pickup',
                              count: ready.length,
                              color: Colors.purpleAccent,
                              children: ready.map((o) => _OrderCard(
                                order: o,
                                onTap: () => _openDetail(o),
                              )).toList(),
                            ),
                          if (onWay.isNotEmpty)
                            _Section(
                              title: 'Out for Delivery',
                              count: onWay.length,
                              color: Colors.blueAccent,
                              isLive: true,
                              children: onWay.map((o) => _OrderCard(
                                order: o,
                                onTap: () => _openDetail(o),
                              )).toList(),
                            ),
                        ],
                      ),
                    ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final bool isLive;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.count,
    required this.color,
    required this.children,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.4))),
                child: Text('$count',
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              if (isLive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.blueAccent.withValues(alpha: 0.5))),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radio_button_checked,
                          color: Colors.blueAccent, size: 9),
                      SizedBox(width: 4),
                      Text('LIVE',
                          style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

// ─── Products ─────────────────────────────────────────────────────────────────

class _ProductsTab extends StatefulWidget {
  const _ProductsTab();

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ProductService _svc = ProductService();
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;
  final Map<int, bool> _toggling = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _svc.getProducts(),
        _svc.getCategories(),
      ]);
      if (mounted) {
        setState(() {
          _products = results[0] as List<Product>;
          _categories = results[1] as List<Category>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggle(Product p) async {
    setState(() => _toggling[p.id] = true);
    try {
      final updated = await _svc.toggleAvailability(p.id);
      if (mounted) {
        setState(() {
          final idx = _products.indexWhere((x) => x.id == p.id);
          if (idx >= 0) _products[idx] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _toggling.remove(p.id));
    }
  }

  Future<void> _openForm({Product? product}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          categories: _categories,
          product: product,
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _deleteProduct(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete Product', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${p.name}"? This cannot be undone.',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _svc.deleteProduct(p.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Products',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _red), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: _red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: _products.length,
                    itemBuilder: (_, i) {
                      final p = _products[i];
                      final toggling = _toggling[p.id] == true;
                      return Card(
                        color: _card,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: p.image.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(p.image,
                                      width: 48, height: 48, fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) =>
                                          const Icon(Icons.fastfood,
                                              color: Colors.grey)),
                                )
                              : Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: _red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.fastfood, color: _red, size: 24),
                                ),
                          title: Text(p.name,
                              style: TextStyle(
                                  color: p.isAvailable ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${p.categoryName} • ₹${p.price.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.grey, size: 20),
                                onPressed: () => _openForm(product: p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteProduct(p),
                              ),
                              toggling
                                  ? const SizedBox(
                                      width: 36, height: 36,
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: _red),
                                      ))
                                  : Switch(
                                      value: p.isAvailable,
                                      onChanged: (_) => _toggle(p),
                                      activeColor: _red,
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─── Delivery Staff (used from Settings) ─────────────────────────────────────

class DeliveryStaffManagementScreen extends StatefulWidget {
  const DeliveryStaffManagementScreen({super.key});

  @override
  State<DeliveryStaffManagementScreen> createState() => _DeliveryStaffManagementScreenState();
}

class _DeliveryStaffManagementScreenState extends State<DeliveryStaffManagementScreen> {
  final DeliveryStaffService _svc = DeliveryStaffService();
  List<DeliveryStaff> _staff = [];
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
      final list = await _svc.getDeliveryStaff();
      if (mounted) setState(() { _staff = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _setDefault(int id) async {
    try {
      await _svc.setDefaultDelivery(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _addStaff() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateDeliveryStaffScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Delivery Staff',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _red), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addStaff,
        backgroundColor: _red,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : _staff.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delivery_dining,
                              color: Colors.grey, size: 64),
                          const SizedBox(height: 12),
                          Text('No delivery staff yet',
                              style: GoogleFonts.poppins(color: Colors.grey)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _addStaff,
                            icon: const Icon(Icons.person_add, color: _red),
                            label: const Text('Add Staff',
                                style: TextStyle(color: _red)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                        itemCount: _staff.length,
                        itemBuilder: (_, i) {
                          final s = _staff[i];
                          return Card(
                            color: _card,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    s.isDefaultDelivery ? _red : Colors.grey[800],
                                child: Text(
                                  (s.name.isNotEmpty ? s.name : '?')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Row(children: [
                                Text(s.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                if (s.isDefaultDelivery) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: _red,
                                        borderRadius: BorderRadius.circular(4)),
                                    child: const Text('DEFAULT',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ]),
                              subtitle: Text(s.phoneNumber,
                                  style: const TextStyle(color: Colors.grey)),
                              trailing: s.isDefaultDelivery
                                  ? null
                                  : TextButton(
                                      onPressed: () => _setDefault(s.id),
                                      child: const Text('Set Default',
                                          style: TextStyle(color: _red)),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ─── Profile ──────────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await OrderService().getMe();
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
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _stroke),
                    ),
                    child: Row(children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: _red, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.admin_panel_settings,
                            size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_profile?['name'] ?? 'Admin',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(_profile?['phone_number'] ?? '',
                                style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: _red,
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Text('ADMIN',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      minimumSize: const Size.fromHeight(52),
                    ),
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
  final bool showQuickActions;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  const _OrderCard({
    required this.order,
    required this.onTap,
    this.showQuickActions = false,
    this.onConfirm,
    this.onReject,
  });

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${order.orderNumber}',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      if (order.customerName.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.person_outline,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(order.customerName,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ]),
                      Text(
                        order.createdAt != null
                            ? DateFormat('MMM d, h:mm a').format(order.createdAt!)
                            : '',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${order.totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                          color: _red, fontWeight: FontWeight.w700, fontSize: 16)),
                  if (order.customerPhone.isNotEmpty)
                    GestureDetector(
                      onTap: () => launchUrl(
                          Uri.parse('tel:${order.customerPhone}')),
                      child: const Icon(Icons.call_rounded,
                          color: Colors.greenAccent, size: 18),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                ]),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _badge(
                  order.status.replaceAll('_', ' ').toUpperCase(),
                  _statusColor(order.status),
                ),
                if (order.paymentMethod == 'online') ...[
                  const SizedBox(width: 6),
                  _badge(
                    order.paymentStatus.toUpperCase(),
                    order.paymentStatus == 'paid' ? Colors.green : Colors.amber,
                  ),
                ],
                if (order.paymentMethod == 'cod') ...[
                  const SizedBox(width: 6),
                  _badge('COD', Colors.grey),
                ],
                if (order.estimatedDeliveryTime != null &&
                    DateTime.now().isAfter(order.estimatedDeliveryTime!) &&
                    !['delivered', 'cancelled', 'rejected'].contains(order.status)) ...[
                  const SizedBox(width: 6),
                  _badge('⚠ LATE', Colors.redAccent),
                ],
              ]),
              if (showQuickActions) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Reject', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Confirm', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 0.5),
        ),
        child: Text(text,
            style:
                TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      );
}

// ─── Quick-action dialogs ─────────────────────────────────────────────────────

class _PrepTimeDialog extends StatefulWidget {
  @override
  State<_PrepTimeDialog> createState() => _PrepTimeDialogState();
}

class _PrepTimeDialogState extends State<_PrepTimeDialog> {
  int _mins = 20;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: const Text('Confirm Order', style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Estimated prep time (minutes):',
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.white),
            onPressed: () { if (_mins > 5) setState(() => _mins -= 5); },
          ),
          Text('$_mins min',
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => setState(() => _mins += 5),
          ),
        ]),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _mins),
          style: ElevatedButton.styleFrom(backgroundColor: _red),
          child: const Text('Confirm', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: const Text('Reject Order', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          labelText: 'Reason (optional)',
          labelStyle: TextStyle(color: Colors.grey),
        ),
        maxLines: 2,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          child: const Text('Reject', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ─── Product form screen ──────────────────────────────────────────────────────

class ProductFormScreen extends StatefulWidget {
  final List<Category> categories;
  final Product? product;

  const ProductFormScreen({super.key, required this.categories, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _svc = ProductService();

  late TextEditingController _name;
  late TextEditingController _description;
  late TextEditingController _price;
  late TextEditingController _image;
  late TextEditingController _prepTime;
  late List<Category> _categories;
  int? _categoryId;
  bool _isAvailable = true;
  bool _isFeatured = false;
  bool _isAddon = false;
  bool _saving = false;
  bool _creatingCategory = false;

  @override
  void initState() {
    super.initState();
    _categories = List<Category>.from(widget.categories);
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(
        text: p != null ? p.price.toStringAsFixed(2) : '');
    _image = TextEditingController(text: p?.image ?? '');
    _prepTime = TextEditingController(
        text: '${p?.preparationTime ?? 15}');
    _categoryId = p?.categoryId;
    _isAvailable = p?.isAvailable ?? true;
    _isFeatured = p?.isFeatured ?? false;
    _isAddon = p?.isAddon ?? false;
  }

  Future<void> _createCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('New Category',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextFormField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Category name',
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _red),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            child: const Text('Create',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;

    setState(() => _creatingCategory = true);
    try {
      final created = await _svc.createCategory(name);
      if (mounted) {
        setState(() {
          _categories.add(created);
          _categoryId = created.id;
          _creatingCategory = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category "${created.name}" created')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _creatingCategory = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _image.dispose();
    _prepTime.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'category': _categoryId,
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price': _price.text.trim(),
      'image': _image.text.trim(),
      'preparation_time': int.tryParse(_prepTime.text) ?? 15,
      'is_available': _isAvailable,
      'is_featured': _isFeatured,
      'is_addon': _isAddon,
    };
    try {
      if (widget.product == null) {
        await _svc.createProduct(data);
      } else {
        await _svc.updateProduct(widget.product!.id, data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text(isEdit ? 'Edit Product' : 'Add Product',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _red)))
              : TextButton(
                  onPressed: _save,
                  child: const Text('Save', style: TextStyle(color: _red, fontWeight: FontWeight.bold)),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field('Product Name', _name, required: true),
            const SizedBox(height: 12),
            _field('Description', _description, maxLines: 3),
            const SizedBox(height: 12),
            _field('Price (₹)', _price,
                required: true,
                keyboardType: TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            _field('Image URL', _image),
            const SizedBox(height: 12),
            _field('Prep Time (mins)', _prepTime,
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            // Category selector + inline create button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _categoryId,
                    decoration: _inputDec('Category'),
                    dropdownColor: _card,
                    style: const TextStyle(color: Colors.white),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                            value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) => v == null ? 'Select a category' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Create new category',
                  child: SizedBox(
                    height: 54,
                    child: _creatingCategory
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _red),
                            ),
                          )
                        : IconButton.filled(
                            onPressed: _createCategory,
                            style: IconButton.styleFrom(
                              backgroundColor: _red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _toggle('Available', _isAvailable,
                    (v) => setState(() => _isAvailable = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _toggle('Featured', _isFeatured,
                    (v) => setState(() => _isFeatured = v)),
              ),
            ]),
            const SizedBox(height: 12),
            _toggle(
              'Add-on (Coke / Juice / Extra)',
              _isAddon,
              (v) => setState(() => _isAddon = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool required = false,
      int maxLines = 1,
      TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDec(label),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _stroke),
        ),
        child: Row(children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const Spacer(),
          Switch(value: value, onChanged: onChanged, activeColor: _red),
        ]),
      );

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _red),
        ),
      );
}

// ─── Create delivery staff screen ─────────────────────────────────────────────

class CreateDeliveryStaffScreen extends StatefulWidget {
  const CreateDeliveryStaffScreen({super.key});

  @override
  State<CreateDeliveryStaffScreen> createState() =>
      _CreateDeliveryStaffScreenState();
}

class _CreateDeliveryStaffScreenState
    extends State<CreateDeliveryStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _svc = DeliveryStaffService();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _svc.createDeliveryStaff(
        phone: _phone.text.trim(),
        name: _name.text.trim(),
        password: _password.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery staff created')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Add Delivery Staff',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            _field('Full Name', _name, required: true),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('Phone Number'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().length < 10) return 'Enter valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('Password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 6) return 'Min 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create Account',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool required = false}) =>
      TextFormField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDec(label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      );

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _red),
        ),
      );
}
