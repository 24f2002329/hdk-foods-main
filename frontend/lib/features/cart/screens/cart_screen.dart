import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/token_storage.dart';
import '../../../shared/models/product.dart';
import '../../auth/screens/login_screen.dart';
import '../../home/services/product_service.dart';
import '../models/cart_item.dart';
import '../services/cart_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _addOnsFuture = ProductService.getAddOns();
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
      body: Consumer<CartProvider>(
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
              ),
            ],
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
        color: _panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.product.image.isEmpty
                  ? const _CartImageFallback()
                  : Image.network(
                      item.product.image,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const _CartImageFallback();
                      },
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${item.product.price.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context
                            .read<CartProvider>()
                            .decreaseQuantity(item.product),
                        color: _brandRed,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        item.quantity.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () => context
                            .read<CartProvider>()
                            .increaseQuantity(item.product),
                        color: _brandRed,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => context
                            .read<CartProvider>()
                            .removeProduct(item.product),
                        color: _mutedText,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
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

  const _CartSummary({required this.total, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      decoration: BoxDecoration(
        color: _panel,
        border: const Border(top: BorderSide(color: _stroke)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total",
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
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
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
            child: const Text(
              "Proceed to Checkout",
              style: TextStyle(fontWeight: FontWeight.w900),
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
      width: 72,
      height: 72,
      child: ColoredBox(
        color: _panelAlt,
        child: Icon(Icons.restaurant_rounded, color: _brandRed),
      ),
    );
  }
}
