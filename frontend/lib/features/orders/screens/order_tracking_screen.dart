import 'dart:async';
import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/order_service.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final OrderService _orderService = OrderService();

  // Ordered tracking steps shown in the stepper.
  static const List<Map<String, String>> _steps = [
    {'key': 'confirmed', 'label': 'Confirmed'},
    {'key': 'preparing', 'label': 'Preparing'},
    {'key': 'ready_for_pickup', 'label': 'Ready for Pickup'},
    {'key': 'out_for_delivery', 'label': 'Out for Delivery'},
    {'key': 'delivered', 'label': 'Delivered'},
  ];

  Timer? _pollingTimer;
  Order? _order;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final order = await _orderService.getOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
        _error = null;
      });
      if (order.status == 'delivered' ||
          order.status == 'cancelled' ||
          order.status == 'rejected') {
        _pollingTimer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  int _currentStepIndex(String status) {
    final idx = _steps.indexWhere((s) => s['key'] == status);
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Track Order',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _brandRed))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.redAccent)))
              : _buildBody(_order!),
    );
  }

  Widget _buildBody(Order order) {
    final isCancelled =
        order.status == 'cancelled' || order.status == 'rejected';
    final currentIdx = _currentStepIndex(order.status);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${order.orderNumber}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  'Payment: ${order.paymentMethod.toUpperCase()} '
                  '(${order.paymentStatus})',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text('Total: ₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (isCancelled)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Text(
                    order.status == 'rejected'
                        ? 'Order was rejected by the restaurant.'
                        : 'Order was cancelled.',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ),
            )
          else
            _buildStepper(currentIdx),
          const SizedBox(height: 24),
          if (order.items.isNotEmpty) ...[
            const Text('Items',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${item.quantity}x ${item.productName}',
                          style: const TextStyle(color: Colors.grey),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 12),
                    Text('₹${(item.price * item.quantity).toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepper(int currentIdx) {
    return Column(
      children: List.generate(_steps.length, (i) {
        final reached = currentIdx >= i && currentIdx != -1;
        final isLast = i == _steps.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: reached ? _brandRed : _panel,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: reached ? _brandRed : _stroke, width: 2),
                    ),
                    child: reached
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: reached ? _brandRed : _stroke,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 2),
                child: Text(
                  _steps[i]['label']!,
                  style: TextStyle(
                    color: reached ? Colors.white : Colors.grey,
                    fontSize: 16,
                    fontWeight: reached ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
