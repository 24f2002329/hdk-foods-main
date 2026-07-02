import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../accounts/data/repositories/user_service.dart';
import '../../../address/data/models/customer_address.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../address/data/repositories/address_service.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../orders/data/repositories/order_repository.dart';
import '../../../../shared/widgets/congratulations_overlay.dart';
import 'package:hdk_core/hdk_core.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final AddressService _addressService = AddressService();
  final OrderRepository _orderRepository = OrderRepository();
  final _couponCtrl = TextEditingController();

  CustomerAddress? _selectedAddress;
  String _selectedPaymentMethod = 'online';
  bool _isLoadingAddresses = true;
  bool _isCreatingOrder = false;
  String? _addressError;

  // Coupon state
  bool _isValidatingCoupon = false;
  Map<String, dynamic>? _couponResult;
  String? _couponError;

  // Loyalty coins state
  int _userCoins = 0;
  bool _redeemCoins = false;

  // Cutlery state
  bool _cutleryNeeded = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _loadUserCoins();
  }

  Future<void> _loadUserCoins() async {
    try {
      final user = await UserService().getCurrentUser();
      if (mounted) {
        setState(() {
          _userCoins = user.loyaltyCoins;
        });
      }
    } catch (_) {}
  }

  double _calculateCoinsDiscount(double remainingTotal) {
    return _userCoins < remainingTotal ? _userCoins.toDouble() : remainingTotal;
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final picked = await AppRoutes.pushAddresses<CustomerAddress>(
      context,
      selectionMode: true,
    );
    if (picked != null && mounted) {
      setState(() => _selectedAddress = picked);
    }
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses = await _addressService.getAddresses();
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
          if (addresses.isNotEmpty) {
            _selectedAddress = addresses.firstWhere(
              (a) => a.isDefault,
              orElse: () => addresses.first,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
          _addressError = e.toString();
        });
      }
    }
  }

  Future<void> _validateCoupon(double cartTotal) async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
      _couponResult = null;
    });
    try {
      final result = await _orderRepository.validateCoupon(
        code: code,
        orderTotal: cartTotal,
      );
      if (!mounted) return;
      if (result == null || result['valid'] == false) {
        setState(() {
          _couponError = result?['detail'] ?? 'Invalid coupon.';
          _couponResult = null;
        });
      } else {
        setState(() => _couponResult = result);
        final discount =
            double.tryParse(result['discount_amount'].toString()) ?? 0.0;
        if (discount > 0) {
          CongratulationsOverlay.show(context, discount);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _couponError = 'Could not validate coupon.');
    } finally {
      if (mounted) setState(() => _isValidatingCoupon = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _couponResult = null;
      _couponError = null;
      _couponCtrl.clear();
    });
  }

  Future<void> _placeOrder(CartProvider cart) async {
    if (_selectedAddress == null || _selectedAddress?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid address.')),
      );
      return;
    }

    setState(() => _isCreatingOrder = true);

    try {
      final items = cart.items
          .map(
            (item) => {
              'product_id': item.product.id,
              'quantity': item.quantity,
            },
          )
          .toList();

      final appliedCode = (_couponResult?['valid'] == true)
          ? (_couponResult!['coupon']['code'] as String)
          : '';

      final List<String> customDetails = [];
      for (final item in cart.items) {
        final List<String> specs = [];
        if (item.size != null) specs.add("Size: ${item.size}");
        if (item.spiceLevel != null) specs.add("Spice: ${item.spiceLevel}");
        if (item.customizations.isNotEmpty) {
          specs.add("Extras: ${item.customizations.join(', ')}");
        }
        if (item.notes != null && item.notes!.isNotEmpty) {
          specs.add("Note: ${item.notes}");
        }
        if (specs.isNotEmpty) {
          customDetails.add(
            "${item.product.name} (${item.quantity}x) -> ${specs.join(', ')}",
          );
        }
      }

      final List<String> notesParts = [];
      if (customDetails.isNotEmpty) {
        notesParts.add(customDetails.join(' | '));
      }
      notesParts.add(
        _cutleryNeeded ? "Cutlery Needed: Yes" : "Cutlery Needed: No",
      );
      final String finalDeliveryNotes = notesParts.join(' | ');

      final order = await _orderRepository.createOrder(
        addressId: _selectedAddress!.id!,
        items: items,
        paymentMethod: _selectedPaymentMethod,
        couponCode: appliedCode,
        deliveryNotes: finalDeliveryNotes,
        redeemCoins: _redeemCoins,
      );

      cart.clearCart();

      if (mounted) {
        AppRoutes.pushReplacementWaitingRoom(
          context,
          orderId: order.id,
          orderNumber: order.orderNumber,
          paymentMethod: _selectedPaymentMethod,
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('closed') || errorMsg.contains('kitchen')) {
          AppRoutes.pushReplacementKitchenClosed(
            context,
            closedMessage: e
                .toString()
                .replaceAll('Exception: ', '')
                .replaceAll('Error: ', ''),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error placing order: $e')));
        }
      }
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }
  }

  Widget _paymentTile({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: _isCreatingOrder
          ? null
          : () => setState(() => _selectedPaymentMethod = value),
      child: Container(
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
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
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
    final cart = context.watch<CartProvider>();
    final cartTotal = cart.totalAmount;
    final discount = _couponResult?['valid'] == true
        ? double.tryParse(_couponResult!['discount_amount'].toString()) ?? 0.0
        : 0.0;
    final coinsDiscount = _redeemCoins
        ? _calculateCoinsDiscount(cartTotal - discount)
        : 0.0;
    final finalTotal = cartTotal - discount - coinsDiscount;

    if (cart.items.isEmpty && !_isCreatingOrder) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(
          child: Text('Cart is empty', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingAddresses
          ? const Center(child: HdkPreloader())
          : _addressError != null
          ? Center(
              child: Text(
                _addressError!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Delivery address ──────────────────────────────────
                  const Text(
                    'Delivery Address',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _selectedAddress == null
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _panel,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'No address selected',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              TextButton(
                                onPressed: _pickAddress,
                                child: const Text(
                                  'Add Address',
                                  style: TextStyle(color: _brandRed),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _panel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _stroke),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on, color: _brandRed),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedAddress!.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_selectedAddress!.house}, ${_selectedAddress!.street}, ${_selectedAddress!.city}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _pickAddress,
                                child: const Text(
                                  'Change',
                                  style: TextStyle(color: _brandRed),
                                ),
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 24),

                  // ── Order summary ─────────────────────────────────────
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _stroke),
                    ),
                    child: Column(
                      children: [
                        ...cart.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity}x ${item.product.name}',
                                    style: const TextStyle(color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '₹${(item.product.price * item.quantity).toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(color: _stroke, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Subtotal',
                              style: TextStyle(color: _mutedText),
                            ),
                            Text(
                              '₹${cartTotal.toStringAsFixed(0)}',
                              style: const TextStyle(color: _mutedText),
                            ),
                          ],
                        ),
                        if (discount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Discount (${_couponResult!['coupon']['code']})',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '-₹${discount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (coinsDiscount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Coins Redeemed',
                                style: TextStyle(
                                  color: Color(0xFFFF8A00),
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '-₹${coinsDiscount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Color(0xFFFF8A00),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '₹${finalTotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Coupon ────────────────────────────────────────────
                  const Text(
                    'Promo Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_couponResult?['valid'] == true)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.greenAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer_rounded,
                            color: Colors.greenAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _couponResult!['coupon']['code'],
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'You save ₹${discount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _removeCoupon,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.greenAccent,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _couponCtrl,
                            style: const TextStyle(color: Colors.white),
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Enter promo code',
                              hintStyle: const TextStyle(color: _mutedText),
                              filled: true,
                              fillColor: _panel,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _stroke),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _stroke),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _brandRed),
                              ),
                              errorText: _couponError,
                              errorStyle: const TextStyle(
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 82,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isValidatingCoupon
                                ? null
                                : () => _validateCoupon(cartTotal),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandRed,
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isValidatingCoupon
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Apply',
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  // ── Redeem Loyalty Coins ──────────────────────────────
                  if (_userCoins > 0) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _redeemCoins
                              ? const Color(0xFFFF8A00).withValues(alpha: 0.4)
                              : _stroke,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            color: Color(0xFFFF8A00),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Redeem $_userCoins HDK Coins',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Save ₹${_calculateCoinsDiscount(cartTotal - discount).toStringAsFixed(0)} on this order',
                                  style: const TextStyle(
                                    color: _mutedText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _redeemCoins,
                            activeThumbColor: const Color(0xFFFF8A00),
                            activeTrackColor: const Color(
                              0xFFFF8A00,
                            ).withValues(alpha: 0.2),
                            inactiveTrackColor: const Color(0xFF2A2A2A),
                            onChanged: (val) {
                              setState(() => _redeemCoins = val);
                              if (val) {
                                final coinsDiscount = _calculateCoinsDiscount(
                                  cartTotal - discount,
                                );
                                if (coinsDiscount > 0) {
                                  CongratulationsOverlay.show(
                                    context,
                                    coinsDiscount,
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Cutlery Option ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _stroke),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.flatware_rounded,
                          color: _brandRed,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cutlery Needed',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Ticked if you need spoons/forks/napkins',
                                style: TextStyle(
                                  color: _mutedText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: _cutleryNeeded,
                          activeColor: _brandRed,
                          checkColor: Colors.white,
                          onChanged: (val) {
                            setState(() => _cutleryNeeded = val ?? true);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Payment mode ──────────────────────────────────────
                  const Text(
                    'Payment Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _paymentTile(
                    value: 'online',
                    icon: Icons.account_balance_wallet,
                    title: 'Pay Online',
                    subtitle: 'UPI, cards, netbanking via Cashfree',
                  ),
                  const SizedBox(height: 12),
                  _paymentTile(
                    value: 'cod',
                    icon: Icons.money,
                    title: 'Cash on Delivery',
                    subtitle: 'Pay when your order arrives',
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomNavigationBar: _isCreatingOrder
          ? const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  heightFactor: 1,
                  child: HdkPreloader(width: 50, height: 50),
                ),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: cart.items.isEmpty || _selectedAddress == null
                        ? null
                        : () => _placeOrder(cart),
                    child: Text(
                      'Place Order  ₹${finalTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
