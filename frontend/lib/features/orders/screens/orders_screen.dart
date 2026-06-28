import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../../shared/widgets/login_prompt_widget.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import 'order_tracking_screen.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderService _orderService = OrderService();
  final _scrollController = ScrollController();

  bool _isLoggedIn = true;
  final List<Order> _orders = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  Timer? _autoReloadTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _scrollController.addListener(_onScroll);
    _autoReloadTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _silentReload(),
    );
  }

  @override
  void dispose() {
    _autoReloadTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _silentReload() async {
    if (_loading || !_isLoggedIn) return;
    try {
      final data = await _orderService.getMyOrdersPaged(page: 1);
      final results = (data['results'] as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        for (final newOrder in results) {
          final idx = _orders.indexWhere((o) => o.id == newOrder.id);
          if (idx != -1) {
            _orders[idx] = newOrder;
          } else {
            _orders.insert(0, newOrder);
          }
        }
      });
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _init() async {
    final loggedIn = await TokenStorage.isLoggedIn();
    if (!mounted) return;
    setState(() => _isLoggedIn = loggedIn);
    if (loggedIn) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _orderService.getMyOrdersPaged(page: _page);
      final results = (data['results'] as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _orders.addAll(results);
        _page++;
        _hasMore = data['next'] != null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _refresh() async {
    setState(() { _orders.clear(); _page = 1; _hasMore = true; _error = null; });
    await _loadMore();
  }

  String _statusLabel(String s) => s
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Color _statusColor(String s) {
    switch (s) {
      case 'delivered': return Colors.greenAccent;
      case 'rejected': case 'cancelled': return Colors.redAccent;
      case 'pending_confirmation': return Colors.orangeAccent;
      default: return _brandRed;
    }
  }

  Color _paymentStatusColor(String s) {
    switch (s) {
      case 'paid': return Colors.greenAccent;
      case 'failed': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final local = d.toLocal();
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${local.day} ${m[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: Colors.white,
        title: const Text('Orders', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: !_isLoggedIn
          ? const LoginPromptWidget(
              icon: Icons.receipt_long_outlined,
              title: 'Your Orders',
              subtitle: 'Login to view your order history and track deliveries.',
            )
          : _orders.isEmpty && _loading
              ? const Center(child: CircularProgressIndicator(color: _brandRed))
              : _orders.isEmpty && _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _refresh,
                            child: const Text('Retry', style: TextStyle(color: _brandRed))),
                      ]))
                  : _orders.isEmpty
                      ? const Center(child: Text('No orders yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16)))
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          color: _brandRed,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _orders.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _orders.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator(color: _brandRed)),
                                );
                              }
                              final order = _orders[index];
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => OrderTrackingScreen(orderId: order.id)),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color: _panel,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _stroke)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(
                                            order.items.isNotEmpty
                                                ? order.items.map((e) => '${e.quantity}x ${e.productName}').join(', ')
                                                : 'Meal from HDK Kitchen',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(_fmtDate(order.createdAt),
                                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        ]),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                            color: _statusColor(order.status).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20)),
                                        child: Text(_statusLabel(order.status),
                                            style: TextStyle(
                                                color: _statusColor(order.status),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ]),
                                    const SizedBox(height: 12),
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Text('₹${order.totalAmount.toStringAsFixed(0)} · ${order.items.length} item(s)',
                                          style: const TextStyle(color: Colors.grey)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: _paymentStatusColor(order.paymentStatus)
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12)),
                                        child: Text(
                                            '${order.paymentMethod.toUpperCase()} • ${order.paymentStatus.toUpperCase()}',
                                            style: TextStyle(
                                                color: _paymentStatusColor(order.paymentStatus),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ]),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
    );
  }
}
