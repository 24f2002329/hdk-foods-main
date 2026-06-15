import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/product_row.dart';
import '../../cart/services/cart_provider.dart';
import '../../home/services/product_service.dart';

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
  int? _selectedCategoryId;

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

    // Default the rail selection to the first category.
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Menu',
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
                  slivers.addAll(_browseSlivers(data, cart, bottomInset));
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

  // ── Browse: horizontal category rail + products of selected category ────────
  List<Widget> _browseSlivers(
    _MenuData data,
    CartProvider cart,
    double bottomInset,
  ) {
    // Keep selection valid if categories changed.
    final hasSelection =
        data.categories.any((c) => c.id == _selectedCategoryId);
    final selectedId =
        hasSelection ? _selectedCategoryId : data.categories.first.id;

    final products = data.productsByCategory[selectedId] ?? [];

    return [
      SliverToBoxAdapter(
        child: _CategoryRail(
          categories: data.categories,
          selectedId: selectedId,
          countFor: (id) => (data.productsByCategory[id] ?? []).length,
          onSelected: (id) => setState(() => _selectedCategoryId = id),
        ),
      ),
      if (products.isEmpty)
        const _MessageSliver(message: 'No items in this category yet')
      else
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 96 + bottomInset),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = products[index];
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
              childCount: products.length,
            ),
          ),
        ),
    ];
  }

  // ── Search: dishes first, then categories ───────────────────────────────────
  List<Widget> _searchSlivers(
    _MenuData data,
    CartProvider cart,
    double bottomInset,
  ) {
    final query = _query.trim().toLowerCase();

    final matchedProducts = data.products
        .where((p) =>
            p.name.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query))
        .toList();

    final matchedCategories = data.categories
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();

    if (matchedCategories.isEmpty && matchedProducts.isEmpty) {
      return [_MessageSliver(message: 'No results for "${_query.trim()}"')];
    }

    final slivers = <Widget>[];
    final hasCategories = matchedCategories.isNotEmpty;

    // Dishes first.
    if (matchedProducts.isNotEmpty) {
      slivers.add(const _SectionHeaderSliver(title: 'Dishes'));
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            hasCategories ? 4 : 96 + bottomInset,
          ),
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

    // Then categories — tapping jumps to that category in browse mode.
    if (hasCategories) {
      slivers.add(const _SectionHeaderSliver(title: 'Categories'));
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 96 + bottomInset),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final category = matchedCategories[index];
                final count =
                    (data.productsByCategory[category.id] ?? []).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CategoryResultTile(
                    category: category,
                    itemCount: count,
                    onTap: () => setState(() {
                      _selectedCategoryId = category.id;
                      _searchController.clear();
                      _query = '';
                    }),
                  ),
                );
              },
              childCount: matchedCategories.length,
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

// ── Horizontal category rail ──────────────────────────────────────────────────
class _CategoryRail extends StatelessWidget {
  final List<Category> categories;
  final int? selectedId;
  final int Function(int id) countFor;
  final ValueChanged<int> onSelected;

  const _CategoryRail({
    required this.categories,
    required this.selectedId,
    required this.countFor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        itemCount: categories.length,
        separatorBuilder: (_, i) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category.id == selectedId;
          return GestureDetector(
            onTap: () => onSelected(category.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _brandRed : _panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? _brandRed : _stroke,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    category.name,
                    style: TextStyle(
                      color: selected ? Colors.white : _deepText,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${countFor(category.id)}',
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : _mutedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryResultTile extends StatelessWidget {
  final Category category;
  final int itemCount;
  final VoidCallback onTap;

  const _CategoryResultTile({
    required this.category,
    required this.itemCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _stroke),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _brandRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.category_rounded, color: _brandRed),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    color: _deepText,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '$itemCount item${itemCount == 1 ? '' : 's'}',
                style: const TextStyle(color: _mutedText, fontSize: 12),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: _mutedText),
            ],
          ),
        ),
      ),
    );
  }
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
