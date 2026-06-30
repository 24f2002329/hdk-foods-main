import 'dart:async';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/order_websocket_service.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../auth/screens/login_screen.dart';
import '../../delivery_staff/models/delivery_staff.dart';
import '../../delivery_staff/services/delivery_staff_service.dart';
import '../../orders/services/order_service.dart';
import '../../orders/screens/admin_order_detail_screen.dart';
import '../../orders/screens/admin_create_order_screen.dart';
import 'kds_screen.dart';
import 'dispatch_screen.dart';
import 'sentiment_dashboard_screen.dart';
import '../../products/services/product_service.dart';
import '../../products/screens/modifier_management_screen.dart';
import '../../settings/screens/site_config_screen.dart';
import '../../settings/services/notification_service.dart';
import '../../settings/screens/notification_screen.dart';

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

  void _onNavTap(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _DashboardTab(),
          KdsScreen(),
          DispatchScreen(),
          SentimentDashboardScreen(),
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
              icon: Icon(Icons.soup_kitchen_outlined),
              selectedIcon: Icon(Icons.soup_kitchen, color: _red),
              label: 'KDS'),
          NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping, color: _red),
              label: 'Dispatch'),
          NavigationDestination(
              icon: Icon(Icons.sentiment_satisfied_alt_outlined),
              selectedIcon: Icon(Icons.sentiment_satisfied_alt, color: _red),
              label: 'Sentiment'),
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
  List<Map<String, dynamic>> _chartData = [];
  List<Product> _unavailableProducts = [];
  bool _loading = true;
  String? _error;
  String _period = 'today';
  final OrderService _svc = OrderService();
  Timer? _timer;
  AdminOrderWebSocketService? _ws;

  @override
  void initState() {
    super.initState();
    _load();
    _loadChart();
    _loadUnavailableProducts();
    _timer = Timer.periodic(
        const Duration(seconds: 30), (_) {
          _load(silent: true);
          _loadUnavailableProducts();
        });

    _ws = AdminOrderWebSocketService();
    _ws!.connect();
    _ws!.stream.listen((msg) {
      if (msg['type'] == 'new_order' || msg['type'] == 'order_update') {
        _load(silent: true);
        _loadUnavailableProducts();
      }
    });
  }

  Future<void> _loadUnavailableProducts() async {
    try {
      final list = await ProductService().getProducts();
      final filtered = list.where((p) => !p.isAvailable).toList();
      if (mounted) {
        setState(() {
          _unavailableProducts = filtered;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ws?.dispose();
    super.dispose();
  }

  int _unreadNotificationCount = 0;

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final data = await _svc.getDashboard(period: _period);
      int unread = 0;
      try {
        final res = await NotificationService().getNotifications();
        unread = res['unread_count'] as int;
      } catch (_) {}
      
      if (mounted) {
        setState(() {
          _data = data;
          _unreadNotificationCount = unread;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationScreen(),
      ),
    );
    _load(silent: true);
  }

  Future<void> _loadChart() async {
    try {
      final analytics = await _svc.getAnalytics(days: 30);
      final rows = (analytics['data'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (mounted) setState(() => _chartData = rows);
    } catch (_) {}
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

  Widget _buildTopProductsChart() {
    final list = _data?['top_products'] as List?;
    if (list == null || list.isEmpty) return const SizedBox.shrink();

    double maxQty = 1;
    for (final item in list) {
      final qty = (item['quantity'] as num).toDouble();
      if (qty > maxQty) maxQty = qty;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text('Top Products Sold (Units)',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxQty * 1.15,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1E1E1E),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final name = list[groupIndex]['name'] as String;
                    return BarTooltipItem(
                      '$name\n${rod.toY.toInt()} units',
                      const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= list.length) {
                        return const SizedBox.shrink();
                      }
                      final name = list[index]['name'] as String;
                      final shortName = name.length > 8 ? '${name.substring(0, 7)}..' : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(shortName, style: const TextStyle(color: Colors.grey, fontSize: 8)),
                      );
                    },
                    reservedSize: 24,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 8)),
                    reservedSize: 22,
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(
                list.length,
                (i) {
                  final qty = (list[i]['quantity'] as num).toDouble();
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: qty,
                        color: i == 0 ? Colors.amber : (i == 1 ? Colors.blueAccent : Colors.deepOrangeAccent),
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxQty * 1.1,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBusyHoursChart() {
    final list = _data?['hourly_distribution'] as List?;
    if (list == null || list.isEmpty) return const SizedBox.shrink();

    double maxCount = 1;
    List<FlSpot> spots = [];
    for (int i = 0; i < list.length; i++) {
      final count = (list[i]['count'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), count));
      if (count > maxCount) maxCount = count;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text('Peak Order Times (Busy Hours)',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Total orders by hour of day',
            style: GoogleFonts.poppins(
                color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: const Color(0xFF2A2A2A),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(color: Colors.grey, fontSize: 8),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 4,
                    getTitlesWidget: (v, _) {
                      final hour = v.toInt();
                      if (hour < 0 || hour >= 24) return const SizedBox.shrink();
                      final suffix = hour >= 12 ? 'PM' : 'AM';
                      final disp = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                      return Text('$disp$suffix', style: const TextStyle(color: Colors.grey, fontSize: 8));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.deepOrange,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                     show: true,
                     color: Colors.deepOrange.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryAlertCard() {
    if (_unavailableProducts.isEmpty) return const SizedBox.shrink();

    final names = _unavailableProducts.map((p) => p.name).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF1E1E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF1E1E).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF1E1E), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory Warning (${_unavailableProducts.length} Items Out of Stock)',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The following items are marked as unavailable and hidden from customers:\n$names',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: _red),
                onPressed: _openNotifications,
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _red,
                      shape: BoxShape.circle,
                      border: Border.all(color: _surface, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_unreadNotificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
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
          ? const Center(child: HdkPreloader())
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
                      _buildInventoryAlertCard(),
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
                                'preparing',
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
                                'confirmed', 'preparing'
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
                      if (_chartData.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text('30-Day Trend',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Orders per day',
                            style: GoogleFonts.poppins(
                                color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: const Color(0xFF2A2A2A),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (v, _) => Text(
                                      v.toInt().toString(),
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 9),
                                    ),
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 20,
                                    interval: (_chartData.length / 5).ceilToDouble(),
                                    getTitlesWidget: (v, _) {
                                      final i = v.toInt();
                                      if (i < 0 || i >= _chartData.length) {
                                        return const SizedBox.shrink();
                                      }
                                      final date = _chartData[i]['date'] as String;
                                      return Text(date.substring(5),
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 8));
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                    _chartData.length,
                                    (i) => FlSpot(
                                      i.toDouble(),
                                      (_chartData[i]['order_count'] as num).toDouble(),
                                    ),
                                  ),
                                  isCurved: true,
                                  color: _red,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: _red.withValues(alpha: 0.08),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Revenue (₹)',
                            style: GoogleFonts.poppins(
                                color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 160,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: const Color(0xFF2A2A2A),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (v, _) => Text(
                                      '₹${(v / 1000).toStringAsFixed(0)}k',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 9),
                                    ),
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                    _chartData.length,
                                    (i) => FlSpot(
                                      i.toDouble(),
                                      (_chartData[i]['revenue'] as num).toDouble(),
                                    ),
                                  ),
                                  isCurved: true,
                                  color: Colors.greenAccent,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.greenAccent.withValues(alpha: 0.07),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      _buildBusyHoursChart(),
                      // Additional Metrics Section
                      const SizedBox(height: 28),
                      Text('Business Insights',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _InsightCard(
                              label: 'Avg Order Value',
                              value: '₹${_data?['average_order_value'] ?? 0}',
                              icon: Icons.auto_graph_rounded,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InsightCard(
                              label: 'Customer Rating',
                              value: '${_data?['average_rating'] ?? 0} ★',
                              icon: Icons.star_rate_rounded,
                              color: Colors.amberAccent,
                              subtitle: '${_data?['total_reviews'] ?? 0} reviews',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _InsightCard(
                              label: 'Cancelled Orders',
                              value: '${_data?['cancelled_count'] ?? 0}',
                              icon: Icons.cancel_outlined,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InsightCard(
                              label: 'Rejected Orders',
                              value: '${_data?['rejected_count'] ?? 0}',
                              icon: Icons.do_not_disturb_on_outlined,
                              color: Colors.deepOrangeAccent,
                            ),
                          ),
                        ],
                      ),
                      if (_data?['top_products'] != null && (_data!['top_products'] as List).isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text('Top Selling Products 🏆',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _stroke),
                          ),
                          child: Column(
                            children: (_data!['top_products'] as List).map<Widget>((item) {
                              final index = (_data!['top_products'] as List).indexOf(item) + 1;
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: index == 1 ? Colors.amber : (index == 2 ? Colors.grey : Colors.brown[300]),
                                  child: Text('$index', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(item['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text('${item['quantity']} units sold', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                trailing: Text('₹${(item['revenue'] as num).toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      _buildTopProductsChart(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _InsightCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ],
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
          ? const Center(child: HdkPreloader())
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
  bool _firstLoadDone = false;

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
      if (mounted) {
        setState(() {
          _all = orders;
          _loading = false;
          if (!_firstLoadDone) {
            _firstLoadDone = true;
            final pendingCount = _all.where((o) => o.status == 'pending_confirmation').length;
            _filter = pendingCount == 0 ? 'all' : 'pending';
          }
        });
      }
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
            ['confirmed', 'preparing', 'out_for_delivery']
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
    final reviewed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PendingOrderReviewDialog(order: order),
    );
    if (reviewed != true) return;
    if (!mounted) return;

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

  Future<void> _openCreateOrderScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminCreateOrderScreen(),
      ),
    );
    if (result == true) {
      _load();
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
          IconButton(
            icon: const Icon(Icons.add_shopping_cart, color: _red),
            onPressed: _openCreateOrderScreen,
          ),
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
          ? const Center(child: HdkPreloader())
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
            ['confirmed', 'preparing', 'out_for_delivery']
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
  AdminOrderWebSocketService? _ws;

  static const _activeStatuses = [
    'pending_confirmation', 'confirmed', 'preparing',
    'out_for_delivery',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _load(silent: true));

    _ws = AdminOrderWebSocketService();
    _ws!.connect();
    _ws!.stream.listen((msg) {
      if (msg['type'] == 'new_order' || msg['type'] == 'order_update') {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ws?.dispose();
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
    final reviewed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PendingOrderReviewDialog(order: order),
    );
    if (reviewed != true) return;
    if (!mounted) return;

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
          ? const Center(child: HdkPreloader())
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
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ModifierGroupsManagementScreen(),
              ),
            ),
            icon: const Icon(Icons.tune, color: _red, size: 18),
            label: const Text('Modifiers',
                style: TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          IconButton(icon: const Icon(Icons.refresh, color: _red), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: _red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: HdkPreloader())
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
                                      child: Center(
                                        child: HdkPreloader(width: 20, height: 20),
                                      ),
                                    )
                                  : Switch(
                                      value: p.isAvailable,
                                      onChanged: (_) => _toggle(p),
                                      activeThumbColor: _red,
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
          ? const Center(child: HdkPreloader())
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
          ? const Center(child: HdkPreloader())
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
                            ? DateFormat('MMM d, h:mm a').format(order.createdAt!.toLocal())
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

class _PendingOrderReviewDialog extends StatefulWidget {
  final Order order;

  const _PendingOrderReviewDialog({required this.order});

  @override
  State<_PendingOrderReviewDialog> createState() =>
      _PendingOrderReviewDialogState();
}

class _PendingOrderReviewDialogState extends State<_PendingOrderReviewDialog> {
  final OrderService _svc = OrderService();
  late Order _order = widget.order;
  bool _loading = false;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final fresh = await _svc.getOrder(widget.order.id);
      if (mounted) {
        setState(() => _order = fresh);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editOrder() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminOrderDetailScreen(orderId: widget.order.id),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final hasDiscount = order.discountAmount > 0;
    final priceChanged = order.originalTotal != null &&
        order.originalTotal != order.totalAmount;

    return Dialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: _red, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Review Order #${order.orderNumber}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: Center(
                        child: HdkPreloader(width: 18, height: 18),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                order.customerName.isNotEmpty
                    ? order.customerName
                    : 'Pending order confirmation',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (order.customerPhone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  order.customerPhone,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
              if (order.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, h:mm a').format(order.createdAt!.toLocal()),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _stroke),
                        ),
                        child: Column(
                          children: order.items
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.quantity}x ${item.productName}',
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ),
                                      Text(
                                        'Rs ${(
                                          item.price * item.quantity
                                        ).toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _stroke),
                        ),
                        child: Column(
                          children: [
                            if (priceChanged) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Original Total',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    'Rs ${order.originalTotal!.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      decoration:
                                          TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (hasDiscount) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    order.discountReason.isNotEmpty
                                        ? 'Discount (${order.discountReason})'
                                        : 'Discount',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                  Text(
                                    '-Rs ${order.discountAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Final Total',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Rs ${order.totalAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: _red,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (order.deliveryNotes.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _stroke),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery Notes',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                order.deliveryNotes,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : _editOrder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _stroke),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: const Text('Edit Order'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _loading ? null : () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _loading ? null : () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  final _picker = ImagePicker();

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
  File? _pickedImageFile;
  bool _uploadingImage = false;

  // Modifier groups
  List<ModifierGroup> _allModifierGroups = [];
  Set<int> _selectedModifierGroupIds = {};
  bool _loadingModifiers = true;

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

    // Pre-select modifier groups already assigned to this product
    if (p != null) {
      _selectedModifierGroupIds = p.modifierGroups.map((g) => g.id).toSet();
    }
    _loadModifierGroups();
  }

  Future<void> _loadModifierGroups() async {
    try {
      final groups = await ProductService().getModifierGroups();
      if (mounted) {
        setState(() {
          _allModifierGroups = groups;
          _loadingModifiers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingModifiers = false);
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (xfile == null) return;
      setState(() {
        _pickedImageFile = File(xfile.path);
        _image.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: _red),
            title: const Text('Camera', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: _red),
            title: const Text('Gallery', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
          ),
          if (_pickedImageFile != null || _image.text.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.grey),
              title: const Text('Remove image', style: TextStyle(color: Colors.grey)),
              onTap: () {
                setState(() { _pickedImageFile = null; _image.clear(); });
                Navigator.pop(context);
              },
            ),
        ]),
      ),
    );
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
      'modifier_groups': _selectedModifierGroupIds.toList(),
    };
    try {
      Product saved;
      if (widget.product == null) {
        saved = await _svc.createProduct(data);
      } else {
        saved = await _svc.updateProduct(widget.product!.id, data);
      }

      // Upload image file if one was picked
      if (_pickedImageFile != null) {
        setState(() { _uploadingImage = true; });
        await _svc.uploadImage(saved.id, _pickedImageFile!);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() { _saving = false; _uploadingImage = false; });
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
          _saving || _uploadingImage
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Center(
                        child: HdkPreloader(width: 20, height: 20),
                      ),
                      if (_uploadingImage)
                        const Text('Uploading...', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ))
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
            Text(
              'Product Image',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_pickedImageFile != null || _image.text.trim().isNotEmpty) ...[
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _stroke),
                    image: DecorationImage(
                      image: _pickedImageFile != null
                          ? FileImage(_pickedImageFile!) as ImageProvider
                          : NetworkImage(_image.text.trim()),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.edit, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _image,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDec(_pickedImageFile != null ? 'Picked from device (will upload)' : 'Image URL (optional)'),
                  readOnly: _pickedImageFile != null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Upload'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: const BorderSide(color: _red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
            if (_uploadingImage)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(color: _red),
              ),
            const SizedBox(height: 16),
            _field('Prep Time (mins)', _prepTime,
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            // Category selector + inline create button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _categoryId,
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
                            child: Center(
                              child: HdkPreloader(width: 22, height: 22),
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
            const SizedBox(height: 24),
            // ── Modifier Groups Section ──
            Text('Modifier Groups',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Assign customization options (Size, Spice, etc.) to this product.',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 10),
            if (_loadingModifiers)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: HdkPreloader(width: 20, height: 20),
                ),
              )
            else if (_allModifierGroups.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Colors.grey, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No modifier groups created yet. Go to Products → Modifiers to create some.',
                      style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ]),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allModifierGroups.map((g) {
                  final selected = _selectedModifierGroupIds.contains(g.id);
                  return FilterChip(
                    label: Text(g.name),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedModifierGroupIds.add(g.id);
                        } else {
                          _selectedModifierGroupIds.remove(g.id);
                        }
                      });
                    },
                    selectedColor: _red.withValues(alpha: 0.2),
                    checkmarkColor: _red,
                    labelStyle: TextStyle(
                      color: selected ? _red : Colors.grey[400],
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    backgroundColor: _card,
                    side: BorderSide(
                      color: selected ? _red : _stroke,
                    ),
                    avatar: selected
                        ? null
                        : Icon(Icons.add, color: Colors.grey[600], size: 16),
                  );
                }).toList(),
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
          Switch(value: value, onChanged: onChanged, activeThumbColor: _red),
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
                  ? const Center(
                      child: HdkPreloader(width: 20, height: 20),
                    )
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
