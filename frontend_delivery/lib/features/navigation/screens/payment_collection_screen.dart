import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/api_config.dart';
import '../../../core/storage/token_storage.dart';
import '../../../features/orders/models/order.dart';
import '../../../features/orders/screens/home_router.dart';
import '../../../features/orders/services/order_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _kRed = Color(0xFFFF1E1E);
const _kSurface = Color(0xFF050505);
const _kPanel = Color(0xFF111111);
const _kStroke = Color(0xFF2A2A2A);
const _kMuted = Color(0xFFB8B8B8);

class PaymentCollectionScreen extends StatefulWidget {
  final Order order;

  const PaymentCollectionScreen({super.key, required this.order});

  @override
  State<PaymentCollectionScreen> createState() =>
      _PaymentCollectionScreenState();
}

class _PaymentCollectionScreenState
    extends State<PaymentCollectionScreen> {
  final OrderService _orderService = OrderService();
  bool _busy = false;
  String? _error;

  bool get _requiresCollection =>
      widget.order.paymentMethod == 'cod' &&
      widget.order.paymentStatus != 'paid';

  // ── Complete delivery ──────────────────────────────────────────────────────

  Future<void> _completeDelivery() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Step 1: Record final GPS location (best-effort)
      await _recordFinalLocation();

      // Step 2: Mark order as delivered (must succeed)
      await _orderService.updateStatus(widget.order.id, 'delivered');

      if (!mounted) return;

      // Step 3: Return to orders home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeRouter()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _recordFinalLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 8));

      final token = await TokenStorage.getAccessToken();
      if (token == null) return;

      await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}/orders/${widget.order.id}/delivery-location/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'latitude': pos.latitude,
              'longitude': pos.longitude,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Best-effort — silently skip if GPS or network unavailable
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirm();
      },
      child: Scaffold(
        backgroundColor: _kSurface,
        appBar: AppBar(
          backgroundColor: _kSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _showExitConfirm,
          ),
          title: const Text(
            'Complete Delivery',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _busy
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _kRed),
                    SizedBox(height: 16),
                    Text('Completing delivery…',
                        style: TextStyle(color: _kMuted)),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOrderCard(),
                  const SizedBox(height: 16),
                  _buildPaymentCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBanner(),
                  ],
                  const SizedBox(height: 24),
                  _buildActionButton(),
                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────────────────────

  Widget _buildOrderCard() {
    final o = widget.order;
    return _Card(
      children: [
        _Row(label: 'Order', value: '#${o.orderNumber}'),
        _Row(label: 'Customer', value: 'Customer #${o.customerId ?? "—"}'),
        _Row(
          label: 'Amount',
          value: '₹${o.totalAmount.toStringAsFixed(0)}',
          valueStyle: const TextStyle(
            color: _kRed,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        if (o.deliveryNotes.isNotEmpty)
          _Row(label: 'Notes', value: o.deliveryNotes),
        if (o.address != null) ...[
          const Divider(color: _kStroke, height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded,
                  color: _kRed, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (o.address!.lineOne.isNotEmpty)
                      Text(o.address!.lineOne,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    if (o.address!.lineTwo.isNotEmpty)
                      Text(o.address!.lineTwo,
                          style: const TextStyle(
                              color: _kMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentCard() {
    final isCod = widget.order.paymentMethod == 'cod';

    if (!_requiresCollection) {
      // Already paid (online) or COD already confirmed
      return _Card(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.greenAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: 16),
                    SizedBox(width: 6),
                    Text('Payment Received',
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isCod
                ? 'Cash payment already confirmed.'
                : 'Online payment was received before dispatch.',
            style: const TextStyle(color: _kMuted, fontSize: 13),
          ),
        ],
      );
    }

    // COD — needs cash collection
    return _Card(
      borderColor: Colors.orangeAccent.withValues(alpha: 0.5),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.payments_rounded,
                      color: Colors.orangeAccent, size: 16),
                  SizedBox(width: 6),
                  Text('Cash on Delivery',
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Collect from Customer:',
                style: TextStyle(color: _kMuted, fontSize: 14),
              ),
              Text(
                '₹${widget.order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _kRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? 'Something went wrong',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final label = _requiresCollection
        ? 'Confirm Payment Received'
        : 'Complete Delivery';

    final color =
        _requiresCollection ? Colors.orangeAccent : Colors.greenAccent;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black87,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _busy ? null : _completeDelivery,
        child: Text(
          label,
          style: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
    );
  }

  void _showExitConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Leave Delivery?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'The order will not be marked delivered. Are you sure?',
          style: TextStyle(color: _kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay',
                style: TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Leave',
                style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
  }
}

// ── Shared helper widgets ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final List<Widget> children;
  final Color? borderColor;

  const _Card({required this.children, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? _kStroke),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _Row({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style:
                    const TextStyle(color: _kMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
