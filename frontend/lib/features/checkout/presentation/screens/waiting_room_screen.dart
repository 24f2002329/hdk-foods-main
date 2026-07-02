import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../../orders/data/repositories/order_repository.dart';
import '../../../orders/presentation/widgets/modified_order_dialog.dart';
import '../../../../core/navigation/app_routes.dart';

const _surface = Color(0xFF050505);
const _deepText = Colors.white;

class WaitingRoomScreen extends StatefulWidget {
  final int orderId;
  final String orderNumber;
  final String paymentMethod;

  const WaitingRoomScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    this.paymentMethod = 'cod',
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  int _secondsRemaining = 300; // 5 minutes
  bool _isLoading = true;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startPolling();
    // Initial check
    _checkOrderStatus();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkOrderStatus();
    });
  }

  Future<void> _checkOrderStatus() async {
    if (_navigated) return;

    try {
      final order = await _orderRepository.getOrder(widget.orderId);

      if (order.status == 'confirmed') {
        _navigated = true;
        _countdownTimer?.cancel();
        _pollingTimer?.cancel();
        await _proceedAfterConfirmation(order);
      } else if (order.status == 'rejected' || order.status == 'cancelled') {
        _navigated = true;
        _countdownTimer?.cancel();
        _pollingTimer?.cancel();

        if (mounted) {
          AppRoutes.pushReplacementOrderRejected(
            context,
            orderNumber: order.orderNumber,
            reason: order.cancellationReason,
            isOnlinePaid:
                order.paymentMethod == 'online' &&
                order.paymentStatus == 'paid',
          );
        }
      }
    } catch (e) {
      debugPrint("Error checking order status: $e");
    } finally {
      if (_isLoading && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _proceedAfterConfirmation(Order order) async {
    if (!mounted) return;
    var currentOrder = order;

    if (currentOrder.isModifiedByStaff) {
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ModifiedOrderDialog(order: currentOrder),
      );

      if (accepted == null) {
        _navigated = false;
        return;
      }

      try {
        currentOrder = await _orderRepository.acknowledgeChanges(
          orderId: currentOrder.id,
          accepted: accepted,
        );
      } catch (e) {
        _navigated = false;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
        return;
      }

      if (!accepted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled. Refund in 3–5 business days.'),
          ),
        );
        Navigator.pop(context);
        return;
      }
    }

    if (widget.paymentMethod == 'cod') {
      // Register the COD choice, then celebrate before tracking.
      try {
        await _orderRepository.selectPayment(
          orderId: currentOrder.id,
          method: 'cod',
        );
      } catch (e) {
        debugPrint("Error registering COD payment: $e");
      }
      if (!mounted) return;
      AppRoutes.pushReplacementOrderConfirmed(
        context,
        orderNumber: currentOrder.orderNumber,
        isOnlinePayment: false,
        nextRouteName: AppRoutes.orderTracking,
        nextRouteArgs: {'orderId': currentOrder.id},
      );
      return;
    }

    // Online -> celebrate, then collect payment via Cashfree.
    if (!mounted) return;
    AppRoutes.pushReplacementOrderConfirmed(
      context,
      orderNumber: currentOrder.orderNumber,
      isOnlinePayment: true,
      nextRouteName: AppRoutes.payment,
      nextRouteArgs: {
        'orderId': currentOrder.id,
        'orderNumber': currentOrder.orderNumber,
        'totalAmount': currentOrder.totalAmount,
        'lockedMethod': 'online',
      },
    );
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining / 60).floor();
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _callRestaurant() async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: '+919999999999',
    ); // Replace with actual restaurant number
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch phone dialer")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Waiting for Confirmation',
          style: TextStyle(fontWeight: FontWeight.w900, color: _deepText),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Prevent going back while waiting
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.restaurant,
                  size: 80,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Your order has been sent to the kitchen!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _deepText,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Order #${widget.orderNumber}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 48),
                if (_secondsRemaining > 0) ...[
                  const Text(
                    'Time remaining for confirmation:',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formattedTime,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'The restaurant is taking longer than expected.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 32),
                const SizedBox(
                  height: 140,
                  child: LottieOr(
                    asset: 'assets/animations/confirming_order.json',
                    height: 140,
                    fallback: CircularProgressIndicator(
                      color: Colors.orangeAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Need to change your order or add a note?',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _callRestaurant,
                    icon: const Icon(Icons.phone),
                    label: const Text(
                      'Call Restaurant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: _surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
