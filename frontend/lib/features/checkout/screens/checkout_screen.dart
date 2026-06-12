import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../address/models/customer_address.dart';
import '../../address/services/address_service.dart';
import '../../cart/services/cart_provider.dart';
import '../../orders/services/order_service.dart';
import 'waiting_room_screen.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final AddressService _addressService = AddressService();
  final OrderService _orderService = OrderService();
  
  CustomerAddress? _selectedAddress;
  bool _isLoadingAddresses = true;
  bool _isCreatingOrder = false;
  String? _addressError;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
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

  Future<void> _placeOrder(CartProvider cart) async {
    if (_selectedAddress == null || _selectedAddress?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid address.')),
      );
      return;
    }

    setState(() {
      _isCreatingOrder = true;
    });

    try {
      final items = cart.items.map((item) => {
        'product_id': item.product.id,
        'quantity': item.quantity,
      }).toList();

      final order = await _orderService.createOrder(
        addressId: _selectedAddress!.id!,
        items: items,
      );

      cart.clearCart();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WaitingRoomScreen(
              orderId: order.id,
              orderNumber: order.orderNumber,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error placing order: \$e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingOrder = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    
    if (cart.items.isEmpty && !_isCreatingOrder) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(title: const Text("Checkout")),
        body: const Center(child: Text("Cart is empty", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingAddresses 
        ? const Center(child: CircularProgressIndicator(color: _brandRed))
        : _addressError != null
            ? Center(child: Text(_addressError!, style: const TextStyle(color: Colors.red)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Address',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedAddress == null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Expanded(child: Text('No address selected', style: TextStyle(color: Colors.white))),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/addresses').then((_) => _loadAddresses());
                              },
                              child: const Text('Add Address', style: TextStyle(color: _brandRed)),
                            )
                          ],
                        ),
                      )
                    else
                      Container(
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
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_selectedAddress!.house}, ${_selectedAddress!.street}, ${_selectedAddress!.city}",
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/addresses').then((_) => _loadAddresses());
                              },
                              child: const Text('Change', style: TextStyle(color: _brandRed)),
                            )
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'Order Summary',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                          ...cart.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "${item.quantity}x ${item.product.name}",
                                    style: const TextStyle(color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text("₹${(item.product.price * item.quantity).toStringAsFixed(0)}", style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          )),
                          const Divider(color: _stroke, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("₹${cart.totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      bottomNavigationBar: _isCreatingOrder
          ? const SafeArea(child: Padding(padding: EdgeInsets.all(16.0), child: Center(heightFactor: 1, child: CircularProgressIndicator(color: _brandRed))))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandRed,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: cart.items.isEmpty || _selectedAddress == null ? null : () => _placeOrder(cart),
                  child: const Text('Place Order', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
    );
  }
}
