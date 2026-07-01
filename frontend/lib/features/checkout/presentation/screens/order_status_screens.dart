import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hdk_core/hdk_core.dart';

const _surface = Color(0xFF050505);
const _brandRed = Color(0xFFFF1E1E);
const _mutedText = Color(0xFFB8B8B8);

/// Full-screen celebration shown when the kitchen accepts an order.
///
/// Plays the `order_confirmed` Lottie animation and then lets the user
/// continue to the next step (order tracking for COD, payment for online)
/// via [nextScreenBuilder].
class OrderConfirmedScreen extends StatefulWidget {
  final String orderNumber;
  final bool isOnlinePayment;
  final WidgetBuilder nextScreenBuilder;

  const OrderConfirmedScreen({
    super.key,
    required this.orderNumber,
    required this.nextScreenBuilder,
    this.isOnlinePayment = false,
  });

  @override
  State<OrderConfirmedScreen> createState() => _OrderConfirmedScreenState();
}

class _OrderConfirmedScreenState extends State<OrderConfirmedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _continue() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: widget.nextScreenBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const SizedBox(
                height: 200,
                child: LottieOr(
                  asset: 'assets/animations/order_confirmed.json',
                  height: 200,
                  repeat: false,
                  fallback: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    size: 120,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    children: [
                      const Text(
                        'Order Confirmed! 🎉',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'The kitchen has accepted your order and is getting '
                        'ready to cook. 🍳',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _mutedText,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _brandRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _brandRed.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Order #${widget.orderNumber}',
                          style: const TextStyle(
                            color: _brandRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _continue,
                  icon: Icon(
                    widget.isOnlinePayment
                        ? Icons.lock_rounded
                        : Icons.local_shipping_rounded,
                    size: 20,
                  ),
                  label: Text(
                    widget.isOnlinePayment
                        ? 'Proceed to Payment'
                        : 'Track My Order',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen state shown when the kitchen rejects (or cancels) an order.
class OrderRejectedScreen extends StatefulWidget {
  final String orderNumber;
  final String? reason;
  final bool isOnlinePaid;

  const OrderRejectedScreen({
    super.key,
    required this.orderNumber,
    this.reason,
    this.isOnlinePaid = false,
  });

  @override
  State<OrderRejectedScreen> createState() => _OrderRejectedScreenState();
}

class _OrderRejectedScreenState extends State<OrderRejectedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _backToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const SizedBox(
                height: 180,
                child: LottieOr(
                  asset: 'assets/animations/order_rejected.json',
                  height: 180,
                  repeat: false,
                  fallback: Icon(
                    Icons.cancel_rounded,
                    color: Colors.redAccent,
                    size: 110,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    const Text(
                      'Order Not Accepted',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Sorry, the kitchen couldn't take your order "
                      '#${widget.orderNumber} right now.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    if (widget.reason != null &&
                        widget.reason!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2A2A2A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: _mutedText,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.reason!,
                                style: const TextStyle(
                                  color: _mutedText,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (widget.isOnlinePaid) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'If you paid online, your refund will be processed to '
                        'your original payment method within 3–5 business days.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _backToHome,
                  icon: const Icon(Icons.home_rounded, size: 20),
                  label: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
