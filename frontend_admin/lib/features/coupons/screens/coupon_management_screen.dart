import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/error_retry.dart';
import '../../orders/services/order_service.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class CouponManagementScreen extends StatefulWidget {
  const CouponManagementScreen({super.key});

  @override
  State<CouponManagementScreen> createState() => _CouponManagementScreenState();
}

class _CouponManagementScreenState extends State<CouponManagementScreen> {
  final OrderService _svc = OrderService();
  List<Map<String, dynamic>> _coupons = [];
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
      final coupons = await _svc.getCoupons();
      if (mounted) setState(() { _coupons = coupons; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggle(Map<String, dynamic> coupon) async {
    try {
      await _svc.toggleCoupon(coupon['id'] as int);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> coupon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete Coupon', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${coupon['code']}"?',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _svc.deleteCoupon(coupon['id'] as int);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final codeCtrl = TextEditingController();
    String discountType = 'flat';
    final valueCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '0');
    final maxCtrl = TextEditingController();
    final limitCtrl = TextEditingController();
    bool? result;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _card,
          title: Text('New Coupon',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Field(ctrl: codeCtrl, label: 'Code', hint: 'e.g. SAVE50',
                  caps: TextCapitalization.characters),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Type', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Flat ₹'),
                  selected: discountType == 'flat',
                  onSelected: (_) => setS(() => discountType = 'flat'),
                  selectedColor: _red.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                      color: discountType == 'flat' ? _red : Colors.grey),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('% Off'),
                  selected: discountType == 'percentage',
                  onSelected: (_) => setS(() => discountType = 'percentage'),
                  selectedColor: _red.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                      color: discountType == 'percentage' ? _red : Colors.grey),
                ),
              ]),
              const SizedBox(height: 12),
              _Field(ctrl: valueCtrl, label: 'Discount Value', hint: '100',
                  numeric: true),
              const SizedBox(height: 12),
              _Field(ctrl: minCtrl, label: 'Min Order ₹', hint: '0', numeric: true),
              if (discountType == 'percentage') ...[
                const SizedBox(height: 12),
                _Field(ctrl: maxCtrl, label: 'Max Discount ₹ (optional)',
                    hint: 'Leave blank for no cap', numeric: true),
              ],
              const SizedBox(height: 12),
              _Field(ctrl: limitCtrl, label: 'Usage Limit (optional)',
                  hint: 'Leave blank for unlimited', numeric: true),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _red),
              onPressed: () async {
                if (codeCtrl.text.trim().isEmpty || valueCtrl.text.trim().isEmpty) {
                  return;
                }
                final data = {
                  'code': codeCtrl.text.trim().toUpperCase(),
                  'discount_type': discountType,
                  'discount_value': valueCtrl.text.trim(),
                  'min_order_amount': minCtrl.text.trim().isEmpty
                      ? '0'
                      : minCtrl.text.trim(),
                  if (discountType == 'percentage' && maxCtrl.text.isNotEmpty)
                    'max_discount_amount': maxCtrl.text.trim(),
                  if (limitCtrl.text.isNotEmpty)
                    'usage_limit': int.tryParse(limitCtrl.text.trim()),
                };
                try {
                  await _svc.createCoupon(data);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                  result = true;
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    // Defer dispose by one frame so the dialog's closing animation can finish
    // before the controllers are invalidated (same fix as profile _editName).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      codeCtrl.dispose();
      valueCtrl.dispose();
      minCtrl.dispose();
      maxCtrl.dispose();
      limitCtrl.dispose();
    });
    if (result == true) _load();
  }

  String _fmtDate(String? s) {
    if (s == null) return '—';
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return DateFormat('d MMM y').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Coupons',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: _red), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: _red,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Coupon', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : _coupons.isEmpty
                  ? Center(
                      child: Text('No coupons yet',
                          style: GoogleFonts.poppins(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _red,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _coupons.length,
                        itemBuilder: (_, i) {
                          final c = _coupons[i];
                          final isActive = c['is_active'] as bool? ?? false;
                          final dtype = c['discount_type'] as String? ?? '';
                          final value = c['discount_value'];
                          final used = c['usage_count'] as int? ?? 0;
                          final limit = c['usage_limit'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: isActive
                                      ? Colors.greenAccent.withValues(alpha: 0.3)
                                      : _stroke),
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(c['code'] as String,
                                            style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (isActive
                                                    ? Colors.greenAccent
                                                    : Colors.grey)
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(isActive ? 'Active' : 'Off',
                                              style: TextStyle(
                                                  color: isActive
                                                      ? Colors.greenAccent
                                                      : Colors.grey,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(
                                        dtype == 'flat'
                                            ? '₹$value off'
                                            : '$value% off',
                                        style: const TextStyle(
                                            color: _red, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Min ₹${c['min_order_amount']} · Used: $used${limit != null ? '/$limit' : ''}',
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 11),
                                      ),
                                      if (c['valid_until'] != null)
                                        Text('Expires: ${_fmtDate(c['valid_until'] as String?)}',
                                            style: const TextStyle(
                                                color: Colors.grey, fontSize: 11)),
                                    ]),
                              ),
                              Column(children: [
                                Switch(
                                  value: isActive,
                                  activeThumbColor: Colors.greenAccent,
                                  onChanged: (_) => _toggle(c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 18),
                                  onPressed: () => _delete(c),
                                ),
                              ]),
                            ]),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool numeric;
  final TextCapitalization caps;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.numeric = false,
    this.caps = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      textCapitalization: caps,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _stroke)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _stroke)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _red)),
        filled: true,
        fillColor: _surface,
      ),
    );
  }
}
