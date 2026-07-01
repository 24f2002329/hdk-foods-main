import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../checkout/presentation/screens/kitchen_closed_screen.dart';
import '../../../home/data/repositories/config_service.dart';
import '../../../home/data/repositories/product_service.dart';
import '../../data/models/cart_item.dart';
import '../providers/cart_provider.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _panelAlt = Color(0xFF1E1E1E);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<Product>> _addOnsFuture;
  late Future<SiteConfig> _configFuture;

  @override
  void initState() {
    super.initState();
    _addOnsFuture = ProductService.getAddOns();
    _configFuture = ConfigService().getConfig();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const bottomNavigationClearance = 16.0;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          "Your Cart",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: context.watch<CartProvider>().items.isEmpty
                ? null
                : () => context.read<CartProvider>().clearCart(),
            child: const Text(
              "Clear",
              style: TextStyle(color: _brandRed, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: FutureBuilder<SiteConfig>(
        future: _configFuture,
        builder: (context, configSnapshot) {
          final config = configSnapshot.data;
          final isClosed = config != null && !config.isCurrentlyOpen;

          return Consumer<CartProvider>(
            builder: (context, cart, _) {
              if (cart.items.isEmpty) {
                return const Center(
                  child: Text(
                    "Your cart is empty",
                    style: TextStyle(
                      color: _mutedText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  if (isClosed)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _brandRed.withValues(alpha: 0.1),
                        border: const Border(bottom: BorderSide(color: _brandRed, width: 1.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: _brandRed, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              config.storeClosedMsg.isNotEmpty
                                  ? config.storeClosedMsg
                                  : "We are currently closed.",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        ...cart.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CartItemTile(item: item),
                          ),
                        ),
                        _AddOnsSection(addOnsFuture: _addOnsFuture),
                      ],
                    ),
                  ),
                  _CartSummary(
                    total: cart.totalAmount,
                    bottomPadding: 16 + bottomInset + bottomNavigationClearance,
                    isClosed: isClosed,
                    closedMessage: config?.storeClosedMsg ?? "",
                    openTime: config?.formattedOpenTime,
                    closeTime: config?.formattedCloseTime,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E1E)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.product.image.isEmpty
                  ? const _CartImageFallback()
                  : Image.network(
                      item.product.image,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const _CartImageFallback();
                      },
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.size != null || item.spiceLevel != null || item.customizations.isNotEmpty || (item.notes != null && item.notes!.isNotEmpty)) ...[
                    Text(
                      [
                        if (item.size != null) "Size: ${item.size}",
                        if (item.spiceLevel != null) "Spice: ${item.spiceLevel}",
                        if (item.customizations.isNotEmpty) "Add-ons: ${item.customizations.join(', ')}",
                        if (item.notes != null && item.notes!.isNotEmpty) "Note: ${item.notes}",
                      ].join(' | '),
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "₹${(item.unitPrice * item.quantity).toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFF262626)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => context
                                  .read<CartProvider>()
                                  .decreaseQuantityForCartId(item.cartId),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1F1F1F),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.remove_rounded, color: _brandRed, size: 14),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              item.quantity.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => context
                                  .read<CartProvider>()
                                  .increaseQuantityForCartId(item.cartId),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1F1F1F),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add_rounded, color: _brandRed, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => context
                  .read<CartProvider>()
                  .removeProductByCartId(item.cartId),
              color: const Color(0xFF444444),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Add something to your order?" — admin-controlled add-on items as checkboxes.
class _AddOnsSection extends StatelessWidget {
  final Future<List<Product>> addOnsFuture;
  const _AddOnsSection({required this.addOnsFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: addOnsFuture,
      builder: (context, snapshot) {
        final addOns = snapshot.data ?? [];
        if (addOns.isEmpty) return const SizedBox.shrink();

        final cart = context.watch<CartProvider>();

        return Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.local_drink_rounded, color: _brandRed, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Add to your order',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Pair your meal with a drink or extra',
                style: TextStyle(color: _mutedText, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ...addOns.map((addon) {
                final inCart = cart.contains(addon);
                return _AddOnTile(
                  product: addon,
                  selected: inCart,
                  onChanged: (checked) {
                    final provider = context.read<CartProvider>();
                    if (checked) {
                      provider.addProduct(addon);
                    } else {
                      provider.removeProduct(addon);
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _AddOnTile extends StatelessWidget {
  final Product product;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _AddOnTile({
    required this.product,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: product.image.isEmpty
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: ColoredBox(
                        color: _panelAlt,
                        child: Icon(Icons.local_drink_rounded,
                            color: _brandRed, size: 20),
                      ),
                    )
                  : Image.network(
                      product.image,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => const SizedBox(
                        width: 40,
                        height: 40,
                        child: ColoredBox(
                          color: _panelAlt,
                          child: Icon(Icons.local_drink_rounded,
                              color: _brandRed, size: 20),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹${product.price.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Checkbox(
              value: selected,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: _brandRed,
              side: const BorderSide(color: _mutedText),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final double total;
  final double bottomPadding;
  final bool isClosed;
  final String closedMessage;
  final String? openTime;
  final String? closeTime;

  const _CartSummary({
    required this.total,
    required this.bottomPadding,
    this.isClosed = false,
    this.closedMessage = "",
    this.openTime,
    this.closeTime,
  });

  Widget _buildBillRow(String label, String value, {bool isFree = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: _mutedText, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: isFree ? Colors.greenAccent : Colors.white,
            fontSize: 13,
            fontWeight: isFree ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(top: BorderSide(color: Color(0xFF1E1E1E))),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 16,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Detailed Bill Breakdown
          const Text(
            "Bill Details",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildBillRow("Item Total", "₹${total.toStringAsFixed(0)}"),
          const SizedBox(height: 8),
          _buildBillRow("Delivery Fee", "FREE", isFree: true),
          const SizedBox(height: 8),
          _buildBillRow("Taxes & Charges", "₹0"),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF222222), thickness: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Grand Total",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "₹${total.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isClosed ? const Color(0xFF222222) : _brandRed,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF222222),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            onPressed: isClosed
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KitchenClosedScreen(
                          closedMessage: closedMessage,
                          openTime: openTime,
                          closeTime: closeTime,
                        ),
                      ),
                    );
                  }
                : () async {
                    final loggedIn = await TokenStorage.isLoggedIn();
                    if (!context.mounted) return;
                    if (loggedIn) {
                      Navigator.pushNamed(context, '/checkout');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
            child: Text(
              isClosed ? "Kitchen is Closed" : "Proceed to Checkout",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: isClosed ? Colors.grey[600] : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartImageFallback extends StatelessWidget {
  const _CartImageFallback();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 80,
      height: 80,
      child: ColoredBox(
        color: _panelAlt,
        child: Icon(Icons.restaurant_rounded, color: _brandRed, size: 28),
      ),
    );
  }
}
