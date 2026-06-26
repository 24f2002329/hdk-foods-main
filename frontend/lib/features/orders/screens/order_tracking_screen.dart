import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/order_websocket_service.dart';
import '../../../core/widgets/error_retry.dart';
import '../models/order.dart';
import '../services/delivery_location_service.dart';
import '../services/order_service.dart';
import '../widgets/modified_order_dialog.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _panelAlt = Color(0xFF181818);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final DeliveryLocationService _deliveryLocationService =
      DeliveryLocationService();

  static const List<Map<String, dynamic>> _steps = [
    {'key': 'confirmed', 'label': 'Order Confirmed', 'icon': Icons.check_circle_outline_rounded},
    {'key': 'preparing', 'label': 'Preparing', 'icon': Icons.restaurant_rounded},
    {'key': 'ready_for_pickup', 'label': 'Ready for Pickup', 'icon': Icons.inventory_2_outlined},
    {'key': 'out_for_delivery', 'label': 'Out for Delivery', 'icon': Icons.delivery_dining_rounded},
    {'key': 'delivered', 'label': 'Delivered', 'icon': Icons.home_rounded},
  ];

  Timer? _pollingTimer;
  OrderWebSocketService? _wsService;
  Order? _order;
  String? _error;
  bool _loading = true;
  bool _modifiedDialogShown = false;
  int? _queuePosition;
  bool _reviewSubmitted = false;
  bool _reviewLoading = false;
  DeliveryLocation? _deliveryLocation;

  late AnimationController _stepAnim;

  @override
  void initState() {
    super.initState();
    _stepAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _load();

    // Prefer WebSocket for real-time updates; fall back to 25-second polling
    // if the WebSocket cannot connect (e.g. no server support yet).
    _wsService = OrderWebSocketService(widget.orderId);
    _wsService!.connect();
    _wsService!.stream.listen((data) {
      try {
        final order = Order.fromJson(data);
        if (mounted) _applyOrder(order);
      } catch (_) {}
    });

    _pollingTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _wsService?.dispose();
    _stepAnim.dispose();
    super.dispose();
  }

  void _applyOrder(Order order) {
    if (!mounted) return;
    setState(() {
      _order = order;
      _loading = false;
      _error = null;
    });
    _stepAnim.forward(from: 0);

    if (order.isModifiedByStaff &&
        order.status == 'confirmed' &&
        !_modifiedDialogShown) {
      _modifiedDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showModifiedOrderDialog(order);
      });
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() { _loading = true; _error = null; });
    try {
      var order = await _orderService.getOrder(widget.orderId);

      if (order.paymentMethod == 'online' && order.paymentStatus == 'pending') {
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
      _stepAnim.forward(from: 0);

      if (order.isModifiedByStaff &&
          order.status == 'confirmed' &&
          !_modifiedDialogShown) {
        _modifiedDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showModifiedOrderDialog(order);
        });
      }

      if (order.status == 'pending_confirmation') {
        try {
          final q = await _orderService.getQueuePosition(widget.orderId);
          if (mounted) setState(() => _queuePosition = q);
        } catch (_) {}
      } else {
        if (mounted) setState(() => _queuePosition = null);
      }

      if (order.status == 'delivered' && !_reviewSubmitted) {
        try {
          final reviewed = await _orderService.hasReview(widget.orderId);
          if (mounted) setState(() => _reviewSubmitted = reviewed);
        } catch (_) {}
      }

      if (order.status == 'out_for_delivery') {
        try {
          final loc = await _deliveryLocationService
              .getDeliveryLocation(widget.orderId);
          if (mounted) setState(() => _deliveryLocation = loc);
        } catch (_) {}
      } else {
        if (mounted) setState(() => _deliveryLocation = null);
      }

      if (['delivered', 'cancelled', 'rejected'].contains(order.status)) {
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
      builder: (_) => ModifiedOrderDialog(order: order),
    );
    if (accepted == null || !mounted) return;
    try {
      await _orderService.acknowledgeChanges(orderId: order.id, accepted: accepted);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accepted
              ? 'Order accepted! Tracking updated.'
              : 'Order cancelled. Refund in 3–5 business days.'),
          duration: Duration(seconds: accepted ? 3 : 6),
        ));
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      _modifiedDialogShown = false;
    }
  }

  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panelAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NeedHelpSheet(order: _order!),
    );
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

    return RefreshIndicator(
      onRefresh: _load,
      color: _brandRed,
      backgroundColor: _panel,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Header card ────────────────────────────────────────────────
          _OrderHeaderCard(order: order),

          // ── Queue banner ───────────────────────────────────────────────
          if (_queuePosition != null && order.status == 'pending_confirmation') ...[
            const SizedBox(height: 12),
            _QueueBanner(position: _queuePosition!),
          ],

          // ── Late warning ───────────────────────────────────────────────
          if (order.estimatedDeliveryTime != null &&
              DateTime.now().isAfter(order.estimatedDeliveryTime!) &&
              !['delivered', 'cancelled', 'rejected'].contains(order.status)) ...[
            const SizedBox(height: 12),
            _LateBanner(),
          ],

          const SizedBox(height: 20),

          // ── Status stepper or cancelled state ─────────────────────────
          isCancelled
              ? _CancelledCard(order: order)
              : _AnimatedStepper(
                  steps: _steps,
                  currentStatus: order.status,
                  animation: _stepAnim,
                ),

          const SizedBox(height: 20),

          // ── Delivery address + map ─────────────────────────────────────
          if (order.address != null) ...[
            _AddressMapCard(
              address: order.address!,
              deliveryLocation: _deliveryLocation,
              isOutForDelivery: order.status == 'out_for_delivery',
            ),
            const SizedBox(height: 16),
          ],

          // ── Items ──────────────────────────────────────────────────────
          if (order.items.isNotEmpty) ...[
            _ItemsCard(order: order),
            const SizedBox(height: 16),
          ],

          // ── Need Help ──────────────────────────────────────────────────
          _NeedHelpButton(onTap: _showHelpSheet),

          // ── Review card ────────────────────────────────────────────────
          if (order.status == 'delivered') ...[
            const SizedBox(height: 16),
            _ReviewCard(
              orderId: order.id,
              submitted: _reviewSubmitted,
              loading: _reviewLoading,
              onSubmit: (rating, comment) async {
                setState(() => _reviewLoading = true);
                try {
                  await _orderService.submitReview(
                      orderId: order.id, rating: rating, comment: comment);
                  if (mounted) {
                    setState(() {
                      _reviewSubmitted = true;
                      _reviewLoading = false;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _reviewLoading = false);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ── Header card ───────────────────────────────────────────────────────────────
class _OrderHeaderCard extends StatelessWidget {
  final Order order;
  const _OrderHeaderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _brandRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _brandRed.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '#${order.orderNumber}',
                  style: const TextStyle(
                    color: _brandRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              if (order.createdAt != null)
                Text(
                  _formatDate(order.createdAt!),
                  style: const TextStyle(color: _mutedText, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Amount',
                      style: TextStyle(color: _mutedText, fontSize: 12)),
                  const SizedBox(height: 2),
                  if (order.originalTotal != null &&
                      order.originalTotal != order.totalAmount) ...[
                    Text(
                      '₹${order.originalTotal!.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: _mutedText,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  if (order.discountAmount > 0)
                    Text(
                      'Saved ₹${order.discountAmount.toStringAsFixed(0)}'
                      '${order.discountReason.isNotEmpty ? " · ${order.discountReason}" : ""}',
                      style: const TextStyle(
                          color: Colors.greenAccent, fontSize: 11),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _PaymentBadge(method: order.paymentMethod, status: order.paymentStatus),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day} ${months[local.month - 1]}, $h:$m $period';
  }
}

class _PaymentBadge extends StatelessWidget {
  final String method;
  final String status;
  const _PaymentBadge({required this.method, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'paid':
        color = Colors.greenAccent;
        break;
      case 'failed':
        color = Colors.redAccent;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            method.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
          ),
          Text(
            status.toUpperCase(),
            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Queue banner ──────────────────────────────────────────────────────────────
class _QueueBanner extends StatelessWidget {
  final int position;
  const _QueueBanner({required this.position});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.queue_rounded, color: Colors.blueAccent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              position == 1 ? "You're next! 🎉" : "You're #$position in queue",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            if (position > 1)
              Text(
                '${position - 1} order${position - 1 > 1 ? "s" : ""} ahead of you',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ── Late banner ───────────────────────────────────────────────────────────────
class _LateBanner extends StatelessWidget {
  const _LateBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
      ),
      child: const Row(children: [
        Icon(Icons.access_time_rounded, color: Colors.orangeAccent, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Your order is taking longer than expected. Sorry for the wait! 🙏',
            style: TextStyle(
                color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}

// ── Animated stepper ──────────────────────────────────────────────────────────
class _AnimatedStepper extends StatelessWidget {
  final List<Map<String, dynamic>> steps;
  final String currentStatus;
  final Animation<double> animation;

  const _AnimatedStepper({
    required this.steps,
    required this.currentStatus,
    required this.animation,
  });

  int get _currentIdx =>
      steps.indexWhere((s) => s['key'] == currentStatus);

  @override
  Widget build(BuildContext context) {
    final currentIdx = _currentIdx;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        children: List.generate(steps.length, (i) {
          final reached = currentIdx >= i && currentIdx != -1;
          final isActive = i == currentIdx;
          final isLast = i == steps.length - 1;

          final stepInterval = Interval(
            i / steps.length,
            (i + 1) / steps.length,
            curve: Curves.easeOut,
          );

          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = stepInterval.transform(animation.value);
              return Opacity(
                opacity: reached ? (0.4 + 0.6 * t).clamp(0.0, 1.0) : 0.35,
                child: Transform.translate(
                  offset: Offset(reached ? (1 - t) * 12 : 0, 0),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon + connector line
                        Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? _brandRed
                                    : reached
                                        ? _brandRed.withValues(alpha: 0.7)
                                        : _stroke,
                                shape: BoxShape.circle,
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: _brandRed.withValues(alpha: 0.4),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                reached
                                    ? (isActive
                                        ? steps[i]['icon'] as IconData
                                        : Icons.check_rounded)
                                    : steps[i]['icon'] as IconData,
                                size: 18,
                                color: reached ? Colors.white : Colors.grey,
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  width: 2,
                                  color: reached ? _brandRed.withValues(alpha: 0.6) : _stroke,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Label
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: 7,
                              bottom: isLast ? 0 : 22,
                            ),
                            child: Text(
                              steps[i]['label'] as String,
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : reached
                                        ? Colors.white70
                                        : Colors.grey,
                                fontSize: isActive ? 16 : 14,
                                fontWeight: isActive
                                    ? FontWeight.w900
                                    : reached
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        if (isActive)
                          const Padding(
                            padding: EdgeInsets.only(top: 9),
                            child: _PulseDot(),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: _brandRed,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Cancelled card ────────────────────────────────────────────────────────────
class _CancelledCard extends StatelessWidget {
  final Order order;
  const _CancelledCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22),
              const SizedBox(width: 10),
              Text(
                order.status == 'rejected'
                    ? 'Order Rejected by Kitchen'
                    : 'Order Cancelled',
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 15),
              ),
            ],
          ),
          if (order.paymentMethod == 'online' &&
              order.paymentStatus == 'paid') ...[
            const SizedBox(height: 10),
            const Text(
              'A refund will be processed to your original payment method in 3–5 business days.',
              style: TextStyle(color: _mutedText, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Address + live tracking map card ─────────────────────────────────────────
class _AddressMapCard extends StatefulWidget {
  final OrderAddress address;
  final DeliveryLocation? deliveryLocation;
  final bool isOutForDelivery;

  const _AddressMapCard({
    required this.address,
    this.deliveryLocation,
    this.isOutForDelivery = false,
  });

  @override
  State<_AddressMapCard> createState() => _AddressMapCardState();
}

class _AddressMapCardState extends State<_AddressMapCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  GoogleMapController? _mapCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_AddressMapCard old) {
    super.didUpdateWidget(old);
    final loc = widget.deliveryLocation;
    if (loc != null && _mapCtrl != null) {
      _mapCtrl!.animateCamera(
        CameraUpdate.newLatLng(LatLng(loc.latitude, loc.longitude)),
      );
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final addr = widget.address;
    final loc = widget.deliveryLocation;
    final isOut = widget.isOutForDelivery;
    final hasAddrCoords = addr.latitude != null && addr.longitude != null;
    final hasLiveLoc = isOut && loc != null;
    final showMap = hasAddrCoords || hasLiveLoc;

    final Set<Marker> markers = {};
    if (hasAddrCoords) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(addr.latitude!, addr.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: addr.label.isNotEmpty ? addr.label : 'Your Address',
        ),
      ));
    }
    if (hasLiveLoc) {
      markers.add(Marker(
        markerId: const MarkerId('delivery_person'),
        position: LatLng(loc.latitude, loc.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Delivery Partner'),
      ));
    }

    final cameraTarget = hasLiveLoc
        ? LatLng(loc.latitude, loc.longitude)
        : hasAddrCoords
            ? LatLng(addr.latitude!, addr.longitude!)
            : const LatLng(0, 0);

    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOut && hasLiveLoc
              ? Colors.blueAccent.withValues(alpha: 0.5)
              : _stroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Map section ──────────────────────────────────────────────
          if (showMap)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 240,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition:
                          CameraPosition(target: cameraTarget, zoom: 15),
                      markers: markers,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      onMapCreated: (c) => _mapCtrl = c,
                    ),
                    // LIVE badge
                    if (hasLiveLoc)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, child) => Opacity(
                            opacity: _pulseAnim.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent
                                        .withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.radio_button_checked,
                                      color: Colors.white, size: 10),
                                  SizedBox(width: 4),
                                  Text('LIVE',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // "Waiting" overlay when out_for_delivery but no location yet
                    if (isOut && !hasLiveLoc)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _panel.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _stroke),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: _brandRed),
                              ),
                              SizedBox(width: 6),
                              Text('Locating partner…',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // ── Partner live status bar ───────────────────────────────────
          if (isOut)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.08),
                border: Border(
                  top: BorderSide(color: _stroke),
                  bottom: BorderSide(color: _stroke),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delivery_dining_rounded,
                        color: Colors.blueAccent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Partner is on the way',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                        if (hasLiveLoc && loc.updatedAt != null)
                          Text(
                            'Location updated ${_timeAgo(loc.updatedAt)}',
                            style: const TextStyle(
                                color: _mutedText, fontSize: 11),
                          )
                        else
                          const Text(
                            'Tracking will appear shortly',
                            style:
                                TextStyle(color: _mutedText, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  if (hasLiveLoc)
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent
                              .withValues(alpha: _pulseAnim.value),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── Address text section ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _brandRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: _brandRed, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivering to ${addr.label.isNotEmpty ? addr.label : "your address"}',
                        style: const TextStyle(
                            color: _mutedText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      if (addr.lineOne.isNotEmpty)
                        Text(
                          addr.lineOne,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                      if (addr.lineTwo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          addr.lineTwo,
                          style: const TextStyle(
                              color: _mutedText, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Items card ────────────────────────────────────────────────────────────────
class _ItemsCard extends StatelessWidget {
  final Order order;
  const _ItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity}×  ${item.productName}',
                      style: const TextStyle(color: _mutedText, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: _stroke, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              Text(
                '₹${order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: _brandRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Need Help button ──────────────────────────────────────────────────────────
class _NeedHelpButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NeedHelpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: _stroke),
        backgroundColor: _panel,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.support_agent_rounded, color: _brandRed),
      label: const Text(
        'Need Help With This Order?',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Need Help bottom sheet ────────────────────────────────────────────────────
class _NeedHelpSheet extends StatelessWidget {
  final Order order;
  const _NeedHelpSheet({required this.order});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Help with Order #${order.orderNumber}',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            "We're here to help. Reach us via:",
            style: TextStyle(color: _mutedText, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _HelpOption(
            icon: Icons.call_rounded,
            color: Colors.greenAccent,
            label: 'Call us',
            subtitle: 'Speak with support directly',
            onTap: () => _launch('tel:+919876543210'),
          ),
          const SizedBox(height: 12),
          _HelpOption(
            icon: Icons.chat_rounded,
            color: const Color(0xFF25D366),
            label: 'WhatsApp',
            subtitle: 'Chat on WhatsApp',
            onTap: () => _launch(
                'https://wa.me/919876543210?text=Hi%2C%20I%20need%20help%20with%20order%20%23${order.orderNumber}'),
          ),
          const SizedBox(height: 12),
          _HelpOption(
            icon: Icons.mail_outline_rounded,
            color: Colors.blueAccent,
            label: 'Email us',
            subtitle: 'support@hdkfoods.com',
            onTap: () => _launch(
                'mailto:support@hdkfoods.com?subject=Help%20with%20Order%20%23${order.orderNumber}'),
          ),
        ],
      ),
    );
  }
}

class _HelpOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _HelpOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _stroke),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: _mutedText, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────────
class _ReviewCard extends StatefulWidget {
  final int orderId;
  final bool submitted;
  final bool loading;
  final Future<void> Function(int rating, String comment) onSubmit;

  const _ReviewCard({
    required this.orderId,
    required this.submitted,
    required this.loading,
    required this.onSubmit,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: widget.submitted
          ? const Row(children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 10),
              Text('Thanks for your review! ⭐',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('How was your order? 🍽️',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        i < _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Add a comment (optional)',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF2A2A2A))),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF2A2A2A))),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _brandRed)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_rating == 0 || widget.loading)
                      ? null
                      : () => widget.onSubmit(_rating, _commentCtrl.text.trim()),
                  style: FilledButton.styleFrom(backgroundColor: _brandRed),
                  child: widget.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Review',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
    );
  }
}
