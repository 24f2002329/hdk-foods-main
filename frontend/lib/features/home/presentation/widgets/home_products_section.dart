import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hdk_core/hdk_core.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../data/repositories/product_service.dart';
import '../../../cart/presentation/providers/cart_provider.dart';

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
          return const _ProductSectionSkeleton();
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

class _ProductSectionSkeleton extends StatelessWidget {
  const _ProductSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF111111),
      highlightColor: const Color(0xFF2A2A2A),
      child: SizedBox(
        height: 320,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Container(
              width: 240,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          },
        ),
      ),
    );
  }
}
