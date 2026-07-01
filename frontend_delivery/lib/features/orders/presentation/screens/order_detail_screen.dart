import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../../../core/services/location_tracking_service.dart';
import '../../../navigation/presentation/screens/delivery_navigation_screen.dart';
import '../../../navigation/presentation/screens/payment_collection_screen.dart';
import '../../data/repositories/order_service.dart';
import '../../../delivery_staff/data/models/delivery_staff.dart';
import '../../../delivery_staff/data/repositories/delivery_staff_service.dart';
import '../widgets/edit_items_dialog.dart';
import '../widgets/assign_ready_dialog.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  final String role;

  const OrderDetailScreen({super.key, required this.order, required this.role});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;
  final OrderService _orderService = OrderService();
  final DeliveryStaffService _deliveryService = DeliveryStaffService();
  bool _busy = false;
  LocationTrackingService? _locationTracker;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _startTrackingIfNeeded();
  }

  void _startTrackingIfNeeded() {
    if (widget.role == 'delivery' && _order.status == 'out_for_delivery') {
      _locationTracker = LocationTrackingService(orderId: _order.id);
      _locationTracker!.start();
    }
  }

  @override
  void dispose() {
    _locationTracker?.stop();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Confirm ──────────────────────────────────────────────────────────────
  Future<void> _confirm() async {
    final prepTime = await _prepTimeDialog();
    if (prepTime == null) return;
    setState(() => _busy = true);
    try {
      final updated = await _orderService.confirmOrder(_order.id, prepTime);
      setState(() => _order = updated);
      _snack('Order confirmed!');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Reject ───────────────────────────────────────────────────────────────
  Future<void> _reject() async {
    final reason = await _rejectDialog();
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final updated = await _orderService.rejectOrder(_order.id, reason);
      setState(() => _order = updated);
      _snack('Order rejected.');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Edit items (opens full dialog) ───────────────────────────────────────
  Future<void> _editItems() async {
    final updated = await showDialog<Order>(
      context: context,
      builder: (_) => EditItemsDialog(order: _order, service: _orderService),
    );
    if (updated != null) setState(() => _order = updated);
  }

  // ── Update status ────────────────────────────────────────────────────────
  bool _canMarkDelivered(Order order) => order.paymentStatus == 'paid';

  String _paymentBlockMessage(Order order) =>
      'Collect or confirm payment first (${order.paymentMethod.toUpperCase()} | ${order.paymentStatus.toUpperCase()}).';

  Future<void> _updateStatus(String s) async {
    if (s == 'delivered' && !_canMarkDelivered(_order)) {
      _snack(_paymentBlockMessage(_order));
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await _orderService.updateStatus(_order.id, s);
      setState(() => _order = updated);
      if (s == 'out_for_delivery' && widget.role == 'delivery') {
        _locationTracker?.stop();
        _locationTracker = LocationTrackingService(orderId: _order.id);
        _locationTracker!.start();
      } else if (s == 'delivered') {
        _locationTracker?.stop();
      }
      _snack('Status updated.');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Mark ready + assign delivery ─────────────────────────────────────────
  Future<void> _markReadyWithAssign() async {
    List<DeliveryStaff> staff = [];
    try {
      staff = await _deliveryService.getDeliveryStaff();
    } catch (_) {}
    if (!mounted) return;

    if (staff.isEmpty) {
      await _updateStatus('out_for_delivery');
      return;
    }

    final defaultStaff = staff.firstWhere(
      (s) => s.isDefaultDelivery,
      orElse: () => staff.first,
    );

    final result = await showDialog<ReadyResult>(
      context: context,
      builder: (_) =>
          AssignAndReadyDialog(staff: staff, initial: defaultStaff),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      if (result.deliveryUserId != null) {
        await _orderService.assignDelivery(_order.id, result.deliveryUserId!);
      }
      final updated = await _orderService.updateStatus(
        _order.id,
        'out_for_delivery',
      );
      setState(() => _order = updated);
      _snack('Marked out for delivery.');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────
  Future<int?> _prepTimeDialog() {
    int prepTime = 20;
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Prep Time', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (_, ss) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$prepTime min',
                style: const TextStyle(
                  color: _red,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                min: 5,
                max: 90,
                divisions: 17,
                value: prepTime.toDouble(),
                activeColor: _red,
                onChanged: (v) => ss(() => prepTime = v.toInt()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, prepTime),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<String?> _rejectDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Reject Order',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason…',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _label(String s) => s
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Color _statusColor(String s) {
    switch (s) {
      case 'delivered':
        return Colors.greenAccent;
      case 'rejected':
      case 'cancelled':
        return Colors.redAccent;
      case 'pending_confirmation':
        return Colors.orangeAccent;
      case 'confirmed':
        return Colors.blueAccent;
      case 'preparing':
        return Colors.amberAccent;
      default:
        return _red;
    }
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _customerRow(String name, String phone) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 120,
          child: Text(
            'Customer',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        if (phone.isNotEmpty)
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('tel:$phone')),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call_rounded, color: Colors.greenAccent, size: 13),
                  SizedBox(width: 3),
                  Text(
                    'Call',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _stroke),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _btn(String label, Color color, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black87,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _busy ? null : onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );

  List<Widget> _actionButtons() {
    final s = _order.status;
    final isAdmin = widget.role == 'admin';
    final buttons = <Widget>[];

    if (s == 'pending_confirmation' && isAdmin) {
      buttons.add(_btn('Edit Items & Discount', Colors.grey, _editItems));
      buttons.add(const SizedBox(height: 10));
      buttons.add(_btn('Confirm Order', _red, _confirm));
      buttons.add(const SizedBox(height: 10));
      buttons.add(_btn('Reject Order', Colors.redAccent, _reject));
    }
    if (s == 'confirmed' && isAdmin) {
      buttons.add(
        _btn(
          'Start Preparing',
          Colors.amberAccent,
          () => _updateStatus('preparing'),
        ),
      );
    }
    if (s == 'preparing' && isAdmin) {
      buttons.add(
        _btn(
          'Mark Ready & Assign Delivery',
          Colors.tealAccent,
          _markReadyWithAssign,
        ),
      );
    }
    if (s == 'out_for_delivery' && widget.role == 'delivery') {
      buttons.add(
        _btn(
          'Mark Delivered',
          Colors.greenAccent,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentCollectionScreen(order: _order),
            ),
          ),
        ),
      );
    }
    return buttons;
  }

  Future<void> _openNavigation(double lat, double lng) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryNavigationScreen(order: _order),
      ),
    );
  }

  Widget _buildDeliveryMap() {
    final addr = _order.address;
    if (addr == null) return const SizedBox.shrink();

    final hasCoords = addr.latitude != null && addr.longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Address',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addr.label.isNotEmpty ? addr.label : 'Address',
                      style: const TextStyle(
                        color: _red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (addr.lineOne.isNotEmpty)
                      Text(
                        addr.lineOne,
                        style: const TextStyle(color: Colors.white),
                      ),
                    if (addr.lineTwo.isNotEmpty)
                      Text(
                        addr.lineTwo,
                        style: const TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
              if (hasCoords) ...[
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  child: SizedBox(
                    height: 200,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(addr.latitude!, addr.longitude!),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('delivery'),
                          position: LatLng(addr.latitude!, addr.longitude!),
                        ),
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasCoords
                              ? Colors.blueAccent
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate'),
                        onPressed: hasCoords
                            ? () => _openNavigation(
                                addr.latitude!,
                                addr.longitude!,
                              )
                            : null,
                      ),
                    ),
                    if (_order.status == 'out_for_delivery' &&
                        widget.role == 'delivery') ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Complete Delivery'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PaymentCollectionScreen(order: _order),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final o = _order;
    final created = o.createdAt != null
        ? DateFormat('dd MMM, hh:mm a').format(o.createdAt!.toLocal())
        : '—';

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text(
          'Order #${o.orderNumber}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: _red, strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(o.status).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _label(o.status),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _statusColor(o.status),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _card([
            _infoRow('Order #', o.orderNumber),
            _infoRow('Created', created),
            if (o.customerName.isNotEmpty)
              _customerRow(o.customerName, o.customerPhone),
            _infoRow(
              'Payment',
              '${o.paymentMethod.toUpperCase()} • ${o.paymentStatus.toUpperCase()}',
            ),
            if (o.estimatedPreparationTime != null)
              _infoRow('Prep Time', '${o.estimatedPreparationTime} min'),
            if (o.deliveryNotes.isNotEmpty) _infoRow('Notes', o.deliveryNotes),
          ]),
          const SizedBox(height: 16),

          // Items + totals
          const Text(
            'Items',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _card([
            ...o.items.map(
              (item) => Padding(
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
              ),
            ),
            const Divider(color: _stroke, height: 16),
            if (o.originalTotal != null &&
                o.originalTotal != o.totalAmount) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  Text(
                    '₹${o.originalTotal!.toStringAsFixed(0)}',
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
            if (o.discountAmount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Discount${o.discountReason.isNotEmpty ? " (${o.discountReason})" : ""}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '-₹${o.discountAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '₹${o.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: _red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 16),
          _buildDeliveryMap(),
          ..._actionButtons(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
