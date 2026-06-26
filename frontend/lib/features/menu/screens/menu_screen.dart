import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../../cart/services/cart_provider.dart';
import '../../home/services/product_service.dart';
import '../../home/services/config_service.dart';
import '../../cart/screens/cart_screen.dart';

// Brand colors
const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF0D0D0D);
const _panel = Color(0xFF161616);
const _panelLight = Color(0xFF222222);
const _stroke = Color(0xFF2A2A2A);
const _textPrimary = Colors.white;
const _textSecondary = Color(0xFF9E9E9E);
const _gold = Color(0xFFFFC107);

class MenuScreen extends StatefulWidget {
  final int? initialCategoryId;
  const MenuScreen({super.key, this.initialCategoryId});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late Future<_MenuData> dataFuture;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();

  String _query = '';
  Timer? _debounceTimer;

  int? _selectedCategoryId;
  bool _isAutoScrolling = false;

  // Keys for scrolling to sections
  final Map<int, GlobalKey> _sectionKeys = {};
  // Extra section keys for dynamic sections
  final GlobalKey _bestsellersKey = GlobalKey();
  final GlobalKey _newArrivalsKey = GlobalKey();

  // Dynamic sections configuration
  bool _showBestsellersSection = true;
  bool _showNewArrivalsSection = true;

  // Filter States
  bool _onlyAvailable = false;
  bool _onlyBestsellers = false;
  String _sortOption = 'none'; // 'none', 'price_asc', 'price_desc', 'rating_desc'

  // Bonus Wishlist/Favorites
  Set<int> _favoriteProductIds = {};

  // Bonus Recently Viewed
  final List<int> _recentlyViewedIds = [];

  // Async load addons for recommended bottom sheet
  List<Product> _addonsList = [];

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    dataFuture = _load();
    _loadFavorites();
    _loadAddons();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('hdk_favorites') ?? [];
      if (mounted) {
        setState(() {
          _favoriteProductIds = list.map(int.parse).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite(int productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (_favoriteProductIds.contains(productId)) {
          _favoriteProductIds.remove(productId);
        } else {
          _favoriteProductIds.add(productId);
        }
      });
      await prefs.setStringList(
        'hdk_favorites',
        _favoriteProductIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  Future<void> _loadAddons() async {
    try {
      final addons = await ProductService.getAddOns();
      if (mounted) {
        setState(() {
          _addonsList = addons;
        });
      }
    } catch (_) {}
  }

  Future<_MenuData> _load() async {
    final results = await Future.wait([
      ProductService.getCategories(),
      ProductService.getProducts(),
      ConfigService().getConfig(),
    ]);

    final categories = results[0] as List<Category>;
    final products = results[1] as List<Product>;
    final config = results[2] as SiteConfig;

    final Map<int, List<Product>> productsByCategory = {};
    for (final product in products) {
      final categoryId = product.categoryId;
      if (categoryId != null) {
        productsByCategory.putIfAbsent(categoryId, () => []).add(product);
      }
    }

    // Default selection
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = -1; // -1 represents '🔥 Bestsellers' tab by default
    }

    return _MenuData(
      categories: categories,
      products: products,
      productsByCategory: productsByCategory,
      config: config,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      dataFuture = future;
    });
    await future;
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _query = value;
        });
      }
    });
  }

  void _onScroll() {
    if (_isAutoScrolling || !mounted) return;

    // Determine current visible section
    try {
      // 1. Check Dynamic Bestsellers Section
      if (_showBestsellersSection && _bestsellersKey.currentContext != null) {
        final box = _bestsellersKey.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          if (position.dy >= 0 && position.dy < 240) {
            _updateSelectedCategoryTab(-1);
            return;
          }
        }
      }

      // 2. Check Dynamic New Arrivals Section
      if (_showNewArrivalsSection && _newArrivalsKey.currentContext != null) {
        final box = _newArrivalsKey.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          if (position.dy >= 0 && position.dy < 240) {
            _updateSelectedCategoryTab(-2);
            return;
          }
        }
      }

      // 3. Check Dynamic Category Sections
      for (final entry in _sectionKeys.entries) {
        final key = entry.value;
        if (key.currentContext != null) {
          final box = key.currentContext!.findRenderObject() as RenderBox?;
          if (box != null) {
            final position = box.localToGlobal(Offset.zero);
            if (position.dy >= 0 && position.dy < 240) {
              _updateSelectedCategoryTab(entry.key);
              break;
            }
          }
        }
      }
    } catch (_) {}
  }

  void _updateSelectedCategoryTab(int categoryId) {
    if (_selectedCategoryId != categoryId) {
      setState(() {
        _selectedCategoryId = categoryId;
      });
      _scrollToCategoryChip(categoryId);
    }
  }

  void _scrollToCategoryChip(int categoryId) {
    if (!_categoryScrollController.hasClients) return;
    // Calculate approximate position. Since we don't know the dynamic width of chips,
    // we can estimate based on a standard spacing.
    // -1 is Bestsellers, -2 is New Arrivals, and positive values are category IDs.
    int index = 0;
    if (categoryId == -1) {
      index = 0;
    } else if (categoryId == -2) {
      index = _showBestsellersSection ? 1 : 0;
    } else {
      // Find index in category list
      dataFuture.then((data) {
        final catIndex = data.categories.indexWhere((c) => c.id == categoryId);
        if (catIndex != -1) {
          int offset = (_showBestsellersSection ? 1 : 0) + (_showNewArrivalsSection ? 1 : 0);
          final targetIndex = catIndex + offset;
          final double targetOffset = targetIndex * 100.0 - 100.0;
          _categoryScrollController.animateTo(
            targetOffset.clamp(0.0, _categoryScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
      return;
    }

    final double targetOffset = index * 100.0 - 100.0;
    _categoryScrollController.animateTo(
      targetOffset.clamp(0.0, _categoryScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToSection(int categoryId) {
    GlobalKey? targetKey;
    if (categoryId == -1) {
      targetKey = _bestsellersKey;
    } else if (categoryId == -2) {
      targetKey = _newArrivalsKey;
    } else {
      targetKey = _sectionKeys[categoryId];
    }

    if (targetKey != null && targetKey.currentContext != null) {
      setState(() {
        _selectedCategoryId = categoryId;
      });
      _isAutoScrolling = true;
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ).then((_) {
        _isAutoScrolling = false;
      });
    }
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => onTap(),
                selectedColor: _brandRed,
                backgroundColor: _panelLight,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : _textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? _brandRed : _stroke,
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters & Sort',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _onlyAvailable = false;
                            _onlyBestsellers = false;
                            _sortOption = 'none';
                          });
                          setState(() {});
                        },
                        child: const Text(
                          'Clear All',
                          style: TextStyle(color: _brandRed, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: _stroke, height: 24),
                  const SizedBox(height: 20),
                  const Text(
                    'Filter Options',
                    style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildFilterChip('🔥 Bestsellers', _onlyBestsellers, () {
                        setModalState(() => _onlyBestsellers = !_onlyBestsellers);
                        setState(() {});
                      }),
                      buildFilterChip('✅ Available Only', _onlyAvailable, () {
                        setModalState(() => _onlyAvailable = !_onlyAvailable);
                        setState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sort By Price & Rating',
                    style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildFilterChip('Price: Low → High', _sortOption == 'price_asc', () {
                        setModalState(() => _sortOption = _sortOption == 'price_asc' ? 'none' : 'price_asc');
                        setState(() {});
                      }),
                      buildFilterChip('Price: High → Low', _sortOption == 'price_desc', () {
                        setModalState(() => _sortOption = _sortOption == 'price_desc' ? 'none' : 'price_desc');
                        setState(() {});
                      }),
                      buildFilterChip('Rating ⭐ (High → Low)', _sortOption == 'rating_desc', () {
                        setModalState(() => _sortOption = _sortOption == 'rating_desc' ? 'none' : 'rating_desc');
                        setState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Product> _applyFiltersAndSort(List<Product> source) {
    List<Product> result = List.from(source);

    // Apply Available Only Filter
    if (_onlyAvailable) {
      result = result.where((p) => p.isAvailable).toList();
    }
    // Apply Bestsellers Filter
    if (_onlyBestsellers) {
      result = result.where((p) => p.isFeatured || p.promoTag.toLowerCase().contains('best')).toList();
    }
    // Apply sorting
    if (_sortOption == 'price_asc') {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortOption == 'price_desc') {
      result.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortOption == 'rating_desc') {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return result;
  }

  void _recordRecentlyViewed(int id) {
    if (!_recentlyViewedIds.contains(id)) {
      setState(() {
        _recentlyViewedIds.insert(0, id);
        if (_recentlyViewedIds.length > 5) {
          _recentlyViewedIds.removeLast();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Menu',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
            onPressed: () {
              _searchFocusNode.requestFocus();
            },
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 24),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 250),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: _brandRed,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${cart.itemCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _ShimmerLoader();
              } else if (snapshot.hasError) {
                return _ErrorState(
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                );
              }

              final data = snapshot.data;
              if (data == null || data.categories.isEmpty) {
                return const _EmptyState(message: 'No categories available');
              }

              final siteConfig = data.config;
              final isStoreClosed = !siteConfig.isCurrentlyOpen;

              // Filter dynamic sections
              final bestsellersList = _applyFiltersAndSort(
                data.products.where((p) => p.isFeatured || p.promoTag.toLowerCase().contains('best')).toList(),
              );
              final newArrivalsList = _applyFiltersAndSort(
                data.products.where((p) => p.promoTag.toLowerCase().contains('new') || p.promoTag.toLowerCase().contains('latest')).toList(),
              );

              _showBestsellersSection = bestsellersList.isNotEmpty;
              _showNewArrivalsSection = newArrivalsList.isNotEmpty;

              // Prepare slivers
              final List<Widget> slivers = [];

              // Search Bar & Filter Button
              slivers.add(
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: _panel,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _stroke),
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: _onSearchChanged,
                              style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search dishes, pizzas, boba...',
                                hintStyle: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                ),
                                prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                        },
                                        icon: const Icon(Icons.close_rounded, color: _textSecondary, size: 20),
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _openFilterBottomSheet,
                          child: Container(
                            height: 52,
                            width: 52,
                            decoration: BoxDecoration(
                              color: _panel,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _stroke),
                            ),
                            child: const Icon(Icons.tune_rounded, color: _brandRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              // Quick Filter Tags
              slivers.add(
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      children: [
                        _QuickFilterChip(
                          label: '🔥 Bestsellers',
                          isSelected: _onlyBestsellers,
                          onTap: () {
                            setState(() => _onlyBestsellers = !_onlyBestsellers);
                          },
                        ),
                        const SizedBox(width: 8),
                        _QuickFilterChip(
                          label: '⭐ Top Rated',
                          isSelected: _sortOption == 'rating_desc',
                          onTap: () {
                            setState(() {
                              _sortOption = _sortOption == 'rating_desc' ? 'none' : 'rating_desc';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _QuickFilterChip(
                          label: '⏳ Fast Prep',
                          isSelected: _onlyAvailable, // Maps to showing only active products
                          onTap: () {
                            setState(() => _onlyAvailable = !_onlyAvailable);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );

              // Sticky Categories / Navigation Rail
              slivers.add(
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyCategoryBarDelegate(
                    height: 58,
                    child: Container(
                      color: _surface,
                      alignment: Alignment.centerLeft,
                      child: ListView.separated(
                        controller: _categoryScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        itemCount: (_showBestsellersSection ? 1 : 0) +
                            (_showNewArrivalsSection ? 1 : 0) +
                            data.categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          int actualIndex = index;
                          int catId = 0;
                          String label = "";

                          if (_showBestsellersSection && actualIndex == 0) {
                            catId = -1;
                            label = "🔥 Bestsellers";
                          } else if (_showNewArrivalsSection &&
                              ((_showBestsellersSection && actualIndex == 1) ||
                                  (!_showBestsellersSection && actualIndex == 0))) {
                            catId = -2;
                            label = "🆕 New";
                          } else {
                            int shift = (_showBestsellersSection ? 1 : 0) +
                                (_showNewArrivalsSection ? 1 : 0);
                            final category = data.categories[actualIndex - shift];
                            catId = category.id;
                            label = category.name;
                          }

                          final isSelected = catId == _selectedCategoryId;

                          return GestureDetector(
                            onTap: () => _scrollToSection(catId),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? _brandRed : _panel,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? _brandRed : _stroke,
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : _textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );

              // Announcement if Kitchen Closed
              if (isStoreClosed) {
                slivers.add(
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _brandRed.withValues(alpha: 0.08),
                        border: Border.all(color: _brandRed.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_rounded, color: _brandRed),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kitchen Closed',
                                  style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  siteConfig.storeClosedMsg.isNotEmpty
                                      ? siteConfig.storeClosedMsg
                                      : 'We are currently closed for orders. Opens at ${siteConfig.formattedOpenTime}.',
                                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Recently Viewed Section (Bonus)
              if (_query.isEmpty && _recentlyViewedIds.isNotEmpty) {
                final recentProducts = data.products
                    .where((p) => _recentlyViewedIds.contains(p.id))
                    .toList();
                if (recentProducts.isNotEmpty) {
                  slivers.add(
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Recently Viewed',
                              style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 104,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: recentProducts.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final p = recentProducts[index];
                                return GestureDetector(
                                  onTap: () {
                                    _recordRecentlyViewed(p.id);
                                    _showProductDetails(context, p, cart, siteConfig);
                                  },
                                  child: Container(
                                    width: 240,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _panel,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _stroke),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: p.image,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Shimmer.fromColors(
                                              baseColor: _panel,
                                              highlightColor: _stroke,
                                              child: Container(color: Colors.white),
                                            ),
                                            errorWidget: (_, _, _) => Container(
                                              color: _stroke,
                                              child: const Icon(Icons.restaurant_rounded, color: _textSecondary),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                p.name,
                                                style: const TextStyle(
                                                    color: _textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '₹${p.price.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                    color: _brandRed, fontSize: 13, fontWeight: FontWeight.w800),
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
                        ],
                      ),
                    ),
                  );
                }
              }

              // Rendering Lists
              if (_query.trim().isNotEmpty) {
                // Search Mode
                final queryStr = _query.trim().toLowerCase();
                final searchMatches = _applyFiltersAndSort(
                  data.products
                      .where((p) =>
                          p.name.toLowerCase().contains(queryStr) ||
                          p.description.toLowerCase().contains(queryStr))
                      .toList(),
                );

                if (searchMatches.isEmpty) {
                  slivers.add(
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No dishes found matching "$_query"',
                          style: const TextStyle(color: _textSecondary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                } else {
                  slivers.add(
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = searchMatches[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _PremiumFoodCard(
                                product: product,
                                isFavorite: _favoriteProductIds.contains(product.id),
                                onFavoriteTapped: () => _toggleFavorite(product.id),
                                cartQuantity: cart.quantityFor(product),
                                isStoreClosed: isStoreClosed,
                                onAddPressed: () {
                                  _recordRecentlyViewed(product.id);
                                  _showProductDetails(context, product, cart, siteConfig);
                                },
                                onIncreasePressed: () => cart.increaseQuantity(product),
                                onDecreasePressed: () => cart.decreaseQuantity(product),
                                onTap: () {
                                  _recordRecentlyViewed(product.id);
                                  _showProductDetails(context, product, cart, siteConfig);
                                },
                              ),
                            );
                          },
                          childCount: searchMatches.length,
                        ),
                      ),
                    ),
                  );
                }
              } else {
                // Browse Mode: Vertical Stack of Category Sections
                // 1. Dynamic Section: Bestsellers
                if (_showBestsellersSection) {
                  slivers.add(
                    SliverToBoxAdapter(
                      key: _bestsellersKey,
                      child: const _SectionHeader(title: '🔥 Best Sellers'),
                    ),
                  );
                  slivers.add(
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = bestsellersList[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _PremiumFoodCard(
                                product: product,
                                isFavorite: _favoriteProductIds.contains(product.id),
                                onFavoriteTapped: () => _toggleFavorite(product.id),
                                cartQuantity: cart.quantityFor(product),
                                isStoreClosed: isStoreClosed,
                                onAddPressed: () {
                                  _recordRecentlyViewed(product.id);
                                  _showProductDetails(context, product, cart, siteConfig);
                                },
                                onIncreasePressed: () => cart.increaseQuantity(product),
                                onDecreasePressed: () => cart.decreaseQuantity(product),
                                onTap: () {
                                  _recordRecentlyViewed(product.id);
                                  _showProductDetails(context, product, cart, siteConfig);
                                },
                              ),
                            );
                          },
                          childCount: bestsellersList.length,
                        ),
                      ),
                    ),
                  );
                }

                // 2. Dynamic Section: New Arrivals
                if (_showNewArrivalsSection) {
                  slivers.add(
                    SliverToBoxAdapter(
                      key: _newArrivalsKey,
                      child: const _SectionHeader(title: '🆕 New Arrivals'),
                    ),
                  );
                  slivers.add(
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = newArrivalsList[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _PremiumFoodCard(
                                product: product,
                                isFavorite: _favoriteProductIds.contains(product.id),
                                onFavoriteTapped: () => _toggleFavorite(product.id),
                                cartQuantity: cart.quantityFor(product),
                                isStoreClosed: isStoreClosed,
                                onAddPressed: () {
                                  _recordRecentlyViewed(product.id);
                                  _showProductDetails(context, product, cart, siteConfig);
                                },
                                onIncreasePressed: () => cart.increaseQuantity(product),
                                onDecreasePressed: () => cart.decreaseQuantity(product),
                                onTap: () {
                                  _recordRecentlyViewed(product.id);
                                  _showProductDetails(context, product, cart, siteConfig);
                                },
                              ),
                            );
                          },
                          childCount: newArrivalsList.length,
                        ),
                      ),
                    ),
                  );
                }

                // 3. Category Lists from backend
                for (final category in data.categories) {
                  final catKey = _sectionKeys.putIfAbsent(category.id, () => GlobalKey());
                  final rawProducts = data.productsByCategory[category.id] ?? [];
                  final products = _applyFiltersAndSort(rawProducts);

                  if (products.isEmpty) continue;

                  slivers.add(
                    SliverToBoxAdapter(
                      key: catKey,
                      child: _SectionHeader(title: category.name),
                    ),
                  );

                  slivers.add(
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = products[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _PremiumFoodCard(
                                product: product,
                                isFavorite: _favoriteProductIds.contains(product.id),
                                onFavoriteTapped: () => _toggleFavorite(product.id),
                                cartQuantity: cart.quantityFor(product),
                                isStoreClosed: isStoreClosed,
                                onAddPressed: () {
                                  _recordRecentlyViewed(product.id);
                                  _showProductDetails(context, product, cart, siteConfig);
                                },
                                onIncreasePressed: () => cart.increaseQuantity(product),
                                onDecreasePressed: () => cart.decreaseQuantity(product),
                                onTap: () {
                                  _recordRecentlyViewed(product.id);
                                  _showProductDetails(context, product, cart, siteConfig);
                                },
                              ),
                            );
                          },
                          childCount: products.length,
                        ),
                      ),
                    ),
                  );
                }

                // Spacer at bottom to avoid overlapping with bottom bar
                slivers.add(
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 120),
                  ),
                );
              }

              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: slivers,
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        offset: cart.itemCount > 0 ? Offset.zero : const Offset(0, 1.5),
        duration: const Duration(milliseconds: 300),
        child: cart.itemCount > 0
            ? Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: _brandRed,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _brandRed.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cart.itemCount} Item${cart.itemCount == 1 ? "" : "s"} added',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${cart.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _brandRed,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (_) => const CartScreen()),
                        );
                      },
                      child: const Row(
                        children: [
                          Text(
                            'View Cart',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  // Phase 6 & 7: Modal details with custom sizes, spice levels, and add-ons
  void _showProductDetails(BuildContext context, Product product, CartProvider cart, SiteConfig config) {
    double basePrice = product.price;

    // Customization variables
    String selectedSize = 'Regular';
    double sizeExtraPrice = 0.0;

    String selectedSpice = 'Medium';

    Map<String, double> possibleAddons = {
      'Extra Cheese': 30.0,
      'Extra Sauce': 15.0,
      'Extra Toppings': 40.0,
    };
    Map<String, bool> selectedAddons = {
      'Extra Cheese': false,
      'Extra Sauce': false,
      'Extra Toppings': false,
    };

    String notes = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double calculateTotalPrice() {
              double total = basePrice + sizeExtraPrice;
              selectedAddons.forEach((name, selected) {
                if (selected) {
                  total += (possibleAddons[name] ?? 0.0);
                }
              });
              return total;
            }

            final totalPrice = calculateTotalPrice();

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Pull Handle
                    const SizedBox(height: 12),
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _stroke,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Scrollable Body
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // Large Image with Hero Animation
                          Hero(
                            tag: 'product_img_${product.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CachedNetworkImage(
                                imageUrl: product.image,
                                height: 240,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Container(
                                  color: _stroke,
                                  child: const Icon(Icons.restaurant_rounded, size: 64, color: _textSecondary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Badges & Indicators
                          Row(
                            children: [
                              if (product.isFeatured) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _gold.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.star_rounded, color: _gold, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Today\'s Special',
                                        style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (product.promoTag.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _brandRed.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    product.promoTag,
                                    style: const TextStyle(color: _brandRed, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Product Name
                          Text(
                            product.name,
                            style: const TextStyle(color: _textPrimary, fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),

                          // Preparation & Rating Info
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: _gold, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                product.rating > 0 ? product.rating.toStringAsFixed(1) : '4.5',
                                style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.timer_outlined, color: _textSecondary, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '${product.preparationTime} mins prep',
                                style: const TextStyle(color: _textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Description
                          Text(
                            product.description.isNotEmpty ? product.description : 'No description available.',
                            style: const TextStyle(color: _textSecondary, fontSize: 14, height: 1.5),
                          ),
                          const SizedBox(height: 24),

                          // Size Selection Section
                          const Text(
                            'Select Size',
                            style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            children: [
                              _buildSizeOption(
                                title: 'Regular',
                                subtitle: 'Perfect for one',
                                extraPrice: 0.0,
                                isSelected: selectedSize == 'Regular',
                                onTap: () {
                                  setModalState(() {
                                    selectedSize = 'Regular';
                                    sizeExtraPrice = 0.0;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildSizeOption(
                                title: 'Medium',
                                subtitle: 'Share with a friend',
                                extraPrice: 50.0,
                                isSelected: selectedSize == 'Medium',
                                onTap: () {
                                  setModalState(() {
                                    selectedSize = 'Medium';
                                    sizeExtraPrice = 50.0;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildSizeOption(
                                title: 'Large',
                                subtitle: 'For the whole group',
                                extraPrice: 100.0,
                                isSelected: selectedSize == 'Large',
                                onTap: () {
                                  setModalState(() {
                                    selectedSize = 'Large';
                                    sizeExtraPrice = 100.0;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Spice Level Section
                          const Text(
                            'Select Spice Level',
                            style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: ['Mild', 'Medium', 'Hot'].map((spice) {
                              final isSelected = selectedSpice == spice;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() => selectedSpice = spice);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? _brandRed : _panelLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isSelected ? _brandRed : _stroke),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      spice,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : _textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Add-ons Section
                          const Text(
                            'Add Extras (Optional)',
                            style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          ...selectedAddons.keys.map((addonName) {
                            final checked = selectedAddons[addonName]!;
                            final extra = possibleAddons[addonName]!;
                            return CheckboxListTile(
                              value: checked,
                              title: Text(addonName, style: const TextStyle(color: _textPrimary, fontSize: 14)),
                              subtitle: Text('+₹${extra.toStringAsFixed(0)}',
                                  style: const TextStyle(color: _brandRed, fontWeight: FontWeight.bold, fontSize: 12)),
                              activeColor: _brandRed,
                              checkColor: Colors.white,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (val) {
                                setModalState(() {
                                  selectedAddons[addonName] = val ?? false;
                                });
                              },
                            );
                          }),
                          const SizedBox(height: 24),

                          // Cooking Notes
                          const Text(
                            'Any special instructions? (Optional)',
                            style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            maxLines: 2,
                            style: const TextStyle(color: _textPrimary, fontSize: 14),
                            onChanged: (val) => notes = val,
                            decoration: InputDecoration(
                              hintText: 'E.g. No onions, extra spicy, etc.',
                              fillColor: _panelLight,
                              contentPadding: const EdgeInsets.all(16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _stroke),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Dynamic Recommended Add-ons (Phase 6 Bonus)
                          if (_addonsList.isNotEmpty) ...[
                            const Text(
                              'People also ordered with this',
                              style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 170,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _addonsList.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 12),
                                itemBuilder: (context, idx) {
                                  final addonItem = _addonsList[idx];
                                  return Container(
                                    width: 130,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _panelLight,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _stroke),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: addonItem.image,
                                            height: 70,
                                            width: 110,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, _, _) => Container(
                                              color: _stroke,
                                              child: const Icon(Icons.local_drink_rounded, color: _textSecondary),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          addonItem.name,
                                          style: const TextStyle(
                                              color: _textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '₹${addonItem.price.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                  color: _brandRed, fontSize: 12, fontWeight: FontWeight.w800),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                cart.addProduct(addonItem);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Added ${addonItem.name} to cart!'),
                                                    duration: const Duration(seconds: 1),
                                                    backgroundColor: _brandRed,
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: _brandRed,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.add, color: Colors.white, size: 14),
                                              ),
                                            )
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ],
                      ),
                    ),

                    // Add to Cart / Sticky Action Bar
                    Container(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
                      decoration: BoxDecoration(
                        color: _panel,
                        border: const Border(top: BorderSide(color: _stroke, width: 1.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Total Price',
                                  style: TextStyle(color: _textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${totalPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: _brandRed,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandRed,
                                disabledBackgroundColor: _panelLight,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: (!product.isAvailable || config.isCurrentlyOpen == false)
                                  ? null
                                  : () {
                                      final selectedAddonsList = selectedAddons.entries
                                          .where((e) => e.value)
                                          .map((e) => e.key)
                                          .toList();
                                      double totalAddonExtra = selectedAddonsList.fold(
                                          0.0, (sum, name) => sum + (possibleAddons[name] ?? 0.0));

                                      cart.addProduct(
                                        product,
                                        quantity: 1,
                                        size: selectedSize,
                                        spiceLevel: selectedSpice,
                                        customizations: selectedAddonsList,
                                        customizationPrice: sizeExtraPrice + totalAddonExtra,
                                        notes: notes.trim().isNotEmpty ? notes.trim() : null,
                                      );

                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Added ${product.name} ($selectedSize) to cart!'),
                                          backgroundColor: _brandRed,
                                          duration: const Duration(seconds: 2),
                                          action: SnackBarAction(
                                            label: 'VIEW CART',
                                            textColor: Colors.white,
                                            onPressed: () {
                                              Navigator.of(context, rootNavigator: true).push(
                                                MaterialPageRoute(builder: (_) => const CartScreen()),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                              child: Text(
                                !product.isAvailable
                                    ? 'Out of Stock'
                                    : (config.isCurrentlyOpen == false ? 'Kitchen Closed' : 'Add to Cart'),
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSizeOption({
    required String title,
    required String subtitle,
    required double extraPrice,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _brandRed.withValues(alpha: 0.08) : _panelLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _brandRed : _stroke,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
            Text(
              extraPrice > 0 ? '+₹${extraPrice.toStringAsFixed(0)}' : 'Free',
              style: TextStyle(
                color: isSelected ? _brandRed : _textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CUSTOM CATEGORY PERSISTENT HEADER ───────────────────────────────────────
class _StickyCategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _StickyCategoryBarDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyCategoryBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

// ── SECTION HEADER WIDGET ───────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── QUICK FILTER CHIP WIDGET ───────────────────────────────────────────────
class _QuickFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _brandRed : _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _brandRed : _stroke,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── PREMIUM FOOD CARD WIDGET ────────────────────────────────────────────────
class _PremiumFoodCard extends StatelessWidget {
  final Product product;
  final bool isFavorite;
  final VoidCallback onFavoriteTapped;
  final int cartQuantity;
  final bool isStoreClosed;
  final VoidCallback onAddPressed;
  final VoidCallback onIncreasePressed;
  final VoidCallback onDecreasePressed;
  final VoidCallback onTap;

  const _PremiumFoodCard({
    required this.product,
    required this.isFavorite,
    required this.onFavoriteTapped,
    required this.cartQuantity,
    required this.isStoreClosed,
    required this.onAddPressed,
    required this.onIncreasePressed,
    required this.onDecreasePressed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.strikePrice != null && product.strikePrice! > product.price;
    final discountPercent = hasDiscount
        ? (((product.strikePrice! - product.price) / product.strikePrice!) * 100).round()
        : 0;

    final isOutOfStock = !product.isAvailable;


    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isOutOfStock ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _stroke),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Badge / Featured
                    if (product.isFeatured || product.promoTag.isNotEmpty)
                      Row(
                        children: [
                          if (product.isFeatured) ...[
                            const Icon(Icons.star_rounded, color: _gold, size: 16),
                            const SizedBox(width: 4),
                            const Text('Chef\'s Choice',
                                style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.bold)),
                          ] else if (product.promoTag.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _brandRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.promoTag,
                                style: const TextStyle(
                                    color: _brandRed, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),

                    // Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Rating & Preparation Time
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: _gold, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          product.rating > 0 ? product.rating.toStringAsFixed(1) : '4.5',
                          style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.timer_outlined, color: _textSecondary, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${product.preparationTime} mins',
                          style: const TextStyle(color: _textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Description
                    Text(
                      product.description.isNotEmpty ? product.description : 'Premium tasty dish.',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Pricing
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: _brandRed,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₹${product.strikePrice!.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Right Column: Image with Add Button Overlay
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // Image
                  Hero(
                    tag: 'product_img_${product.id}',
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _stroke),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: CachedNetworkImage(
                          imageUrl: product.image,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: _panel,
                            highlightColor: _stroke,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: _stroke,
                            child: const Icon(Icons.restaurant_rounded, color: _textSecondary, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Favorite Overlay Button
                  Positioned(
                    right: 4,
                    top: 4,
                    child: GestureDetector(
                      onTap: onFavoriteTapped,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? _brandRed : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),

                  // Discount Percentage Overlay Badge
                  if (hasDiscount)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _brandRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$discountPercent% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                  // Add Button / Quantity Controls
                  Positioned(
                    bottom: -12,
                    child: Container(
                      height: 34,
                      width: 86,
                      decoration: BoxDecoration(
                        color: _panelLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _stroke),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: isOutOfStock
                          ? const Center(
                              child: Text(
                                'OUT',
                                style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            )
                          : isStoreClosed
                              ? const Center(
                                  child: Text(
                                    'CLOSED',
                                    style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : cartQuantity > 0
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        GestureDetector(
                                          onTap: onDecreasePressed,
                                          child: Container(
                                            width: 26,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.remove_rounded, color: _brandRed, size: 16),
                                          ),
                                        ),
                                        Text(
                                          '$cartQuantity',
                                          style: const TextStyle(
                                            color: _brandRed,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: onIncreasePressed,
                                          child: Container(
                                            width: 26,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.add_rounded, color: _brandRed, size: 16),
                                          ),
                                        ),
                                      ],
                                    )
                                  : InkWell(
                                      onTap: onAddPressed,
                                      borderRadius: BorderRadius.circular(9),
                                      child: const Center(
                                        child: Text(
                                          'ADD',
                                          style: TextStyle(
                                            color: _brandRed,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}



// ── SHIMMER SKELETON LOADER ──────────────────────────────────────────────────
class _ShimmerLoader extends StatelessWidget {
  const _ShimmerLoader();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _panel,
      highlightColor: _stroke,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search field shimmer
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            // Filter chips shimmer
            Row(
              children: List.generate(3, (i) {
                return Container(
                  width: 80,
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // Category rail shimmer
            Row(
              children: List.generate(4, (i) {
                return Container(
                  width: 90,
                  height: 38,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            // Section title shimmer
            Container(
              width: 140,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            // Cards shimmer
            Expanded(
              child: ListView.builder(
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Container(
                    height: 130,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── MENU DATA CONTAINER ──────────────────────────────────────────────────────
class _MenuData {
  final List<Category> categories;
  final List<Product> products;
  final Map<int, List<Product>> productsByCategory;
  final SiteConfig config;

  _MenuData({
    required this.categories,
    required this.products,
    required this.productsByCategory,
    required this.config,
  });
}

// ── ERROR STATE WIDGET ───────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: _brandRed, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load Menu',
              style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: _textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandRed,
                minimumSize: const Size(140, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── EMPTY STATE WIDGET ───────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_rounded, color: _textSecondary, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: _textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
