import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/token_storage.dart';
import '../../auth/screens/login_screen.dart';
import '../services/cart_provider.dart';

const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _panelAlt = Color(0xFF1E1E1E);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFFB8B8B8);

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: cart.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];

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
                                      errorBuilder:
                                          (context, error, stackTrace) {
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
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
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
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
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
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + bottomInset + bottomNavigationClearance,
                ),
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
                          "₹${cart.totalAmount.toStringAsFixed(0)}",
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
              ),
            ],
          );
        },
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
