import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/token_storage.dart';
import '../../../shared/widgets/login_prompt_widget.dart';
import '../../cart/screens/cart_screen.dart';
import '../../cart/services/cart_provider.dart';
import '../../home/services/product_service.dart';
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

  int? _reorderingId;

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

  Future<void> _reorder(Order order) async {
    if (order.items.isEmpty || _reorderingId != null) return;
    setState(() => _reorderingId = order.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final products = await ProductService.getProducts();
      final byId = {for (final p in products) p.id: p};
      if (!mounted) return;
      final cart = context.read<CartProvider>();
      cart.clearCart();
      int added = 0;
      int missing = 0;
      for (final line in order.items) {
        final product = line.productId != null ? byId[line.productId] : null;
        if (product == null || !product.isAvailable) {
          missing++;
          continue;
        }
        cart.addProduct(product, quantity: line.quantity);
        added++;
      }
      if (added == 0) {
        messenger.showSnackBar(const SnackBar(
            content: Text('These items are no longer available.')));
        return;
      }
      if (missing > 0) {
        messenger.showSnackBar(SnackBar(
          content: Text('$added item(s) added · $missing unavailable'),
          backgroundColor: _panel,
        ));
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not reorder. Please try again.')));
    } finally {
      if (mounted) setState(() => _reorderingId = null);
    }
  }

  String _statusLabel(String s) => s
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Color _statusColor(String s) {
    switch (s) {
      case 'pending_confirmation': return const Color(0xFFFFB300); // amber
      case 'confirmed': return const Color(0xFF3B9DFF);            // blue
      case 'preparing': return const Color(0xFFB061FF);            // purple
      case 'out_for_delivery': return const Color(0xFF00C2D1);     // cyan
      case 'delivered': return const Color(0xFF2ECC71);            // green
      case 'cancelled': return const Color(0xFFFF6B6B);            // soft red
      case 'rejected': return const Color(0xFFE53935);             // deep red
      default: return _brandRed;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'pending_confirmation': return Icons.hourglass_top_rounded;
      case 'confirmed': return Icons.check_circle_outline_rounded;
      case 'preparing': return Icons.restaurant_rounded;
      case 'out_for_delivery': return Icons.delivery_dining_rounded;
      case 'delivered': return Icons.task_alt_rounded;
      case 'cancelled': return Icons.cancel_outlined;
      case 'rejected': return Icons.block_rounded;
      default: return Icons.receipt_long_rounded;
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
    final h24 = local.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = h24 < 12 ? 'AM' : 'PM';
    return '${local.day} ${m[local.month - 1]} ${local.year}, $h12:$mm $ampm';
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = _statusColor(order.status);
    final shownItems = order.items.take(3).toList();
    final remaining = order.items.length - shownItems.length;
    final reordering = _reorderingId == order.id;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header: order ref + date · status chip ──
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Text(
            _fmtDate(order.createdAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_statusIcon(order.status), color: statusColor, size: 13),
            const SizedBox(width: 5),
            Text(_statusLabel(order.status),
                style: TextStyle(
                    color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),

      // ── Dishes: max 3 small muted lines, +N more ──
      if (shownItems.isEmpty)
        const Text('Meal from HDK Kitchen',
            style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 12))
      else
        ...shownItems.map((it) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${it.quantity}× ${it.productName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
              ),
            )),
      if (remaining > 0)
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            '+$remaining more item${remaining > 1 ? 's' : ''}',
            style: const TextStyle(
                color: Color(0xFF6E6E6E), fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ),

      const Divider(color: _stroke, height: 24),

      // ── Footer: total · items + payment chip ──
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('₹${order.totalAmount.toStringAsFixed(0)} · ${order.items.length} item(s)',
            style: const TextStyle(color: Colors.grey)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: _paymentStatusColor(order.paymentStatus).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Text(
              '${order.paymentMethod.toUpperCase()} • ${order.paymentStatus.toUpperCase()}',
              style: TextStyle(
                  color: _paymentStatusColor(order.paymentStatus),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 12),

      // ── Reorder button ──
      SizedBox(
        width: double.infinity,
        height: 40,
        child: OutlinedButton.icon(
          onPressed: (order.items.isEmpty || _reorderingId != null)
              ? null
              : () => _reorder(order),
          icon: reordering
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: _brandRed, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded, size: 18),
          label: Text(reordering ? 'Adding…' : 'Reorder'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _brandRed,
            disabledForegroundColor: Colors.grey,
            side: BorderSide(
                color: _reorderingId != null ? _stroke : _brandRed.withValues(alpha: 0.6)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    ]);
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
                                  child: _buildOrderCard(order),
                                ),
                              );
                            },
                          ),
                        ),
    );
  }
}
