import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/error_retry.dart';
import '../../orders/models/order.dart';
import '../../orders/screens/admin_order_detail_screen.dart';
import '../services/customer_service.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

// ── Customer List ─────────────────────────────────────────────────────────────

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState
    extends State<CustomerManagementScreen> {
  final CustomerService _svc = CustomerService();
  final TextEditingController _search = TextEditingController();
  final _scrollController = ScrollController();

  final List<Customer> _all = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  String _lastSearch = '';

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _load();
    }
  }

  Timer? _debounce;
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _reset();
    });
  }

  void _reset() {
    setState(() { _all.clear(); _page = 1; _hasMore = true; _error = null; });
    _load();
  }

  List<Customer> get _filtered => _all;

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    final q = _search.text.trim();
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _svc.getCustomersPaged(page: _page, search: q.isEmpty ? null : q);
      final results = (data['results'] as List)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _all.addAll(results);
        _page++;
        _hasMore = data['next'] != null;
        _loading = false;
        _lastSearch = q;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _refresh() async {
    _reset();
  }

  Future<void> _toggle(Customer c) async {
    try {
      final updated = await _svc.toggleStatus(c.id);
      if (mounted) {
        setState(() {
          final idx = _all.indexWhere((x) => x.id == c.id);
          if (idx >= 0) _all[idx] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(Customer c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete Account',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Permanently delete "${c.displayName}"? '
          'All their orders will also be deleted.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _svc.deleteCustomer(c.id);
      if (mounted) setState(() => _all.removeWhere((x) => x.id == c.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text('Customers',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: _red),
              onPressed: _refresh),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or phone…',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => _search.clear(),
                      )
                    : null,
                filled: true,
                fillColor: _card,
                contentPadding: EdgeInsets.zero,
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
              ),
            ),
          ),
        ),
      ),
      body: _loading && _all.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null && _all.isEmpty
              ? ErrorRetryWidget(error: _error!, onRetry: _refresh)
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline,
                              color: Colors.grey, size: 56),
                          const SizedBox(height: 12),
                          Text(
                            _search.text.isEmpty
                                ? 'No customers yet'
                                : 'No results',
                            style: GoogleFonts.poppins(
                                color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      color: _red,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length + (_hasMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == filtered.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator(color: _red)),
                            );
                          }
                          return _CustomerCard(
                            customer: filtered[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerDetailScreen(
                                    customerId: filtered[i].id),
                              ),
                            ).then((_) => _refresh()),
                            onToggle: () => _toggle(filtered[i]),
                            onDelete: () => _delete(filtered[i]),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ── Customer card ─────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Card(
      color: _card,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    c.isActive ? _red : Colors.grey[700],
                child: Text(c.initials,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(c.displayName,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      if (!c.isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.4)),
                          ),
                          child: const Text('BLOCKED',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(c.phone,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${c.orderCount} orders',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                      if (c.createdAt != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM yyyy').format(c.createdAt!),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                color: const Color(0xFF1A1A1A),
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (v) {
                  if (v == 'call') {
                    launchUrl(Uri.parse('tel:${c.phone}'));
                  } else if (v == 'toggle') {
                    onToggle();
                  } else if (v == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => [
                  if (c.phone.isNotEmpty)
                    const PopupMenuItem(
                      value: 'call',
                      child: Row(children: [
                        Icon(Icons.call_rounded,
                            color: Colors.greenAccent, size: 18),
                        SizedBox(width: 10),
                        Text('Call', style: TextStyle(color: Colors.white)),
                      ]),
                    ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(
                        c.isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_outline,
                        color:
                            c.isActive ? Colors.orangeAccent : Colors.greenAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        c.isActive ? 'Block' : 'Unblock',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 18),
                      SizedBox(width: 10),
                      Text('Delete',
                          style: TextStyle(color: Colors.redAccent)),
                    ]),
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

// ── Customer Detail ───────────────────────────────────────────────────────────

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final CustomerService _svc = CustomerService();
  CustomerDetail? _detail;
  bool _loading = true;
  bool _toggling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await _svc.getCustomerDetail(widget.customerId);
      if (mounted) setState(() { _detail = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggle() async {
    setState(() => _toggling = true);
    try {
      final updated = await _svc.toggleStatus(widget.customerId);
      if (mounted) {
        setState(() {
          _detail = CustomerDetail(
            customer: updated,
            recentOrders: _detail?.recentOrders ?? [],
          );
          _toggling = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _toggling = false);
      }
    }
  }

  Future<void> _delete() async {
    final c = _detail?.customer;
    if (c == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete Account',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Permanently delete "${c.displayName}"? All their orders will also be deleted.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _svc.deleteCustomer(widget.customerId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: Text(_detail?.customer.displayName ?? 'Customer',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: _red),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? ErrorRetryWidget(error: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _detail!;
    final c = d.customer;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Customer info card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _stroke),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: c.isActive ? _red : Colors.grey[700],
                    child: Text(c.initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.displayName,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        Text(c.phone,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        if (c.createdAt != null)
                          Text(
                            'Joined ${DateFormat('MMM d, yyyy').format(c.createdAt!)}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  if (!c.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: const Text('BLOCKED',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                children: [
                  _stat('${c.orderCount}', 'Orders',
                      Icons.receipt_long_outlined, Colors.blueAccent),
                  const SizedBox(width: 12),
                  if (c.phone.isNotEmpty)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => launchUrl(Uri.parse('tel:${c.phone}')),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    Colors.greenAccent.withValues(alpha: 0.3)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.call_rounded,
                                  color: Colors.greenAccent, size: 20),
                              SizedBox(height: 4),
                              Text('Call',
                                  style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Block/Unblock button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _toggling ? null : _toggle,
                  icon: _toggling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.orangeAccent))
                      : Icon(
                          c.isActive
                              ? Icons.block_rounded
                              : Icons.check_circle_outline,
                          size: 16,
                        ),
                  label: Text(c.isActive ? 'Block Customer' : 'Unblock Customer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        c.isActive ? Colors.orangeAccent : Colors.greenAccent,
                    side: BorderSide(
                        color: c.isActive
                            ? Colors.orangeAccent
                            : Colors.greenAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Recent orders ───────────────────────────────────────────────────
        Text('Recent Orders (${d.recentOrders.length})',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        const SizedBox(height: 8),

        if (d.recentOrders.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No orders yet',
                  style: GoogleFonts.poppins(color: Colors.grey)),
            ),
          )
        else
          ...d.recentOrders.map((o) => _OrderRow(
                order: o,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminOrderDetailScreen(orderId: o.id),
                  ),
                ),
              )),

        const SizedBox(height: 24),

        // ── Delete button ───────────────────────────────────────────────────
        OutlinedButton.icon(
          onPressed: _delete,
          icon: const Icon(Icons.delete_forever_outlined,
              color: Colors.redAccent),
          label: const Text('Delete Account',
              style: TextStyle(color: Colors.redAccent)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.redAccent),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _stat(String value, String label, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text(label,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
      );
}

// ── Compact order row ─────────────────────────────────────────────────────────

class _OrderRow extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderRow({required this.order, required this.onTap});

  Color _statusColor(String s) {
    switch (s) {
      case 'pending_confirmation': return Colors.orange;
      case 'confirmed':
      case 'preparing': return Colors.blue;
      case 'ready_for_pickup': return Colors.purple;
      case 'out_for_delivery': return Colors.indigo;
      case 'delivered': return Colors.green;
      default: return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _card,
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${order.orderNumber}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    if (order.createdAt != null)
                      Text(
                        DateFormat('MMM d, h:mm a')
                            .format(order.createdAt!.toLocal()),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Text('₹${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: _red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(order.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _statusColor(order.status).withValues(alpha: 0.4)),
                ),
                child: Text(
                  order.status.replaceAll('_', ' '),
                  style: TextStyle(
                      color: _statusColor(order.status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
