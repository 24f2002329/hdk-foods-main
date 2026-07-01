import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/order_websocket_service.dart';
import 'package:hdk_core/hdk_core.dart';
import '../../../delivery_staff/data/models/delivery_staff.dart';
import '../../../delivery_staff/data/repositories/delivery_staff_service.dart';
import '../../data/repositories/order_service.dart';
import 'admin_order_detail_screen.dart';

const _red = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _card = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key});

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final OrderService _orderSvc = OrderService();
  final DeliveryStaffService _deliverySvc = DeliveryStaffService();

  List<Order> _orders = [];
  bool _loading = true;
  String? _error;

  Timer? _pollTimer;
  AdminOrderWebSocketService? _ws;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Fallback polling every 20 seconds
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadData(silent: true),
    );

    // Connect real-time WebSockets
    _ws = AdminOrderWebSocketService();
    _ws!.connect();
    _ws!.stream.listen((msg) {
      if (msg['type'] == 'new_order') {
        // Trigger system beep sound for new orders
        SystemSound.play(SystemSoundType.click);
        _loadData(silent: true);
        _showNewOrderNotification(msg['order_number'] ?? 'New');
      } else if (msg['type'] == 'order_update') {
        _loadData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ws?.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final all = await _orderSvc.getAllOrders();
      if (mounted) {
        setState(() {
          // Filter to only active KDS statuses
          _orders = all
              .where(
                (o) => [
                  'pending_confirmation',
                  'confirmed',
                  'preparing',
                  'out_for_delivery',
                ].contains(o.status),
              )
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _showNewOrderNotification(String orderNum) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.amberAccent),
            const SizedBox(width: 8),
            Text(
              'NEW ORDER RECEIVED: #$orderNum',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // --- Order State Transitions ---

  Future<void> _confirmOrder(Order order) async {
    final prepTime = await showDialog<int>(
      context: context,
      builder: (ctx) => _PrepTimeDialog(),
    );
    if (prepTime == null) return;

    setState(() => _isBusy = true);
    try {
      await _orderSvc.confirmOrder(order.id, prepTime);
      _loadData(silent: true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _rejectOrder(Order order) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          'Reject Order',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter rejection reason...',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      await _orderSvc.rejectOrder(order.id, reason);
      _loadData(silent: true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _startPreparing(Order order) async {
    setState(() => _isBusy = true);
    try {
      await _orderSvc.updateStatus(order.id, 'preparing');
      _loadData(silent: true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _markReadyAndAssign(Order order) async {
    List<DeliveryStaff> staff = [];
    try {
      staff = await _deliverySvc.getDeliveryStaff();
    } catch (_) {}

    if (!mounted) return;

    if (staff.isEmpty) {
      // If no delivery staff configured, just update status directly
      setState(() => _isBusy = true);
      try {
        await _orderSvc.updateStatus(order.id, 'out_for_delivery');
        _loadData(silent: true);
      } catch (e) {
        _showError(e.toString());
      } finally {
        if (mounted) setState(() => _isBusy = false);
      }
      return;
    }

    final defaultStaff = staff.firstWhere(
      (s) => s.isDefaultDelivery,
      orElse: () => staff.first,
    );

    final selectedStaff = await showDialog<DeliveryStaff>(
      context: context,
      builder: (ctx) =>
          _AssignDriverDialog(staffList: staff, initial: defaultStaff),
    );

    if (selectedStaff == null) return;

    setState(() => _isBusy = true);
    try {
      await _orderSvc.assignDelivery(order.id, selectedStaff.id);
      await _orderSvc.updateStatus(order.id, 'out_for_delivery');
      _loadData(silent: true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _markDelivered(Order order) async {
    setState(() => _isBusy = true);
    try {
      await _orderSvc.updateStatus(order.id, 'delivered');
      _loadData(silent: true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $msg'), backgroundColor: _red),
    );
  }

  // --- Layout Helper ---

  List<Order> _getPendingOrders() =>
      _orders.where((o) => o.status == 'pending_confirmation').toList();

  List<Order> _getPreparingOrders() => _orders
      .where((o) => o.status == 'confirmed' || o.status == 'preparing')
      .toList();

  List<Order> _getReadyOrders() =>
      _orders.where((o) => o.status == 'out_for_delivery').toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: HdkPreloader()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _surface,
        body: ErrorRetryWidget(error: _error!, onRetry: () => _loadData()),
      );
    }

    final pending = _getPendingOrders();
    final preparing = _getPreparingOrders();
    final ready = _getReadyOrders();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.soup_kitchen_outlined, color: _red, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Kitchen Display System (KDS)',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            if (_isBusy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: _red, strokeWidth: 2),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: () => _loadData(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            // Landscape View - 3 Columns side-by-side
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _KdsColumn(
                      title: 'Pending Orders',
                      accentColor: Colors.orangeAccent,
                      orders: pending,
                      childBuilder: (o) => _KdsOrderCard(
                        order: o,
                        accentColor: Colors.orangeAccent,
                        actions: [
                          _KdsCardAction(
                            label: 'Reject',
                            color: Colors.redAccent,
                            onPressed: () => _rejectOrder(o),
                          ),
                          _KdsCardAction(
                            label: 'Confirm',
                            color: _red,
                            onPressed: () => _confirmOrder(o),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _KdsColumn(
                      title: 'In Preparation',
                      accentColor: Colors.amberAccent,
                      orders: preparing,
                      childBuilder: (o) => _KdsOrderCard(
                        order: o,
                        accentColor: Colors.amberAccent,
                        actions: [
                          if (o.status == 'confirmed')
                            _KdsCardAction(
                              label: 'Start Cooking',
                              color: Colors.amberAccent,
                              onPressed: () => _startPreparing(o),
                            )
                          else
                            _KdsCardAction(
                              label: 'Mark Ready',
                              color: Colors.tealAccent,
                              onPressed: () => _markReadyAndAssign(o),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _KdsColumn(
                      title: 'Ready for Pickup',
                      accentColor: Colors.blueAccent,
                      orders: ready,
                      childBuilder: (o) => _KdsOrderCard(
                        order: o,
                        accentColor: Colors.blueAccent,
                        actions: [
                          _KdsCardAction(
                            label: 'Mark Delivered',
                            color: Colors.greenAccent,
                            onPressed: () => _markDelivered(o),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Portrait View - Tabbed swipeable view
            return DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: _red,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: 'Pending (${pending.length})'),
                      Tab(text: 'Preparing (${preparing.length})'),
                      Tab(text: 'Ready (${ready.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: _KdsColumn(
                            title: 'Pending',
                            accentColor: Colors.orangeAccent,
                            orders: pending,
                            hideHeader: true,
                            childBuilder: (o) => _KdsOrderCard(
                              order: o,
                              accentColor: Colors.orangeAccent,
                              actions: [
                                _KdsCardAction(
                                  label: 'Reject',
                                  color: Colors.redAccent,
                                  onPressed: () => _rejectOrder(o),
                                ),
                                _KdsCardAction(
                                  label: 'Confirm',
                                  color: _red,
                                  onPressed: () => _confirmOrder(o),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: _KdsColumn(
                            title: 'Preparing',
                            accentColor: Colors.amberAccent,
                            orders: preparing,
                            hideHeader: true,
                            childBuilder: (o) => _KdsOrderCard(
                              order: o,
                              accentColor: Colors.amberAccent,
                              actions: [
                                if (o.status == 'confirmed')
                                  _KdsCardAction(
                                    label: 'Start Cooking',
                                    color: Colors.amberAccent,
                                    onPressed: () => _startPreparing(o),
                                  )
                                else
                                  _KdsCardAction(
                                    label: 'Mark Ready',
                                    color: Colors.tealAccent,
                                    onPressed: () => _markReadyAndAssign(o),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: _KdsColumn(
                            title: 'Ready',
                            accentColor: Colors.blueAccent,
                            orders: ready,
                            hideHeader: true,
                            childBuilder: (o) => _KdsOrderCard(
                              order: o,
                              accentColor: Colors.blueAccent,
                              actions: [
                                _KdsCardAction(
                                  label: 'Mark Delivered',
                                  color: Colors.greenAccent,
                                  onPressed: () => _markDelivered(o),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

// --- Columns and Components ---

class _KdsColumn extends StatelessWidget {
  final String title;
  final Color accentColor;
  final List<Order> orders;
  final Widget Function(Order) childBuilder;
  final bool hideHeader;

  const _KdsColumn({
    required this.title,
    required this.accentColor,
    required this.orders,
    required this.childBuilder,
    this.hideHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        children: [
          if (!hideHeader) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${orders.length}',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Text(
                      'No Orders',
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    itemBuilder: (context, index) =>
                        childBuilder(orders[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KdsOrderCard extends StatelessWidget {
  final Order order;
  final Color accentColor;
  final List<_KdsCardAction> actions;

  const _KdsOrderCard({
    required this.order,
    required this.accentColor,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _stroke),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminOrderDetailScreen(orderId: order.id),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: ID + Timer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${order.orderNumber}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (order.createdAt != null)
                    _KdsTimerText(createdAt: order.createdAt!),
                ],
              ),
              const Divider(color: _stroke, height: 16),

              // Items Details (Large touchable font)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: order.items.length,
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity}x ',
                          style: GoogleFonts.poppins(
                            color: _red,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.productName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Kitchen/Delivery Notes
              if (order.deliveryNotes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Note: ${order.deliveryNotes}',
                    style: GoogleFonts.poppins(
                      color: Colors.amberAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              // Customer / Footer Details
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.customerName.isNotEmpty
                          ? order.customerName
                          : 'Guest Customer',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    order.paymentMethod.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: order.paymentMethod == 'online'
                          ? Colors.green
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

              // Action buttons (large targets)
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: actions
                      .map(
                        (act) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: act.color,
                                foregroundColor:
                                    act.color == Colors.tealAccent ||
                                        act.color == Colors.greenAccent
                                    ? Colors.black87
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: act.onPressed,
                              child: Text(
                                act.label,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KdsCardAction {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _KdsCardAction({
    required this.label,
    required this.color,
    required this.onPressed,
  });
}

// --- Dynamic SLA Timer Widget ---

class _KdsTimerText extends StatefulWidget {
  final DateTime createdAt;
  const _KdsTimerText({required this.createdAt});

  @override
  State<_KdsTimerText> createState() => _KdsTimerTextState();
}

class _KdsTimerTextState extends State<_KdsTimerText> {
  late Timer _timer;
  late Duration _elapsed;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _calc();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calc();
          if (_elapsed.inMinutes >= 20) {
            _flash = !_flash;
          }
        });
      }
    });
  }

  void _calc() {
    _elapsed = DateTime.now().difference(widget.createdAt);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed.inMinutes;
    final seconds = _elapsed.inSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    Color textColor = Colors.greenAccent;
    if (minutes >= 10 && minutes < 20) {
      textColor = Colors.orangeAccent;
    } else if (minutes >= 20) {
      textColor = _flash ? Colors.redAccent : Colors.transparent;
    }

    return Text(
      timeStr,
      style: GoogleFonts.poppins(
        color: textColor,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }
}

// --- Inline Dialog Components ---

class _PrepTimeDialog extends StatefulWidget {
  @override
  State<_PrepTimeDialog> createState() => _PrepTimeDialogState();
}

class _PrepTimeDialogState extends State<_PrepTimeDialog> {
  int prepTime = 20;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: const Text(
        'Confirm Prep Time',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
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
            onChanged: (v) => setState(() => prepTime = v.toInt()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _red),
          onPressed: () => Navigator.pop(context, prepTime),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _AssignDriverDialog extends StatefulWidget {
  final List<DeliveryStaff> staffList;
  final DeliveryStaff initial;

  const _AssignDriverDialog({required this.staffList, required this.initial});

  @override
  State<_AssignDriverDialog> createState() => _AssignDriverDialogState();
}

class _AssignDriverDialogState extends State<_AssignDriverDialog> {
  late DeliveryStaff selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: const Text(
        'Assign Delivery Partner',
        style: TextStyle(color: Colors.white),
      ),
      content: DropdownButtonFormField<DeliveryStaff>(
        dropdownColor: _card,
        value: selected,
        items: widget.staffList
            .map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(
                  s.name,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() {
          if (v != null) selected = v;
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Skip / Auto Assign',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _red),
          onPressed: () => Navigator.pop(context, selected),
          child: const Text('Assign & Ready'),
        ),
      ],
    );
  }
}
