import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/hdk_preloader.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../../delivery_staff/models/delivery_staff.dart';
import '../../delivery_staff/services/delivery_staff_service.dart';
import '../../products/models/product.dart';
import '../../products/services/product_service.dart';
import 'admin_order_chat_screen.dart';

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
      if (mounted) {
        setState(() {
          _order = o;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _canMarkDelivered(Order order) => order.paymentStatus == 'paid';

  bool _canEditPaymentMethod(Order order) =>
      order.paymentStatus != 'paid' &&
      !['delivered', 'cancelled', 'rejected'].contains(order.status);

  String _paymentBlockMessage(Order order) =>
      'Collect or confirm payment first (${order.paymentMethod.toUpperCase()} | ${order.paymentStatus.toUpperCase()}).';

  Future<void> _changePaymentMethod(String method) async {
    if (_order == null || _order!.paymentMethod == method) return;
    setState(() => _busy = true);
    try {
      final updated = await _svc.updatePaymentMethod(_order!.id, method);
      setState(() => _order = updated);
      _snack('Payment method changed to ${method.toUpperCase()}.');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markCodPaid() async {
    if (_order == null) return;
    setState(() => _busy = true);
    try {
      final updated = await _svc.markCodPaid(_order!.id);
      setState(() => _order = updated);
      _snack('COD payment marked as paid.');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      builder: (_) => _EditItemsDialog(order: _order!, service: _svc),
    );
    if (updated != null) setState(() => _order = updated);
  }

  Future<void> _overrideStatus() async {
    const allStatuses = [
      ('pending_confirmation', 'Pending Confirmation', Colors.orangeAccent),
      ('confirmed', 'Confirmed', Colors.blueAccent),
      ('preparing', 'Preparing', Colors.amberAccent),
      ('out_for_delivery', 'Out for Delivery', Colors.tealAccent),
      ('delivered', 'Delivered', Colors.greenAccent),
      ('cancelled', 'Cancelled', Colors.redAccent),
      ('rejected', 'Rejected', Colors.redAccent),
    ];

    final current = _order?.status ?? '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Override Order Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select any status — coins & flags are corrected automatically.',
              style: TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ...allStatuses.map((s) {
              final (key, label, color) = s;
              final isCurrent = key == current;
              return ListTile(
                leading: CircleAvatar(
                  radius: 10,
                  backgroundColor: isCurrent
                      ? color
                      : color.withValues(alpha: 0.3),
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    color: isCurrent ? color : Colors.white,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isCurrent
                    ? const Text(
                        'CURRENT',
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      )
                    : null,
                onTap: isCurrent ? null : () => Navigator.pop(ctx, key),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await _svc.overrideStatus(_order!.id, picked);
      setState(() => _order = updated);
      _snack('Status overridden to "${picked.replaceAll('_', ' ')}" ✅');
    } catch (e) {
      _snack('Override failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateStatus(String s) async {
    if (s == 'delivered' && _order != null && !_canMarkDelivered(_order!)) {
      _snack(_paymentBlockMessage(_order!));
      return;
    }
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

  Future<String?> _cancelReasonDialog({
    required String title,
    String actionLabel = 'Cancel Order',
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter reason for cancellation...',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _red),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(actionLabel, style: const TextStyle(color: _red)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancellation(String action) async {
    setState(() => _busy = true);
    try {
      final updated = await _svc.adminHandleCancellation(
        orderId: _order!.id,
        action: action,
        reason: '',
      );
      setState(() => _order = updated);
      _snack(
        action == 'approve'
            ? 'Cancellation approved.'
            : 'Cancellation request declined.',
      );
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _adminCancelDirectly() async {
    final reason = await _cancelReasonDialog(title: 'Cancel Order (Direct)');
    if (reason == null || reason.isEmpty) return;

    setState(() => _busy = true);
    try {
      final updated = await _svc.adminCancelOrder(
        orderId: _order!.id,
        reason: reason,
      );
      setState(() => _order = updated);
      _snack('Order cancelled.');
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
      await _updateStatus('out_for_delivery');
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
      final updated = await _svc.updateStatus(_order!.id, 'out_for_delivery');
      setState(() => _order = updated);
      _snack('Marked out for delivery.');
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
          width: 130,
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
          width: 130,
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
        if (phone.isNotEmpty) ...[
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('tel:$phone')),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  Icon(Icons.call_rounded, color: Colors.greenAccent, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Call',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminOrderChatScreen(
                  orderId: _order!.id,
                  orderNumber: _order!.orderNumber,
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _red.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: _red,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Chat',
                    style: TextStyle(
                      color: _red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

  Widget _paymentWarning(Order order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.amberAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _paymentBlockMessage(order),
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodEditor(Order order) {
    Widget chip(String method, String label, IconData icon) {
      final selected = order.paymentMethod == method;
      return Expanded(
        child: OutlinedButton.icon(
          onPressed: _busy || selected
              ? null
              : () => _changePaymentMethod(method),
          icon: Icon(icon, size: 16),
          label: Text(label, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            foregroundColor: selected ? Colors.white : _red,
            disabledForegroundColor: selected ? Colors.white : Colors.grey,
            backgroundColor: selected
                ? _red.withValues(alpha: 0.18)
                : Colors.transparent,
            side: BorderSide(color: selected ? _red : _stroke),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Change payment method',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              chip('cod', 'COD', Icons.payments_rounded),
              const SizedBox(width: 8),
              chip('online', 'Online', Icons.qr_code_rounded),
            ],
          ),
        ],
      ),
    );
  }

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
      buttons.add(
        _btn(
          'Start Preparing',
          Colors.amberAccent,
          () => _updateStatus('preparing'),
        ),
      );
    }
    if (s == 'preparing') {
      buttons.add(
        _btn(
          'Mark Ready & Assign Delivery',
          Colors.tealAccent,
          _markReadyWithAssign,
        ),
      );
    }
    if (s == 'out_for_delivery') {
      final order = _order!;
      if (!_canMarkDelivered(order)) {
        buttons.add(_paymentWarning(order));
        buttons.add(const SizedBox(height: 10));
        if (order.paymentMethod == 'cod') {
          buttons.add(
            _btn('Mark COD as Paid', Colors.amberAccent, _markCodPaid),
          );
          buttons.add(const SizedBox(height: 10));
        }
      }
      buttons.add(
        _btn(
          'Mark Delivered',
          Colors.greenAccent,
          _canMarkDelivered(order)
              ? () => _updateStatus('delivered')
              : () => _snack(_paymentBlockMessage(order)),
        ),
      );
    }

    // Direct cancellation after confirmation
    if (s != 'pending_confirmation' &&
        s != 'delivered' &&
        s != 'cancelled' &&
        s != 'rejected') {
      buttons.add(const SizedBox(height: 10));
      buttons.add(_btn('Cancel Order', Colors.redAccent, _adminCancelDirectly));
    }
    // Override Status — always visible for non-terminal statuses, but also for delivered
    if (!['cancelled', 'rejected'].contains(s)) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 10));
      buttons.add(
        _btn('⚙️  Override Status', const Color(0xFF2A2A2A), _overrideStatus),
      );
    }
    return buttons;
  }

  Future<void> _exportInvoicePdf(Order order) async {
    final pdf = pw.Document();

    // Load a font that supports the ₹ (rupee) symbol
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final dateStr = order.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt!.toLocal())
        : 'N/A';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'HDK FOODS',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#FF1E1E'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Deliciously Yours',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 10,
                          color: PdfColors.grey,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Order #${order.orderNumber}',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      pw.Text(
                        'Date: $dateStr',
                        style: pw.TextStyle(font: fontRegular, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 16),

              // Billing Details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CUSTOMER DETAILS',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          order.customerName.isNotEmpty
                              ? order.customerName
                              : 'Walk-in Customer',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Phone: ${order.customerPhone.isNotEmpty ? order.customerPhone : 'N/A'}',
                          style: pw.TextStyle(font: fontRegular),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DELIVERY ADDRESS',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        if (order.address != null) ...[
                          pw.Text(
                            order.address!.lineOne,
                            style: pw.TextStyle(font: fontRegular),
                          ),
                          if (order.address!.lineTwo.isNotEmpty)
                            pw.Text(
                              order.address!.lineTwo,
                              style: pw.TextStyle(font: fontRegular),
                            ),
                        ] else ...[
                          pw.Text(
                            'Takeaway / Dine-in',
                            style: pw.TextStyle(font: fontRegular),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Items Table Header
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'Item Description',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Container(
                      width: 60,
                      child: pw.Text(
                        'Price',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Container(
                      width: 40,
                      child: pw.Text(
                        'Qty',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Container(
                      width: 70,
                      child: pw.Text(
                        'Total',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Items List
              pw.ListView.builder(
                itemCount: order.items.length,
                itemBuilder: (pw.Context context, int index) {
                  final item = order.items[index];
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColors.grey200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            item.productName,
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Container(
                          width: 60,
                          child: pw.Text(
                            '\u20B9${item.price.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Container(
                          width: 40,
                          child: pw.Text(
                            '${item.quantity}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Container(
                          width: 70,
                          child: pw.Text(
                            '\u20B9${(item.price * item.quantity).toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              pw.SizedBox(height: 16),

              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.SizedBox(),
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Subtotal:',
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 10,
                              ),
                            ),
                            pw.Text(
                              '\u20B9${order.items.fold<double>(0, (sum, item) => sum + (item.price * item.quantity)).toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        if (order.discountAmount > 0) ...[
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Discount (${order.discountReason}):',
                                style: pw.TextStyle(
                                  font: fontRegular,
                                  fontSize: 10,
                                  color: PdfColors.green,
                                ),
                              ),
                              pw.Text(
                                '-\u20B9${order.discountAmount.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  font: fontRegular,
                                  fontSize: 10,
                                  color: PdfColors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (order.coinsRedeemed > 0) ...[
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Coins Redeemed:',
                                style: pw.TextStyle(
                                  font: fontRegular,
                                  fontSize: 10,
                                  color: PdfColor.fromHex('#FF8A00'),
                                ),
                              ),
                              pw.Text(
                                '-\u20B9${order.coinsRedeemed.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  font: fontRegular,
                                  fontSize: 10,
                                  color: PdfColor.fromHex('#FF8A00'),
                                ),
                              ),
                            ],
                          ),
                        ],
                        pw.Divider(thickness: 1, color: PdfColors.grey400),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Grand Total:',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            pw.Text(
                              '\u20B9${order.totalAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for ordering from HDK Foods!',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      'hdkfoods.in | Support: contact@hdkfoods.in',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'invoice_${order.orderNumber}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: HdkPreloader()),
      );
    }
    if (_order == null) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(backgroundColor: _surface),
        body: const Center(
          child: Text('Order not found', style: TextStyle(color: Colors.grey)),
        ),
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
        title: Text(
          'Order #${o.orderNumber}',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: 'Export Invoice',
            onPressed: () => _exportInvoicePdf(o),
          ),
          IconButton(
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
            ),
            tooltip: 'Chat with Customer',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminOrderChatScreen(
                  orderId: o.id,
                  orderNumber: o.orderNumber,
                ),
              ),
            ),
          ),
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
          // Cancellation Request Notification Card
          if (o.cancellationRequested &&
              o.status != 'cancelled' &&
              o.status != 'rejected') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C1E03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amberAccent,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Cancellation Requested by Customer',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reason: "${o.cancellationReason}"',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busy
                              ? null
                              : () => _handleCancellation('approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Approve & Cancel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _handleCancellation('reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amberAccent,
                            side: const BorderSide(color: Colors.amberAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Decline Request',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

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
            _infoRow('Total', '₹${o.totalAmount.toStringAsFixed(0)}'),
            _infoRow(
              'Payment',
              '${o.paymentMethod.toUpperCase()} • ${o.paymentStatus.toUpperCase()}',
            ),
            if (_canEditPaymentMethod(o) && o.paymentMethod == 'online')
              _paymentMethodEditor(o),
            if (o.deliveryNotes.isNotEmpty)
              _infoRow('Delivery Notes', o.deliveryNotes),
            if (o.estimatedPreparationTime != null)
              _infoRow('Prep Time', '${o.estimatedPreparationTime} min'),
            if (o.rejectionReason.isNotEmpty)
              _infoRow('Rejection Reason', o.rejectionReason),
          ]),
          const SizedBox(height: 16),
          const Text(
            'Items',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _card(
            o.items
                .map(
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
                )
                .toList(),
          ),
          const SizedBox(height: 24),

          // ── Not Received Alert ─────────────────────────────────────────
          if (o.notReceivedReported) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0505),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.report_problem_rounded,
                    color: Colors.redAccent,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️  Customer Didn\'t Receive This Order',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Customer reported non-receipt. Use Override Status to correct it.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

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
        .map(
          (i) => {
            'product_id': i.productId,
            'quantity': i.quantity,
            'name': i.productName,
            'price': i.price,
          },
        )
        .toList();
    if (widget.order.discountAmount > 0) {
      _discountCtrl.text = widget.order.discountAmount.toStringAsFixed(0);
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
    (sum, i) => sum + (i['price'] as double) * (i['quantity'] as int),
  );

  double get _discount {
    final v = double.tryParse(_discountCtrl.text) ?? 0;
    return v.clamp(0, _subtotal);
  }

  double get _newTotal => (_subtotal - _discount).clamp(0, double.infinity);

  Future<void> _addItem() async {
    final Product? picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked == null) return;
    final existing = _items.indexWhere((i) => i['product_id'] == picked.id);
    if (existing >= 0) {
      setState(() => _items[existing]['quantity']++);
    } else {
      setState(
        () => _items.add({
          'product_id': picked.id,
          'quantity': 1,
          'name': picked.name,
          'price': picked.price,
        }),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = _items
          .where((i) => (i['quantity'] as int) > 0)
          .map(
            (i) => {'product_id': i['product_id'], 'quantity': i['quantity']},
          )
          .toList();
      if (payload.isEmpty) throw Exception('At least one item is required.');

      Order updated = await widget.service.editItems(widget.order.id, payload);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
      title: const Text(
        'Edit Order',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Items',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ..._items.map((item) {
                final qty = item['quantity'] as int;
                final idx = _items.indexOf(item);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] as String,
                          style: TextStyle(
                            color: qty == 0 ? Colors.grey : Colors.white,
                            decoration: qty == 0
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                        onPressed: qty > 0
                            ? () => setState(
                                () => _items[idx]['quantity'] = qty - 1,
                              )
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: _red,
                          size: 22,
                        ),
                        onPressed: () =>
                            setState(() => _items[idx]['quantity'] = qty + 1),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, color: _red, size: 18),
                label: const Text('Add Item', style: TextStyle(color: _red)),
              ),
              const Divider(color: _stroke, height: 20),
              const Text(
                'Discount (optional)',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _discountCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '₹ Amount',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(color: Colors.white),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
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
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: _stroke, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  Text(
                    '₹${_subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              if (_discount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Discount',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 13),
                    ),
                    Text(
                      '-₹${_discount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New Total',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '₹${_newTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: _red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
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
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _red),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
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
      setState(() {
        _all = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filter(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
                .where((p) => p.name.toLowerCase().contains(q.toLowerCase()))
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Add Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: _surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _red))
                  : _error != null
                  ? ErrorRetryWidget(error: _error!, onRetry: _load)
                  : _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No items found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: p.image.isNotEmpty
                                ? Image.network(
                                    p.image,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx2, e2, st2) =>
                                        _placeholder(),
                                  )
                                : _placeholder(),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '₹${p.price.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: _red,
                              size: 28,
                            ),
                            onPressed: () => Navigator.pop(ctx, p),
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
    child: const Icon(Icons.fastfood, color: Colors.grey, size: 24),
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
    _selected =
        widget.initial ?? (widget.staff.isNotEmpty ? widget.staff.first : null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      title: const Text(
        'Assign Delivery Person',
        style: TextStyle(color: Colors.white),
      ),
      content: RadioGroup<int>(
        groupValue: _selected?.id,
        onChanged: (value) {
          if (value == null) return;
          final selected = widget.staff.firstWhere((s) => s.id == value);
          setState(() => _selected = selected);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.staff.map((s) {
            final sel = _selected?.id == s.id;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Radio<int>(value: s.id, activeColor: _red),
              title: Text(
                s.displayName,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: s.isDefaultDelivery
                  ? const Text(
                      'Default',
                      style: TextStyle(color: _red, fontSize: 11),
                    )
                  : null,
              tileColor: sel ? _red.withValues(alpha: 0.08) : null,
              onTap: () => setState(() => _selected = s),
            );
          }).toList(),
        ),
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
            context,
            _ReadyResult(deliveryUserId: _selected?.id),
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
