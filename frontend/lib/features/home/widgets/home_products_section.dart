import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/product.dart';
import '../../../shared/widgets/product_card.dart';
import '../services/product_service.dart';
import '../../cart/services/cart_provider.dart';

class HomeProductsSection extends StatefulWidget {
  const HomeProductsSection({super.key});

  @override
  State<HomeProductsSection> createState() => _HomeProductsSectionState();
}

class _HomeProductsSectionState extends State<HomeProductsSection> {
  late Future<List<Product>> products;

  @override
  void initState() {
    super.initState();

    products = ProductService.getProducts();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: products,

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Text("Failed to load products");
        }

        final products = snapshot.data ?? [];
        final cart = context.watch<CartProvider>();

        return SizedBox(
          height: 320,

          child: ListView.builder(
            scrollDirection: Axis.horizontal,

            itemCount: products.length,

            itemBuilder: (context, index) {
              final product = products[index];

              return SizedBox(
                width: 240,

                child: ProductCard(
                  product: product,
                  quantity: cart.quantityFor(product),
                  onAddPressed: () {
                    context.read<CartProvider>().addProduct(product);
                  },
                  onIncreasePressed: () {
                    context.read<CartProvider>().increaseQuantity(product);
                  },
                  onDecreasePressed: () {
                    context.read<CartProvider>().decreaseQuantity(product);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
