import 'package:flutter/material.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';

import '../../../orders/domain/repositories/order_repository.dart';
import '../../../../core/navigation/app_routes.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class PaymentScreen extends StatefulWidget {
  final int orderId;
  final String orderNumber;
  final double totalAmount;

  /// When set, the user already chose this method at checkout, so the
  /// selection tiles are hidden and only the chosen method is shown.
  final String? lockedMethod;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.totalAmount,
    this.lockedMethod,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final OrderRepository _orderRepository = OrderRepository.instance;
  final CFPaymentGatewayService _cfService = CFPaymentGatewayService();

  late String _selectedMethod = widget.lockedMethod ?? 'cod';
  bool _isProcessing = false;

  bool get _isLocked => widget.lockedMethod != null;

  @override
  void initState() {
    super.initState();
    _cfService.setCallback(_onPaymentVerify, _onPaymentError);
  }

  void _goToTracking() {
    AppRoutes.pushReplacementOrderTracking(context, orderId: widget.orderId);
  }

  /// Cashfree invokes this when the checkout flow finishes. It hands back the
  /// order id (our order_number); the backend then fetches the authoritative
  /// status from Cashfree and marks the order paid.
  Future<void> _onPaymentVerify(String orderId) async {
    try {
      final order = await _orderRepository.verifyPayment(
        orderId: widget.orderId,
      );

      if (!mounted) return;
      final paid = order.paymentStatus == 'paid';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paid
                ? 'Payment successful!'
                : 'Payment received — confirming with the bank...',
          ),
        ),
      );
      // Either way head to tracking, which keeps reconciling the status.
      _goToTracking();
    } catch (e) {
      _showError('Payment captured but verification failed. $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _onPaymentError(CFErrorResponse errorResponse, String orderId) {
    _showError('Payment failed: ${errorResponse.getMessage() ?? 'cancelled'}');
    if (mounted) setState(() => _isProcessing = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pay() async {
    setState(() => _isProcessing = true);

    try {
      final result = await _orderRepository.selectPayment(
        orderId: widget.orderId,
        method: _selectedMethod,
      );

      if (_selectedMethod == 'cod') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed with Cash on Delivery.')),
        );
        _goToTracking();
        return;
      }

      // online -> open Cashfree web checkout.
      final environment = result['environment'] == 'production'
          ? CFEnvironment.PRODUCTION
          : CFEnvironment.SANDBOX;

      final session = CFSessionBuilder()
          .setEnvironment(environment)
          .setOrderId(result['cf_order_id'])
          .setPaymentSessionId(result['payment_session_id'])
          .build();

      // NOTE: the SDK setter name is doubled ("...ColorColor") — that is the
      // upstream method name, not a typo here.
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
      if (mounted) setState(() => _isProcessing = false);
    } catch (e) {
      _showError('$e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _methodTile({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedMethod == value;
    return GestureDetector(
      onTap: (_isProcessing || _isLocked)
          ? null
          : () => setState(() => _selectedMethod = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _brandRed : _stroke,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _brandRed : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: _brandRed),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment for HDK Kitchen',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${widget.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isLocked ? 'Payment Method' : 'Select Payment Method',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (!_isLocked || _selectedMethod == 'cod')
              _methodTile(
                value: 'cod',
                icon: Icons.money,
                title: 'Cash on Delivery',
                subtitle: 'Pay when your order arrives',
              ),
            if (!_isLocked || _selectedMethod == 'online')
              _methodTile(
                value: 'online',
                icon: Icons.account_balance_wallet,
                title: 'Pay Online',
                subtitle: 'UPI, cards, netbanking via Cashfree',
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandRed,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isProcessing ? null : _pay,
            child: _isProcessing
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _selectedMethod == 'cod'
                        ? 'Place Order (COD)'
                        : 'Pay ₹${widget.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
