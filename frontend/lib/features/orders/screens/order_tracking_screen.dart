import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';

import '../../../core/services/order_websocket_service.dart';
import 'package:hdk_core/hdk_core.dart';
import '../../cart/screens/cart_screen.dart';
import '../../cart/services/cart_provider.dart';
import '../../home/services/product_service.dart';
import '../services/delivery_location_service.dart';
import '../services/order_service.dart';
import '../widgets/modified_order_dialog.dart';
import 'order_chat_screen.dart';
import 'premium_review_screen.dart';

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
  final CFPaymentGatewayService _cfService = CFPaymentGatewayService();
  bool _isProcessingPayment = false;

  static const List<Map<String, dynamic>> _steps = [
    {
      'key': 'confirmed',
      'label': 'Order Confirmed',
      'icon': Icons.check_circle_outline_rounded,
    },
    {
      'key': 'preparing',
      'label': 'Preparing',
      'icon': Icons.restaurant_rounded,
    },
    {
      'key': 'out_for_delivery',
      'label': 'Out for Delivery',
      'icon': Icons.delivery_dining_rounded,
    },
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
  bool _isReordering = false;
  DeliveryLocation? _deliveryLocation;

  late AnimationController _stepAnim;

  @override
  void initState() {
    super.initState();
    _cfService.setCallback(_onPaymentVerify, _onPaymentError);
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
        if (data['type'] == 'chat_message') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: _panel,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _stroke),
                ),
                content: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: _brandRed,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Message from Kitchen',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            data['message']['message'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderChatScreen(
                              orderId: widget.orderId,
                              orderNumber: _order?.orderNumber ?? '',
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'View',
                        style: TextStyle(
                          color: _brandRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return;
        }

        if (data['type'] == 'location_update') {
          final list = data['data'] as List<dynamic>;
          final lat = double.tryParse(list[0].toString()) ?? 0.0;
          final lng = double.tryParse(list[1].toString()) ?? 0.0;
          if (mounted) {
            setState(() {
              _deliveryLocation = DeliveryLocation(
                latitude: lat,
                longitude: lng,
                updatedAt: DateTime.now(),
              );
            });
          }
          return;
        }

        final order = Order.fromJson(data);
        if (mounted) _applyOrder(order);
      } catch (_) {}
    });

    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
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
    final statusAdvanced = _order != null && _order!.status != order.status;
    setState(() {
      _order = order;
      _loading = false;
      _error = null;
    });
    if (statusAdvanced) HapticFeedback.mediumImpact();
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
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
          final loc = await _deliveryLocationService.getDeliveryLocation(
            widget.orderId,
          );
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

  Future<void> _onPaymentVerify(String orderId) async {
    try {
      final updated = await _orderService.verifyPayment(
        orderId: widget.orderId,
      );
      if (!mounted) return;
      setState(() {
        _order = updated;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment successful!')));
      _load(silent: true);
    } catch (e) {
      _showError('Payment captured but verification failed. $e');
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _onPaymentError(CFErrorResponse errorResponse, String orderId) {
    _showError('Payment failed: ${errorResponse.getMessage() ?? 'cancelled'}');
    if (mounted) setState(() => _isProcessingPayment = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reorder(Order order) async {
    if (order.items.isEmpty || _isReordering) return;
    setState(() => _isReordering = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final products = await ProductService.getProducts();
      final byId = {for (final p in products) p.id: p};
      if (!mounted) return;
      final cart = context.read<CartProvider>();
      cart.clearCart();
      int added = 0;
      int missing = 0;
      for (final line in order.items) {
        final product = line.productId != null ? byId[line.productId] : null;
        if (product == null || !product.isAvailable) {
          missing++;
          continue;
        }
        cart.addProduct(product, quantity: line.quantity, haptic: false);
        added++;
      }
      if (added > 0) HapticFeedback.mediumImpact();
      if (added == 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('These items are no longer available.')),
        );
        return;
      }
      if (missing > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('$added item(s) added · $missing unavailable'),
            backgroundColor: _panel,
          ),
        );
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not reorder. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isReordering = false);
    }
  }

  Future<void> _payOnline() async {
    if (_isProcessingPayment) return;
    setState(() => _isProcessingPayment = true);

    try {
      final result = await _orderService.selectPayment(
        orderId: widget.orderId,
        method: 'online',
      );

      final environment = result['environment'] == 'production'
          ? CFEnvironment.PRODUCTION
          : CFEnvironment.SANDBOX;

      final session = CFSessionBuilder()
          .setEnvironment(environment)
          .setOrderId(result['cf_order_id'])
          .setPaymentSessionId(result['payment_session_id'])
          .build();

      final theme = CFThemeBuilder()
          .setNavigationBarBackgroundColorColor('#FF1E1E')
          .setNavigationBarTextColor('#FFFFFF')
          .build();

      final cfWebCheckout = CFWebCheckoutPaymentBuilder()
          .setSession(session)
          .setTheme(theme)
          .build();

      _cfService.doPayment(cfWebCheckout);
    } on CFException catch (e) {
      _showError(e.message);
      if (mounted) setState(() => _isProcessingPayment = false);
    } catch (e) {
      _showError('$e');
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _requestCancellation(String reason) async {
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      await _orderService.requestCancellation(
        orderId: widget.orderId,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cancellation request submitted successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request cancellation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  void _showCancellationBottomSheet(Order order) {
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF151515),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Cancel Your Order',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please provide a reason for cancelling. If you paid online, a refund will be processed upon approval.',
                  style: TextStyle(color: Color(0xFFB8B8B8), fontSize: 13),
                ),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (context, setModalState) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: reasonCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          onChanged: (val) {
                            setModalState(() {});
                          },
                          decoration: InputDecoration(
                            hintText:
                                'e.g., I ordered the wrong item / entered incorrect address...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            contentPadding: const EdgeInsets.all(16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2A2A2A),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF1E1E),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  'Keep Order',
                                  style: TextStyle(
                                    color: Color(0xFFB8B8B8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: reasonCtrl.text.trim().isEmpty
                                    ? null
                                    : () {
                                        final reason = reasonCtrl.text.trim();
                                        Navigator.pop(ctx);
                                        _requestCancellation(reason);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF1E1E),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(
                                    0xFF333333,
                                  ),
                                  disabledForegroundColor: const Color(
                                    0xFF666666,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Request Cancel',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showModifiedOrderDialog(Order order) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ModifiedOrderDialog(order: order),
    );
    if (accepted == null || !mounted) return;
    try {
      await _orderService.acknowledgeChanges(
        orderId: order.id,
        accepted: accepted,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accepted
                  ? 'Order accepted! Tracking updated.'
                  : 'Order cancelled. Refund in 3–5 business days.',
            ),
            duration: Duration(seconds: accepted ? 3 : 6),
          ),
        );
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
      useRootNavigator: true,
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
        title: const Text(
          'Track Order',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(child: HdkPreloader())
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
          _OrderHeaderCard(order: order),

          // ── Review card at the top ──────────────────────────────────────
          if (order.status == 'delivered') ...[
            const SizedBox(height: 12),
            _PremiumReviewHeaderCard(
              order: order,
              submitted: _reviewSubmitted,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PremiumReviewScreen(order: order),
                  ),
                );
                if (result == true) {
                  setState(() {
                    _reviewSubmitted = true;
                  });
                }
              },
            ),
          ],

          // ── Cancellation Section Card ─────────────────────────────────
          if (order.cancellationRequested) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF221702), // dark warm amber
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF5E4300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amberAccent,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Cancellation Requested',
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
                    'You requested to cancel this order: "${order.cancellationReason}"',
                    style: const TextStyle(
                      color: Color(0xFFE2B93B),
                      fontSize: 12,
                    ),
                  ),
                  if (order.refundStatus.isNotEmpty &&
                      order.refundStatus != 'not_applicable') ...[
                    const SizedBox(height: 8),
                    Text(
                      'Online Refund Status: ${order.refundStatus.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          if ((order.paymentMethod == 'cod' ||
                  (order.paymentMethod == 'online' &&
                      order.paymentStatus != 'paid')) &&
              order.paymentStatus != 'paid' &&
              ![
                'delivered',
                'cancelled',
                'rejected',
              ].contains(order.status)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: order.isOnlinePaymentPending
                    ? const Color(0xFF2A1F05)
                    : _panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: order.isOnlinePaymentPending
                      ? const Color(0xFFFFC107).withValues(alpha: 0.55)
                      : _stroke,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        order.isOnlinePaymentPending
                            ? Icons.warning_amber_rounded
                            : Icons.payment_rounded,
                        color: order.isOnlinePaymentPending
                            ? Colors.amberAccent
                            : Colors.blueAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        order.paymentMethod == 'online'
                            ? 'Payment Pending'
                            : 'Want to Pay Online?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    order.paymentMethod == 'online'
                        ? 'Complete your online payment to keep this order moving.'
                        : 'You can pay online now using UPI, cards, or net banking before your order is delivered.',
                    style: TextStyle(
                      color: order.isOnlinePaymentPending
                          ? const Color(0xFFFFD76A)
                          : _mutedText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessingPayment ? null : _payOnline,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isProcessingPayment
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.flash_on_rounded, size: 16),
                      label: Text(
                        order.paymentMethod == 'online'
                            ? 'Pay Now'
                            : 'Pay Online Now',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Queue banner ───────────────────────────────────────────────
          if (_queuePosition != null &&
              order.status == 'pending_confirmation') ...[
            const SizedBox(height: 12),
            _QueueBanner(position: _queuePosition!),
          ],

          // ── Late warning ───────────────────────────────────────────────
          if (order.estimatedDeliveryTime != null &&
              DateTime.now().isAfter(order.estimatedDeliveryTime!) &&
              ![
                'delivered',
                'cancelled',
                'rejected',
              ].contains(order.status)) ...[
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

          if (order.status == 'delivered') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _CompactReorderButton(
                loading: _isReordering,
                enabled: order.items.isNotEmpty && !_isReordering,
                onTap: () => _reorder(order),
              ),
            ),
            const SizedBox(height: 12),
            _NotReceivedCard(
              order: order,
              onReport: () async {
                try {
                  final updated = await _orderService.reportNotReceived(
                    order.id,
                  );
                  if (mounted) _applyOrder(updated);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
            ),
          ],

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

          // ── Cancellation Option Banner ─────────────────────────────────
          if (!order.cancellationRequested &&
              order.status != 'delivered' &&
              order.status != 'cancelled' &&
              order.status != 'rejected') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1F1F1F)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFB8B8B8),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Need to cancel this order?',
                      style: TextStyle(color: Color(0xFFB8B8B8), fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showCancellationBottomSheet(order),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF1E1E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: const Text(
                      'Cancel Order',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Need Help ──────────────────────────────────────────────────
          _NeedHelpButton(onTap: _showHelpSheet),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _brandRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _brandRed.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'HDK KITCHEN',
                  style: TextStyle(
                    color: _brandRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.6,
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
                  const Text(
                    'Total Amount',
                    style: TextStyle(color: _mutedText, fontSize: 12),
                  ),
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
                        color: Colors.greenAccent,
                        fontSize: 11,
                      ),
                    ),
                  if (order.coinsRedeemed > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Redeemed ${order.coinsRedeemed} HDK Coins',
                        style: const TextStyle(
                          color: Color(0xFFFF8A00),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  if (order.coinsEarned > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Earned +${order.coinsEarned} HDK Coins! 🌟',
                        style: const TextStyle(
                          color: Color(0xFFFF8A00),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _PaymentBadge(
                    method: order.paymentMethod,
                    status: order.paymentStatus,
                  ),
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
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
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
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
      child: Row(
        children: [
          const Icon(Icons.queue_rounded, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  position == 1
                      ? "You're next! 🎉"
                      : "You're #$position in queue",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (position > 1)
                  Text(
                    '${position - 1} order${position - 1 > 1 ? "s" : ""} ahead of you',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
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
      child: const Row(
        children: [
          Icon(Icons.access_time_rounded, color: Colors.orangeAccent, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your order is taking longer than expected. Sorry for the wait! 🙏',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated stepper ──────────────────────────────────────────────────────────

/// Lottie asset for the active step of a given status, or null to keep the icon.
String? _stepLottieAsset(String key) {
  switch (key) {
    case 'preparing':
      return 'assets/animations/cooking.json';
    case 'out_for_delivery':
      return 'assets/animations/out_for_delivery.json';
    case 'delivered':
      return 'assets/animations/order_confirmed.json';
    default:
      return null;
  }
}

class _AnimatedStepper extends StatelessWidget {
  final List<Map<String, dynamic>> steps;
  final String currentStatus;
  final Animation<double> animation;

  const _AnimatedStepper({
    required this.steps,
    required this.currentStatus,
    required this.animation,
  });

  int get _currentIdx => steps.indexWhere((s) => s['key'] == currentStatus);

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
                                    ? Colors.white
                                    : reached
                                    ? _brandRed.withValues(alpha: 0.7)
                                    : _stroke,
                                shape: BoxShape.circle,
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child:
                                  (isActive &&
                                      _stepLottieAsset(
                                            steps[i]['key'] as String,
                                          ) !=
                                          null)
                                  ? LottieOr(
                                      asset: _stepLottieAsset(
                                        steps[i]['key'] as String,
                                      )!,
                                      width: 28,
                                      height: 28,
                                      fallback: Icon(
                                        steps[i]['icon'] as IconData,
                                        size: 18,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Icon(
                                      reached
                                          ? (isActive
                                                ? steps[i]['icon'] as IconData
                                                : Icons.check_rounded)
                                          : steps[i]['icon'] as IconData,
                                      size: 18,
                                      color: isActive
                                          ? Colors.black
                                          : (reached
                                                ? Colors.white
                                                : Colors.grey),
                                    ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  width: 2,
                                  color: reached
                                      ? _brandRed.withValues(alpha: 0.6)
                                      : _stroke,
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
    _scale = Tween<double>(
      begin: 0.7,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
              const Icon(
                Icons.cancel_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                order.status == 'rejected'
                    ? 'Order Rejected by Kitchen'
                    : 'Order Cancelled',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (order.paymentMethod == 'online') ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF222222)),
            const SizedBox(height: 10),
            const Text(
              'Refund Status Tracker',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _buildRefundStep(
              title: 'Refund Initiated',
              subtitle:
                  'Refund request processed by our kitchen to payment gateway.',
              isActive:
                  order.refundStatus == 'initiated' ||
                  order.paymentStatus == 'refunded',
              isCompleted:
                  order.refundStatus == 'initiated' ||
                  order.paymentStatus == 'refunded',
            ),
            _buildRefundStep(
              title: 'Processing by Bank',
              subtitle:
                  'Refund is being credited back to your account (usually takes 3-5 business days).',
              isActive:
                  order.refundStatus == 'initiated' ||
                  order.paymentStatus == 'refunded',
              isCompleted: false,
              isLast: true,
            ),
            if (order.refundStatus == 'failed') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Refund automated attempt failed. Support team is manually resolving this.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (order.paymentMethod == 'online' &&
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

  Widget _buildRefundStep({
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
    bool isLast = false,
  }) {
    final dotColor = isCompleted
        ? Colors.greenAccent
        : (isActive ? Colors.blueAccent : const Color(0xFF333333));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: isCompleted
                    ? Colors.greenAccent
                    : const Color(0xFF333333),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: _mutedText, fontSize: 11),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
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
  BitmapDescriptor? _destinationIcon;
  BitmapDescriptor? _deliveryIcon;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadCustomMarkers();
  }

  Future<void> _loadCustomMarkers() async {
    try {
      final dest = await _getCustomMarker(
        Icons.home_rounded,
        const Color(0xFFFF1E1E),
      );
      final deliv = await _getCustomMarker(
        Icons.delivery_dining_rounded,
        Colors.blueAccent,
      );
      if (mounted) {
        setState(() {
          _destinationIcon = dest;
          _deliveryIcon = deliv;
        });
      }
    } catch (_) {}
  }

  Future<BitmapDescriptor> _getCustomMarker(
    IconData iconData,
    Color color,
  ) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Background circle
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(const Offset(40, 40), 38, paint);

    // White border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(const Offset(40, 40), 38, borderPaint);

    // Icon
    final TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 44,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(40 - textPainter.width / 2, 40 - textPainter.height / 2),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(80, 80);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  void _fitMapBounds() {
    if (_mapCtrl == null) return;

    final addr = widget.address;
    final loc = widget.deliveryLocation;
    final hasAddrCoords = addr.latitude != null && addr.longitude != null;
    final hasLiveLoc = widget.isOutForDelivery && loc != null;

    if (hasAddrCoords && hasLiveLoc) {
      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          loc.latitude < addr.latitude! ? loc.latitude : addr.latitude!,
          loc.longitude < addr.longitude! ? loc.longitude : addr.longitude!,
        ),
        northeast: LatLng(
          loc.latitude > addr.latitude! ? loc.latitude : addr.latitude!,
          loc.longitude > addr.longitude! ? loc.longitude : addr.longitude!,
        ),
      );
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } else if (hasLiveLoc) {
      _mapCtrl!.animateCamera(
        CameraUpdate.newLatLng(LatLng(loc.latitude, loc.longitude)),
      );
    } else if (hasAddrCoords) {
      _mapCtrl!.animateCamera(
        CameraUpdate.newLatLng(LatLng(addr.latitude!, addr.longitude!)),
      );
    }
  }

  @override
  void didUpdateWidget(_AddressMapCard old) {
    super.didUpdateWidget(old);
    if (_mapCtrl != null) {
      _fitMapBounds();
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
    final showMap = isOut; // Map only shown while actively out for delivery

    final Set<Marker> markers = {};
    if (hasAddrCoords) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(addr.latitude!, addr.longitude!),
          icon:
              _destinationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: addr.label.isNotEmpty ? addr.label : 'Your Address',
          ),
        ),
      );
    }
    if (hasLiveLoc) {
      markers.add(
        Marker(
          markerId: const MarkerId('delivery_person'),
          position: LatLng(loc.latitude, loc.longitude),
          icon:
              _deliveryIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Delivery Partner'),
        ),
      );
    }

    final Set<Polyline> polylines = {};
    if (hasLiveLoc && hasAddrCoords) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          points: [
            LatLng(loc.latitude, loc.longitude),
            LatLng(addr.latitude!, addr.longitude!),
          ],
          color: _brandRed,
          width: 5,
          geodesic: true,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: 240,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: cameraTarget,
                        zoom: 15,
                      ),
                      markers: markers,
                      polylines: polylines,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      onMapCreated: (c) {
                        _mapCtrl = c;
                        Future.delayed(const Duration(milliseconds: 200), () {
                          _fitMapBounds();
                        });
                      },
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
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withValues(
                                      alpha: 0.6,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.radio_button_checked,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
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
                            horizontal: 10,
                            vertical: 5,
                          ),
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
                                  color: _brandRed,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Locating partner…',
                                style: TextStyle(
                                  color: Colors.white70,
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
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: Colors.blueAccent,
                      size: 18,
                    ),
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
                            fontSize: 13,
                          ),
                        ),
                        if (hasLiveLoc && loc.updatedAt != null)
                          Text(
                            'Location updated ${_timeAgo(loc.updatedAt)}',
                            style: const TextStyle(
                              color: _mutedText,
                              fontSize: 11,
                            ),
                          )
                        else
                          const Text(
                            'Tracking will appear shortly',
                            style: TextStyle(color: _mutedText, fontSize: 11),
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
                          color: Colors.blueAccent.withValues(
                            alpha: _pulseAnim.value,
                          ),
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
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: _brandRed,
                    size: 18,
                  ),
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (addr.lineOne.isNotEmpty)
                        Text(
                          addr.lineOne,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (addr.lineTwo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          addr.lineTwo,
                          style: const TextStyle(
                            color: _mutedText,
                            fontSize: 13,
                          ),
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
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
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
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: _stroke, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                '₹${order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: _brandRed,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
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
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "We're here to help. Reach us via:",
            style: TextStyle(color: _mutedText, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _HelpOption(
            icon: Icons.forum_rounded,
            color: _brandRed,
            label: 'Chat with Kitchen',
            subtitle: 'Message support in real-time',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderChatScreen(
                    orderId: order.id,
                    orderNumber: order.orderNumber,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
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
              'https://wa.me/919876543210?text=Hi%2C%20I%20need%20help%20with%20order%20%23${order.orderNumber}',
            ),
          ),
          const SizedBox(height: 12),
          _HelpOption(
            icon: Icons.mail_outline_rounded,
            color: Colors.blueAccent,
            label: 'Email us',
            subtitle: 'support@hdkfoods.com',
            onTap: () => _launch(
              'mailto:support@hdkfoods.com?subject=Help%20with%20Order%20%23${order.orderNumber}',
            ),
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
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _mutedText, fontSize: 12),
                    ),
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

// ── Premium Review Header Card ────────────────────────────────────────────────
class _PremiumReviewHeaderCard extends StatelessWidget {
  final Order order;
  final bool submitted;
  final VoidCallback onTap;

  const _PremiumReviewHeaderCard({
    required this.order,
    required this.submitted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: submitted
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: submitted
          ? const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review Submitted! ⭐',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Thank you for your feedback.',
                        style: TextStyle(color: _mutedText, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.rate_review_rounded,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate Food & Experience 🍽️',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _mutedText,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Compact Reorder Button ───────────────────────────────────────────────────
class _CompactReorderButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  const _CompactReorderButton({
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? _brandRed.withValues(alpha: 0.14) : _panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: enabled ? _brandRed.withValues(alpha: 0.55) : _stroke,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _brandRed,
                  ),
                )
              else
                Icon(
                  Icons.refresh_rounded,
                  size: 17,
                  color: enabled ? _brandRed : _mutedText,
                ),
              const SizedBox(width: 8),
              Text(
                loading ? 'Adding...' : 'Reorder',
                style: TextStyle(
                  color: enabled ? Colors.white : _mutedText,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Not Received Card ────────────────────────────────────────────────────────
class _NotReceivedCard extends StatefulWidget {
  final Order order;
  final Future<void> Function() onReport;
  const _NotReceivedCard({required this.order, required this.onReport});

  @override
  State<_NotReceivedCard> createState() => _NotReceivedCardState();
}

class _NotReceivedCardState extends State<_NotReceivedCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final reported = widget.order.notReceivedReported;

    return Material(
      color: _panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: reported ? Colors.orange.withValues(alpha: 0.5) : _stroke,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: reported
              ? Colors.orange.withValues(alpha: 0.15)
              : const Color(0xFF1A1A1A),
          child: Icon(
            reported ? Icons.hourglass_top_rounded : Icons.help_outline_rounded,
            color: reported ? Colors.orange : _mutedText,
            size: 20,
          ),
        ),
        title: Text(
          reported ? 'Report Submitted' : "Didn't receive your order?",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          reported
              ? 'Our team has been alerted and will look into it.'
              : "Tap to alert our team — we'll look into it right away.",
          style: const TextStyle(color: _mutedText, fontSize: 11),
        ),
        trailing: reported
            ? const Text(
                'REPORTED',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              )
            : (_loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _brandRed,
                      ),
                    )
                  : const Icon(Icons.chevron_right_rounded, color: _mutedText)),
        onTap: reported || _loading
            ? null
            : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _panel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: _stroke),
                    ),
                    title: const Text(
                      'Report Non-Receipt?',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    content: const Text(
                      "This will alert our team that you didn't receive your order. They will investigate and correct it.",
                      style: TextStyle(color: _mutedText, fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: _mutedText),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Report',
                          style: TextStyle(
                            color: _brandRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !mounted) return;
                setState(() => _loading = true);
                try {
                  await widget.onReport();
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
      ),
    );
  }
}
