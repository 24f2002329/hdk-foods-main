import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/error_retry.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../../delivery_staff/models/delivery_staff.dart';
import '../../delivery_staff/services/delivery_staff_service.dart';
import '../../products/models/product.dart';
import '../../products/services/product_service.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class AdminOrderDetailScreen extends StatefulWidget {
  final int orderId;
  const AdminOrderDetailScreen({super.key, required this.orderId});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  bool _busy = false;
  final OrderService _svc = OrderService();
  final DeliveryStaffService _deliverySvc = DeliveryStaffService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final o = await _svc.getOrder(widget.orderId);
      if (mounted) setState(() { _order = o; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirm() async {
    final prepTime = await _prepTimeDialog();
    if (prepTime == null) return;
    setState(() => _busy = true);
    try {
      final updated = await _svc.confirmOrder(_order!.id, prepTime);
      setState(() => _order = updated);
      _snack('Order confirmed!');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await _rejectDialog();
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final updated = await _svc.rejectOrder(_order!.id, reason);
      setState(() => _order = updated);
      _snack('Order rejected.');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editItems() async {
    if (_order == null) return;
    final updated = await showDialog<Order>(
      context: context,
      builder: (_) =>
          _EditItemsDialog(order: _order!, service: _svc),
    );
    if (updated != null) setState(() => _order = updated);
  }

  Future<void> _updateStatus(String s) async {
    setState(() => _busy = true);
    try {
      final updated = await _svc.updateStatus(_order!.id, s);
      setState(() => _order = updated);
      _snack('Status updated.');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markReadyWithAssign() async {
    List<DeliveryStaff> staff = [];
    try {
      staff = await _deliverySvc.getDeliveryStaff();
    } catch (_) {}

    if (!mounted) return;

    if (staff.isEmpty) {
      await _updateStatus('ready_for_pickup');
      return;
    }

    final defaultStaff = staff.firstWhere(
      (s) => s.isDefaultDelivery,
      orElse: () => staff.first,
    );

    final result = await showDialog<_ReadyResult>(
      context: context,
      builder: (_) =>
          _AssignAndReadyDialog(staff: staff, initial: defaultStaff),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      if (result.deliveryUserId != null) {
        await _svc.assignDelivery(_order!.id, result.deliveryUserId!);
      }
      final updated = await _svc.updateStatus(_order!.id, 'ready_for_pickup');
      setState(() => _order = updated);
      _snack('Marked ready for pickup.');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int?> _prepTimeDialog() {
    int prepTime = 20;
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Prep Time',
            style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (_, ss) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$prepTime min',
                  style: const TextStyle(
                      color: _red,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
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
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey))),
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
        title: const Text('Reject Order',
            style: TextStyle(color: Colors.white)),
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
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  String _label(String s) => s
      .split('_')
      .map((w) =>
          w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Color _statusColor(String s) {
    switch (s) {
      case 'delivered': return Colors.greenAccent;
      case 'rejected':
      case 'cancelled': return Colors.redAccent;
      case 'pending_confirmation': return Colors.orangeAccent;
      case 'confirmed': return Colors.blueAccent;
      case 'preparing': return Colors.amberAccent;
      case 'ready_for_pickup': return Colors.tealAccent;
      default: return _red;
    }
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13)),
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
            children: children),
      );

  Widget _btn(String label, Color color, VoidCallback onTap) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.black87,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _busy ? null : onTap,
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );

  List<Widget> _actions(String s) {
    final buttons = <Widget>[];
    if (s == 'pending_confirmation') {
      buttons.add(_btn('Edit Items & Discount', Colors.grey[700]!, _editItems));
      buttons.add(const SizedBox(height: 10));
      buttons.add(_btn('Confirm Order', _red, _confirm));
      buttons.add(const SizedBox(height: 10));
      buttons.add(_btn('Reject Order', Colors.redAccent, _reject));
    }
    if (s == 'confirmed') {
      buttons.add(_btn('Start Preparing', Colors.amberAccent,
          () => _updateStatus('preparing')));
    }
    if (s == 'preparing') {
      buttons.add(_btn('Mark Ready & Assign Delivery',
          Colors.tealAccent, _markReadyWithAssign));
    }
    if (s == 'ready_for_pickup') {
      buttons.add(_btn('Mark Out for Delivery', Colors.blueAccent,
          () => _updateStatus('out_for_delivery')));
    }
    if (s == 'out_for_delivery') {
      buttons.add(_btn('Mark Delivered', Colors.greenAccent,
          () => _updateStatus('delivered')));
    }
    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: CircularProgressIndicator(color: _red)),
      );
    }
    if (_order == null) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(backgroundColor: _surface),
        body: const Center(
            child: Text('Order not found',
                style: TextStyle(color: Colors.grey))),
      );
    }
    final o = _order!;
    final created = o.createdAt != null
        ? DateFormat('dd MMM, hh:mm a').format(o.createdAt!.toLocal())
        : '—';

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Order #${o.orderNumber}',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: _red, strokeWidth: 2)),
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
                  fontSize: 15),
            ),
          ),
          const SizedBox(height: 20),
          _card([
            _infoRow('Order #', o.orderNumber),
            _infoRow('Created', created),
            _infoRow('Total', '₹${o.totalAmount.toStringAsFixed(0)}'),
            _infoRow('Payment',
                '${o.paymentMethod.toUpperCase()} • ${o.paymentStatus.toUpperCase()}'),
            if (o.deliveryNotes.isNotEmpty)
              _infoRow('Delivery Notes', o.deliveryNotes),
            if (o.estimatedPreparationTime != null)
              _infoRow('Prep Time', '${o.estimatedPreparationTime} min'),
            if (o.rejectionReason.isNotEmpty)
              _infoRow('Rejection Reason', o.rejectionReason),
          ]),
          const SizedBox(height: 16),
          const Text('Items',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 8),
          _card(o.items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              '${item.quantity}× ${item.productName}',
                              style: const TextStyle(color: Colors.white)),
                        ),
                        Text(
                          '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ))
              .toList()),
          const SizedBox(height: 24),
          ..._actions(o.status),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Enhanced Edit Items Dialog ───────────────────────────────────────────────

class _EditItemsDialog extends StatefulWidget {
  final Order order;
  final OrderService service;
  const _EditItemsDialog({required this.order, required this.service});

  @override
  State<_EditItemsDialog> createState() => _EditItemsDialogState();
}

class _EditItemsDialogState extends State<_EditItemsDialog> {
  late List<Map<String, dynamic>> _items;
  final TextEditingController _discountCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.order.items
        .map((i) => {
              'product_id': i.productId,
              'quantity': i.quantity,
              'name': i.productName,
              'price': i.price,
            })
        .toList();
    if (widget.order.discountAmount > 0) {
      _discountCtrl.text =
          widget.order.discountAmount.toStringAsFixed(0);
      _reasonCtrl.text = widget.order.discountReason;
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(
      0,
      (sum, i) =>
          sum + (i['price'] as double) * (i['quantity'] as int));

  double get _discount {
    final v = double.tryParse(_discountCtrl.text) ?? 0;
    return v.clamp(0, _subtotal);
  }

  double get _newTotal =>
      (_subtotal - _discount).clamp(0, double.infinity);

  Future<void> _addItem() async {
    final Product? picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked == null) return;
    final existing =
        _items.indexWhere((i) => i['product_id'] == picked.id);
    if (existing >= 0) {
      setState(() => _items[existing]['quantity']++);
    } else {
      setState(() => _items.add({
            'product_id': picked.id,
            'quantity': 1,
            'name': picked.name,
            'price': picked.price,
          }));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = _items
          .where((i) => (i['quantity'] as int) > 0)
          .map((i) =>
              {'product_id': i['product_id'], 'quantity': i['quantity']})
          .toList();
      if (payload.isEmpty) throw Exception('At least one item is required.');

      Order updated =
          await widget.service.editItems(widget.order.id, payload);
      final d = _discount;
      if (d > 0) {
        updated = await widget.service.applyDiscount(
          widget.order.id,
          d,
          _reasonCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      title: const Text('Edit Order',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Items',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ..._items.map((item) {
                final qty = item['quantity'] as int;
                final idx = _items.indexOf(item);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(item['name'] as String,
                            style: TextStyle(
                                color: qty == 0
                                    ? Colors.grey
                                    : Colors.white,
                                decoration: qty == 0
                                    ? TextDecoration.lineThrough
                                    : null)),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.redAccent, size: 22),
                        onPressed: qty > 0
                            ? () => setState(
                                () => _items[idx]['quantity'] = qty - 1)
                            : null,
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('$qty',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.add_circle_outline,
                            color: _red, size: 22),
                        onPressed: () => setState(
                            () => _items[idx]['quantity'] = qty + 1),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, color: _red, size: 18),
                label: const Text('Add Item',
                    style: TextStyle(color: _red)),
              ),
              const Divider(color: _stroke, height: 20),
              const Text('Discount (optional)',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _discountCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '₹ Amount',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(color: Colors.white),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _reasonCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Reason (optional)',
                        hintStyle: TextStyle(color: Colors.grey),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: _stroke, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13)),
                  Text('₹${_subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13)),
                ],
              ),
              if (_discount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Discount',
                        style: TextStyle(
                            color: Colors.greenAccent, fontSize: 13)),
                    Text('-₹${_discount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.greenAccent, fontSize: 13)),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Total',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  Text('₹${_newTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: _red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _red),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─── Product Picker Sheet ─────────────────────────────────────────────────────

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final ProductService _svc = ProductService();
  final TextEditingController _search = TextEditingController();
  List<Product> _all = [];
  List<Product> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _svc.getProducts();
      setState(() { _all = list; _filtered = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _filter(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
              .where(
                  (p) => p.name.toLowerCase().contains(q.toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _panel,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Add Item',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                style: const TextStyle(color: Colors.white),
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'Search menu…',
                  hintStyle:
                      const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search,
                      color: Colors.grey),
                  filled: true,
                  fillColor: _surface,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: _red))
                  : _error != null
                      ? ErrorRetryWidget(error: _error!, onRetry: _load)
                      : _filtered.isEmpty
                          ? const Center(
                              child: Text('No items found',
                                  style: TextStyle(
                                      color: Colors.grey)))
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) {
                                final p = _filtered[i];
                                return ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          vertical: 6),
                                  leading: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    child: p.image.isNotEmpty
                                        ? Image.network(
                                            p.image,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (ctx2, e2, st2) =>
                                                    _placeholder(),
                                          )
                                        : _placeholder(),
                                  ),
                                  title: Text(p.name,
                                      style: const TextStyle(
                                          color: Colors.white)),
                                  subtitle: Text(
                                      '₹${p.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          color: Colors.grey)),
                                  trailing: IconButton(
                                    icon: const Icon(
                                        Icons.add_circle,
                                        color: _red,
                                        size: 28),
                                    onPressed: () =>
                                        Navigator.pop(ctx, p),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 48,
        height: 48,
        color: _surface,
        child: const Icon(Icons.fastfood,
            color: Colors.grey, size: 24),
      );
}

// ─── Assign + Ready Dialog ────────────────────────────────────────────────────

class _ReadyResult {
  final int? deliveryUserId;
  _ReadyResult({this.deliveryUserId});
}

class _AssignAndReadyDialog extends StatefulWidget {
  final List<DeliveryStaff> staff;
  final DeliveryStaff? initial;
  const _AssignAndReadyDialog({required this.staff, this.initial});

  @override
  State<_AssignAndReadyDialog> createState() => _AssignAndReadyDialogState();
}

class _AssignAndReadyDialogState extends State<_AssignAndReadyDialog> {
  DeliveryStaff? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ??
        (widget.staff.isNotEmpty ? widget.staff.first : null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      title: const Text('Assign Delivery Person',
          style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.staff.map((s) {
          final sel = _selected?.id == s.id;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Radio<int>(
              value: s.id,
              groupValue: _selected?.id,
              activeColor: _red,
              onChanged: (_) => setState(() => _selected = s),
            ),
            title: Text(s.displayName,
                style: const TextStyle(color: Colors.white)),
            subtitle: s.isDefaultDelivery
                ? const Text('Default',
                    style: TextStyle(color: _red, fontSize: 11))
                : null,
            tileColor:
                sel ? _red.withValues(alpha: 0.08) : null,
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, _ReadyResult(deliveryUserId: null)),
          child: const Text('Skip', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _red),
          onPressed: () => Navigator.pop(
              context, _ReadyResult(deliveryUserId: _selected?.id)),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
