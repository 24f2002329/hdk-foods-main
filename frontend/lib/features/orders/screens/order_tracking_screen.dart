import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/widgets/error_retry.dart';
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
  bool _modifiedDialogShown = false;

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
      var order = await _orderService.getOrder(widget.orderId);

      if (order.paymentMethod == 'online' &&
          order.paymentStatus == 'pending') {
        try {
          order = await _orderService.verifyPayment(orderId: widget.orderId);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
        _error = null;
      });

      // Show the modified-order popup once when the chef has changed the order
      // and it is now confirmed.
      if (order.isModifiedByStaff &&
          order.status == 'confirmed' &&
          !_modifiedDialogShown) {
        _modifiedDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showModifiedOrderDialog(order);
        });
      }

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

  Future<void> _showModifiedOrderDialog(Order order) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ModifiedOrderDialog(order: order),
    );

    if (accepted == null || !mounted) return;

    try {
      await _orderService.acknowledgeChanges(
        orderId: order.id,
        accepted: accepted,
      );
      if (accepted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order accepted! Tracking updated.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Order cancelled. If you already paid, '
                'a refund will be processed in 3–5 business days.',
              ),
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      _modifiedDialogShown = false; // allow retry
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
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
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
                if (order.originalTotal != null &&
                    order.originalTotal != order.totalAmount) ...[
                  Text(
                    '₹${order.originalTotal!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
                Text('Total: ₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                if (order.discountAmount > 0)
                  Text(
                    'Discount: -₹${order.discountAmount.toStringAsFixed(0)}'
                    '${order.discountReason.isNotEmpty ? " (${order.discountReason})" : ""}',
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 12),
                  ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cancel, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Text(
                        order.status == 'rejected'
                            ? 'Order rejected by restaurant.'
                            : 'Order was cancelled.',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                  if (order.paymentMethod == 'online' &&
                      order.paymentStatus == 'paid') ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Refund will be processed in 3–5 business days.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
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
                    fontWeight:
                        reached ? FontWeight.bold : FontWeight.normal,
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

// ─── Modified Order Popup ─────────────────────────────────────────────────────

class _ModifiedOrderDialog extends StatelessWidget {
  final Order order;
  const _ModifiedOrderDialog({required this.order});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = order.discountAmount > 0;
    final priceChanged = order.originalTotal != null &&
        order.originalTotal != order.totalAmount;

    return Dialog(
      backgroundColor: _panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.orangeAccent, size: 22),
                SizedBox(width: 8),
                Text('Order Updated',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'The restaurant has modified your order.\n'
              'Please review the changes below.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Items list
            const Text('Items',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  children: order.items
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity}× ${item.productName}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                Text(
                                  '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Totals box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  if (priceChanged) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Original Total',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text(
                          '₹${order.originalTotal!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (hasDiscount) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Discount${order.discountReason.isNotEmpty ? " (${order.discountReason})" : ""}',
                          style: const TextStyle(
                              color: Colors.greenAccent, fontSize: 12),
                        ),
                        Text(
                          '-₹${order.discountAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.greenAccent, fontSize: 12),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF2A2A2A), height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('New Total',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text(
                        '₹${order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: _brandRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Accept button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Accept & Continue',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
