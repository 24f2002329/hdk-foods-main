import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/category_grid_card.dart';
import '../../../shared/widgets/product_row.dart';
import '../../cart/services/cart_provider.dart';
import '../../home/services/product_service.dart';
import 'category_products_screen.dart';

const _brandRed = Color(0xFFFF1E1E);
const _deepText = Colors.white;
const _mutedText = Color(0xFFB8B8B8);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late Future<_MenuData> dataFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    dataFuture = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_MenuData> _load() async {
    final results = await Future.wait([
      ProductService.getCategories(),
      ProductService.getProducts(),
    ]);

    final categories = results[0] as List<Category>;
    final products = results[1] as List<Product>;

    final Map<int, List<Product>> productsByCategory = {};
    for (final product in products) {
      final categoryId = product.categoryId;
      if (categoryId != null) {
        productsByCategory.putIfAbsent(categoryId, () => []).add(product);
      }
    }

    return _MenuData(
      categories: categories,
      products: products,
      productsByCategory: productsByCategory,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      dataFuture = future;
    });
    await future;
  }

  void _openCategory(Category category, List<Product> products) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          category: category,
          products: products,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _brandRed,
          backgroundColor: _panel,
          onRefresh: _refresh,
          child: FutureBuilder<_MenuData>(
            future: dataFuture,
            builder: (context, snapshot) {
              final slivers = <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: _SearchBar(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      onClear: () => setState(() {
                        _searchController.clear();
                        _query = '';
                      }),
                    ),
                  ),
                ),
              ];

              if (snapshot.connectionState == ConnectionState.waiting) {
                slivers.add(const _LoadingSliver());
              } else if (snapshot.hasError) {
                slivers.add(
                  _MessageSliver(message: snapshot.error.toString()),
                );
              } else {
                final data = snapshot.data;
                if (data == null || data.categories.isEmpty) {
                  slivers.add(
                    const _MessageSliver(message: 'No categories available'),
                  );
                } else if (_query.trim().isEmpty) {
                  slivers.add(_categoryGridSliver(
                    data.categories,
                    data,
                    bottomPadding: 96 + bottomInset,
                  ));
                } else {
                  slivers.addAll(_searchSlivers(data, cart, bottomInset));
                }
              }

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: slivers,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _categoryGridSliver(
    List<Category> categories,
    _MenuData data, {
    double bottomPadding = 96,
  }) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = categories[index];
            final categoryProducts =
                data.productsByCategory[category.id] ?? [];

            return CategoryGridCard(
              category: category,
              itemCount: categoryProducts.length,
              onTap: () => _openCategory(category, categoryProducts),
            );
          },
          childCount: categories.length,
        ),
      ),
    );
  }

  List<Widget> _searchSlivers(
    _MenuData data,
    CartProvider cart,
    double bottomInset,
  ) {
    final query = _query.trim().toLowerCase();

    final matchedCategories = data.categories
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();

    final matchedProducts = data.products
        .where((p) =>
            p.name.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query))
        .toList();

    if (matchedCategories.isEmpty && matchedProducts.isEmpty) {
      return [_MessageSliver(message: 'No results for "${_query.trim()}"')];
    }

    final slivers = <Widget>[];
    final hasDishes = matchedProducts.isNotEmpty;

    if (matchedCategories.isNotEmpty) {
      slivers.add(const _SectionHeaderSliver(title: 'Categories'));
      slivers.add(_categoryGridSliver(
        matchedCategories,
        data,
        bottomPadding: hasDishes ? 4 : 96 + bottomInset,
      ));
    }

    if (hasDishes) {
      slivers.add(const _SectionHeaderSliver(title: 'Dishes'));
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 96 + bottomInset),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = matchedProducts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ProductRow(
                    product: product,
                    quantity: cart.quantityFor(product),
                    onAddPressed: () =>
                        context.read<CartProvider>().addProduct(product),
                    onIncreasePressed: () =>
                        context.read<CartProvider>().increaseQuantity(product),
                    onDecreasePressed: () =>
                        context.read<CartProvider>().decreaseQuantity(product),
                  ),
                );
              },
              childCount: matchedProducts.length,
            ),
          ),
        ),
      );
    }

    return slivers;
  }
}

class _MenuData {
  final List<Category> categories;
  final List<Product> products;
  final Map<int, List<Product>> productsByCategory;

  _MenuData({
    required this.categories,
    required this.products,
    required this.productsByCategory,
  });
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: _deepText, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search dishes, drinks, desserts',
              hintStyle: const TextStyle(
                color: _mutedText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(Icons.search, color: _mutedText),
              suffixIcon: hasText
                  ? IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, color: _mutedText),
                    )
                  : null,
              filled: true,
              fillColor: _panel,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _brandRed),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeaderSliver extends StatelessWidget {
  final String title;

  const _SectionHeaderSliver({required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
        child: Text(
          title,
          style: const TextStyle(
            color: _deepText,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _LoadingSliver extends StatelessWidget {
  const _LoadingSliver();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: _brandRed)),
      ),
    );
  }
}

class _MessageSliver extends StatelessWidget {
  final String message;

  const _MessageSliver({required this.message});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
