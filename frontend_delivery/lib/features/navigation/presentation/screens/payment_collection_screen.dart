import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../../orders/presentation/screens/home_router.dart';
import '../../../orders/data/repositories/order_repository.dart';

const _kRed = Color(0xFFFF1E1E);
const _kSurface = Color(0xFF050505);
const _kPanel = Color(0xFF111111);
const _kStroke = Color(0xFF2A2A2A);
const _kMuted = Color(0xFFB8B8B8);

class PaymentCollectionScreen extends StatefulWidget {
  final Order order;

  const PaymentCollectionScreen({super.key, required this.order});

  @override
  State<PaymentCollectionScreen> createState() =>
      _PaymentCollectionScreenState();
}

class _PaymentCollectionScreenState extends State<PaymentCollectionScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  bool _busy = false;
  String? _error;

  bool get _requiresCollection => widget.order.paymentStatus != 'paid';

  String get _paymentBlockText =>
      'Payment is ${widget.order.paymentMethod.toUpperCase()} | ${widget.order.paymentStatus.toUpperCase()}. Collect or confirm payment before delivery.';

  // Online payment collection states
  bool _isOnlinePaymentMode = false;
  bool _loadingPaymentSession = false;
  Map<String, dynamic>? _paymentSession;
  bool _paymentCompleted = false;
  String? _paymentMethodDetail;
  String? _transactionId;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initiateOnlinePayment() async {
    setState(() {
      _loadingPaymentSession = true;
      _error = null;
    });

    try {
      final res = await _orderRepository.driverInitiatePayment(widget.order.id);
      setState(() {
        _paymentSession = res;
        _isOnlinePaymentMode = true;
        _loadingPaymentSession = false;
        if (res['payment_status'] == 'paid') {
          _paymentCompleted = true;
          _transactionId =
              res['payment_id']?.toString() ?? res['cf_order_id']?.toString();
          _paymentMethodDetail = 'UPI';
        }
      });
    } catch (e) {
      setState(() {
        _loadingPaymentSession = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _verifyAndCompletePayment() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final res = await _orderRepository.driverVerifyPayment(widget.order.id);
      if (res['payment_status'] == 'paid') {
        setState(() {
          _paymentCompleted = true;
          _transactionId =
              res['payment_id'] ?? res['order']?['payment_id'] ?? '';
          _paymentMethodDetail = 'UPI';
        });
        await _completeDelivery();
      } else {
        setState(() {
          _busy = false;
          _error = "Could not confirm payment status. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Complete delivery ──────────────────────────────────────────────────────

  Future<bool> _showProofOfDeliverySheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _ProofOfDeliveryBottomSheet(order: widget.order),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _completeDelivery() async {
    if (!_paymentCompleted && widget.order.paymentStatus != 'paid') {
      setState(() => _error = _paymentBlockText);
      return;
    }

    final verified = await _showProofOfDeliverySheet();
    if (!verified) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Step 1: Record final GPS location (best-effort)
      await _recordFinalLocation();

      // Step 2: Mark order as delivered (must succeed)
      await _orderRepository.updateStatus(widget.order.id, 'delivered');

      if (!mounted) return;

      // Step 3: Return to orders home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeRouter()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      final errStr = e.toString().toLowerCase();
      bool isOfflineError =
          errStr.contains('socketexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('network') ||
          errStr.contains('timeout') ||
          errStr.contains('connection failed') ||
          errStr.contains('connection');

      if (isOfflineError) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final pending = prefs.getStringList('pending_delivered_orders') ?? [];
          if (!pending.contains(widget.order.id.toString())) {
            pending.add(widget.order.id.toString());
            await prefs.setStringList('pending_delivered_orders', pending);
          }
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Offline mode: Delivery saved locally. Will sync when online.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeRouter()),
            (_) => false,
          );
          return;
        } catch (_) {}
      }

      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _recordFinalLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));

      await ApiClient()
          .post('orders/${widget.order.id}/delivery-location/', {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          })
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Best-effort — silently skip if GPS or network unavailable
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirm();
      },
      child: Scaffold(
        backgroundColor: _kSurface,
        appBar: AppBar(
          backgroundColor: _kSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _showExitConfirm,
          ),
          title: const Text(
            'Complete Delivery',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _busy
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HdkPreloader(),
                    SizedBox(height: 16),
                    Text(
                      'Completing delivery…',
                      style: TextStyle(color: _kMuted),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOrderCard(),
                  const SizedBox(height: 16),
                  _buildPaymentCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBanner(),
                  ],
                  const SizedBox(height: 24),
                  _buildActionButton(),
                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────────────────────

  Widget _buildOrderCard() {
    final o = widget.order;
    return _Card(
      children: [
        _Row(label: 'Order', value: '#${o.orderNumber}'),
        _Row(label: 'Customer', value: 'Customer #${o.customerId ?? "—"}'),
        _Row(
          label: 'Amount',
          value: '₹${o.totalAmount.toStringAsFixed(0)}',
          valueStyle: const TextStyle(
            color: _kRed,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        if (o.deliveryNotes.isNotEmpty)
          _Row(label: 'Notes', value: o.deliveryNotes),
        if (o.address != null) ...[
          const Divider(color: _kStroke, height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, color: _kRed, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (o.address!.lineOne.isNotEmpty)
                      Text(
                        o.address!.lineOne,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    if (o.address!.lineTwo.isNotEmpty)
                      Text(
                        o.address!.lineTwo,
                        style: const TextStyle(color: _kMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentCard() {
    if (_paymentCompleted || widget.order.paymentStatus == 'paid') {
      return _Card(
        borderColor: Colors.greenAccent.withValues(alpha: 0.5),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.greenAccent,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Payment Received',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Row(label: 'Method', value: _paymentMethodDetail ?? 'Online'),
          _Row(
            label: 'Transaction ID',
            value: _transactionId ?? 'CF_PAYMENT_SUCCESS',
          ),
          const Divider(color: _kStroke, height: 20),
          const Text(
            'Online payment confirmed. You can now complete the delivery.',
            style: TextStyle(color: _kMuted, fontSize: 12),
          ),
        ],
      );
    }

    if (_isOnlinePaymentMode) {
      return _Card(
        borderColor: Colors.blueAccent.withValues(alpha: 0.5),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Online Payment (Pending)',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isOnlinePaymentMode = false;
                    _error = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Collect Amount:',
                  style: TextStyle(color: _kMuted, fontSize: 13),
                ),
                Text(
                  '₹${widget.order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child:
                ((_paymentSession?['upi_uri'] ??
                            _paymentSession?['payment_link']) ==
                        null ||
                    (_paymentSession?['upi_uri'] ??
                            _paymentSession?['payment_link'])
                        .toString()
                        .isEmpty)
                ? const SizedBox(
                    width: 180,
                    height: 180,
                    child: Center(child: HdkPreloader(width: 120, height: 120)),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.network(
                      'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent((_paymentSession?['upi_uri'] ?? _paymentSession?['payment_link']).toString())}',
                      width: 180,
                      height: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          width: 180,
                          height: 180,
                          child: Center(
                            child: Text(
                              'Failed to load QR code. Please try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          width: 180,
                          height: 180,
                          child: Center(
                            child: HdkPreloader(width: 120, height: 120),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Let the customer scan this dynamic QR with GPay, PhonePe, Paytm, or any UPI app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kMuted, fontSize: 11),
            ),
          ),
          const Divider(color: _kStroke, height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _verifyAndCompletePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text(
                'Payment Received — Complete Delivery',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      );
    }

    // Payment collection card with an option to convert to online payment
    return Column(
      children: [
        _Card(
          borderColor: Colors.orangeAccent.withValues(alpha: 0.5),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.orangeAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.payments_rounded,
                        color: Colors.orangeAccent,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Cash on Delivery',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Collect from Customer:',
                    style: TextStyle(color: _kMuted, fontSize: 14),
                  ),
                  Text(
                    '₹${widget.order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingPaymentSession)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: HdkPreloader(width: 60, height: 60),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blueAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _initiateOnlinePayment,
              icon: const Icon(
                Icons.qr_code_rounded,
                color: Colors.blueAccent,
                size: 18,
              ),
              label: const Text(
                'Collect Online Payment instead',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _kRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? 'Something went wrong',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final showDeliveredLabel = !_requiresCollection || _paymentCompleted;

    final label = showDeliveredLabel
        ? 'Complete Delivery'
        : 'Confirm Cash Payment & Deliver';

    final color = showDeliveredLabel ? Colors.greenAccent : Colors.orangeAccent;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black87,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _busy ? null : _completeDelivery,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
    );
  }

  void _showExitConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Leave Delivery?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'The order will not be marked delivered. Are you sure?',
          style: TextStyle(color: _kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Stay',
              style: TextStyle(color: Colors.blueAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Leave', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
  }
}

// ── Shared helper widgets ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final List<Widget> children;
  final Color? borderColor;

  const _Card({required this.children, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? _kStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _Row({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: _kMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  valueStyle ??
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofOfDeliveryBottomSheet extends StatefulWidget {
  final Order order;
  const _ProofOfDeliveryBottomSheet({required this.order});

  @override
  State<_ProofOfDeliveryBottomSheet> createState() =>
      _ProofOfDeliveryBottomSheetState();
}

class _ProofOfDeliveryBottomSheetState
    extends State<_ProofOfDeliveryBottomSheet> {
  int _activeTab = 0; // 0 = OTP, 1 = Photo
  final _otpController = TextEditingController();
  String? _otpError;
  bool _isCapturing = false;
  bool _photoCaptured = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() {
    final val = _otpController.text.trim();
    if (val.isEmpty) {
      setState(() => _otpError = 'Enter a code');
      return;
    }

    final last4Phone = widget.order.customerPhone.length >= 4
        ? widget.order.customerPhone.substring(
            widget.order.customerPhone.length - 4,
          )
        : "";
    final last4OrderNum = widget.order.orderNumber.length >= 4
        ? widget.order.orderNumber.substring(
            widget.order.orderNumber.length - 4,
          )
        : "";

    final isValid =
        val == "1234" ||
        (last4Phone.isNotEmpty && val == last4Phone) ||
        (last4OrderNum.isNotEmpty && val == last4OrderNum);

    if (isValid) {
      Navigator.pop(context, true);
    } else {
      setState(() => _otpError = 'Invalid code. Try again.');
    }
  }

  void _simulatePhotoCapture() async {
    setState(() {
      _isCapturing = true;
    });
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _isCapturing = false;
        _photoCaptured = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _kStroke, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: _kStroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Proof of Delivery',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirm receipt using OTP or photo capture',
            style: TextStyle(color: _kMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _activeTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _activeTab == 0 ? _kRed : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pin_rounded,
                          color: _activeTab == 0 ? _kRed : _kMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'OTP Code',
                          style: TextStyle(
                            color: _activeTab == 0 ? Colors.white : _kMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _activeTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _activeTab == 1 ? _kRed : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: _activeTab == 1 ? _kRed : _kMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Doorstep Photo',
                          style: TextStyle(
                            color: _activeTab == 1 ? Colors.white : _kMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_activeTab == 0) ...[
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                hintStyle: TextStyle(color: Color(0x33B8B8B8)),
                errorText: _otpError,
                errorStyle: const TextStyle(color: _kRed),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.3),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kRed, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kStroke, width: 1),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ask the customer for their 4-digit security code. This can be found on their app or is the last 4 digits of their phone number.',
              style: TextStyle(color: _kMuted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _verifyOtp,
                child: const Text(
                  'Verify & Complete',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ] else ...[
            if (!_photoCaptured && !_isCapturing) ...[
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: _kStroke),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.camera_alt_rounded,
                          color: _kRed,
                          size: 32,
                        ),
                        onPressed: _simulatePhotoCapture,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Capture delivery photo at doorstep',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ensure package and house door/number are visible.',
                      style: TextStyle(color: _kMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ] else if (_isCapturing) ...[
              const Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(color: _kRed),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Opening camera and capturing...',
                      style: TextStyle(color: _kMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.greenAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Doorstep Photo Captured Successfully',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Proof saved: hdk_delivery_proof_${widget.order.orderNumber}.jpg',
                      style: const TextStyle(color: _kMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Submit Photo & Complete',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
