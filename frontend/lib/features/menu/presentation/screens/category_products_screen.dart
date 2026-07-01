import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../../../shared/widgets/product_row.dart';
import '../../../cart/presentation/providers/cart_provider.dart';

const _mutedText = Color(0xFFB8B8B8);
const _surface = Color(0xFF050505);

class CategoryProductsScreen extends StatelessWidget {
  final Category category;
  final List<Product> products;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: products.isEmpty
            ? const Center(
                child: Text(
                  'No items in this category yet',
                  style: TextStyle(
                    color: _mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
                itemCount: products.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final quantity = cart.quantityFor(product);

                  return ProductRow(
                    product: product,
                    quantity: quantity,
                    onAddPressed: () =>
                        context.read<CartProvider>().addProduct(product),
                    onIncreasePressed: () =>
                        context.read<CartProvider>().increaseQuantity(product),
                    onDecreasePressed: () =>
                        context.read<CartProvider>().decreaseQuantity(product),
                  );
                },
              ),
      ),
    );
  }
}
