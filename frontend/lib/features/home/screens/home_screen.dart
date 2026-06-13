import '../../address/screens/address_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../cart/screens/cart_screen.dart';
import '../../cart/services/cart_provider.dart';
import '../../menu/screens/menu_screen.dart';
import '../../orders/screens/orders_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/category_card.dart';
import '../../../shared/widgets/product_card.dart';
import '../services/product_service.dart';

const _brandRed = Color(0xFFFF1E1E);
const _deepText = Colors.white;
const _mutedText = Color(0xFFB8B8B8);
const _surface = Color(0xFF050505);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int activeTab = 0; // 0 maps to Home, 1 maps to Profile

  final _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  final screens = const [HomeTab(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final isFirstRouteInCurrentTab = !await _navigatorKeys[activeTab]
            .currentState!
            .maybePop();
        if (isFirstRouteInCurrentTab) {
          if (activeTab != 0) {
            setState(() {
              activeTab = 0;
            });
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: _surface,
        body: IndexedStack(
          index: activeTab,
          children: List.generate(2, (index) {
            return Navigator(
              key: _navigatorKeys[index],
              onGenerateRoute: (settings) {
                WidgetBuilder builder;
                switch (settings.name) {
                  case '/':
                    builder = (context) => screens[index];
                    break;
                  case '/addresses':
                    builder = (context) => const AddressScreen();
                    break;
                  default:
                    builder = (context) => screens[index];
                }
                return MaterialPageRoute(builder: builder, settings: settings);
              },
            );
          }),
        ),
        bottomNavigationBar: _FoodBottomNavigationBar(
          currentIndex: activeTab == 0 ? 0 : 4,
          cartCount: cartCount,
          onTap: (index) {
            if (index == 0) {
              if (activeTab == 0) {
                _navigatorKeys[0].currentState?.popUntil(
                  (route) => route.isFirst,
                );
              } else {
                setState(() => activeTab = 0);
              }
            } else if (index == 1) {
              Navigator.of(
                context,
                rootNavigator: true,
              ).push(MaterialPageRoute(builder: (_) => const MenuScreen()));
            } else if (index == 2) {
              Navigator.of(
                context,
                rootNavigator: true,
              ).push(MaterialPageRoute(builder: (_) => const CartScreen()));
            } else if (index == 3) {
              Navigator.of(
                context,
                rootNavigator: true,
              ).push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
            } else if (index == 4) {
              if (activeTab == 1) {
                _navigatorKeys[1].currentState?.popUntil(
                  (route) => route.isFirst,
                );
              } else {
                setState(() => activeTab = 1);
              }
            }
          },
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<Product>> productsFuture;
  late Future<List<Category>> categoriesFuture;

  @override
  void initState() {
    super.initState();
    productsFuture = ProductService.getProducts();
    categoriesFuture = ProductService.getCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _brandRed,
          backgroundColor: _panel,
          onRefresh: () async {
            setState(() {
              productsFuture = ProductService.getProducts();
              categoriesFuture = ProductService.getCategories();
            });
            await Future.wait([productsFuture, categoriesFuture]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _HomeHeader(),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _SearchBar(),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _OfferBanner(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 0, 0),
                  child: _CategoriesSection(categoriesFuture: categoriesFuture),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                  child: _SectionHeader(
                    title: 'Popular dishes',
                    action: 'View all',
                    onActionPressed: () {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const MenuScreen()),
                      );
                    },
                  ),
                ),
              ),
              _ProductsGrid(productsFuture: productsFuture),
              const SliverToBoxAdapter(child: SizedBox(height: 112)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _brandRed,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _brandRed.withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'HDK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: const TextStyle(
                  color: _deepText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Row(
                children: [
                  Text(
                    'Delivering to',
                    style: TextStyle(
                      color: _mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Current Location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _deepText,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 20, color: _deepText),
                ],
              ),
            ],
          ),
        ),
        IconButton.filled(
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: _panel,
            foregroundColor: Colors.white,
            side: const BorderSide(color: _stroke),
          ),
          icon: const Icon(Icons.notifications_none),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: _panel,
            foregroundColor: _brandRed,
            side: const BorderSide(color: _stroke),
          ),
          icon: const Icon(Icons.favorite_border_rounded),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            readOnly: true,
            onTap: () {
              Navigator.of(
                context,
                rootNavigator: true,
              ).push(MaterialPageRoute(builder: (_) => const MenuScreen()));
            },
            decoration: InputDecoration(
              hintText: 'Search boba, momos, wraps',
              hintStyle: const TextStyle(
                color: _mutedText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(Icons.search, color: _mutedText),
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
        const SizedBox(width: 12),
        SizedBox(
          width: 54,
          height: 54,
          child: IconButton.filled(
            onPressed: () {},
            style: IconButton.styleFrom(
              backgroundColor: _deepText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.tune),
          ),
        ),
      ],
    );
  }
}

class _OfferBanner extends StatelessWidget {
  const _OfferBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF1E1E), Color(0xFF8D0000), Color(0xFF120000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _brandRed.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -42,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 10,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.local_pizza_rounded,
                      size: 74,
                      color: Color(0xFFFFC107),
                    ),
                    Positioned(
                      right: 23,
                      top: 31,
                      child: Icon(
                        Icons.circle,
                        size: 10,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                    Positioned(
                      left: 31,
                      bottom: 31,
                      child: Icon(
                        Icons.circle,
                        size: 9,
                        color: Color(0xFFFF1E1E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 185,
                    child: Text(
                      '50% OFF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 0.96,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ON YOUR FIRST ORDER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 34,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (_) => const MenuScreen()),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _brandRed,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'ORDER NOW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
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

class _CategoriesSection extends StatelessWidget {
  final Future<List<Category>> categoriesFuture;

  const _CategoriesSection({required this.categoriesFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 112,
            child: Center(child: CircularProgressIndicator(color: _brandRed)),
          );
        }

        if (snapshot.hasError) {
          return _InlineError(message: snapshot.error.toString());
        }

        final categories = snapshot.data ?? [];

        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: _SectionHeader(
                title: 'Categories',
                action: 'See all',
                onActionPressed: () {
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).push(MaterialPageRoute(builder: (_) => const MenuScreen()));
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return CategoryCard(category: categories[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductsGrid extends StatelessWidget {
  final Future<List<Product>> productsFuture;

  const _ProductsGrid({required this.productsFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(color: _brandRed)),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _InlineError(message: snapshot.error.toString()),
            ),
          );
        }

        final products = snapshot.data ?? [];
        final cart = context.watch<CartProvider>();

        if (products.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _InlineError(message: 'No products available right now'),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.builder(
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.58,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              final product = products[index];

              return ProductCard(
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
              );
            },
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback? onActionPressed;

  const _SectionHeader({
    required this.title,
    required this.action,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _deepText,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        TextButton(
          onPressed: onActionPressed ?? () {},
          style: TextButton.styleFrom(
            foregroundColor: _mutedText,
            padding: EdgeInsets.zero,
            minimumSize: const Size(54, 34),
          ),
          child: Text(
            action,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
      ),
      child: Text(
        message,
        style: const TextStyle(color: _mutedText, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FoodBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final int cartCount;
  final ValueChanged<int> onTap;

  const _FoodBottomNavigationBar({
    required this.currentIndex,
    required this.cartCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        border: const Border(top: BorderSide(color: _stroke, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.44),
            blurRadius: 28,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.restaurant_menu_rounded,
                label: 'Categories',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.shopping_bag_rounded,
                label: 'Cart',
                selected: currentIndex == 2,
                badgeCount: cartCount,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Orders',
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: selected ? _brandRed : const Color(0xFFBEB7AF),
                    size: 24,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _brandRed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _brandRed : const Color(0xFFBEB7AF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
