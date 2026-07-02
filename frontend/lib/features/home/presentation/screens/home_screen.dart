import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hdk_core/hdk_core.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../address/data/models/customer_address.dart';
import '../../../address/presentation/screens/address_screen.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../../shared/widgets/fly_to_cart.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../data/repositories/product_service.dart';
import '../../data/repositories/config_service.dart';
import '../providers/home_provider.dart';

// Styling constants
const _brandRed = Color(0xFFFF1E1E);
const _surface = Color(0xFF0D0D0D);
const _panel = Color(0xFF161616);
const _stroke = Color(0xFF2A2A2A);
const _mutedText = Color(0xFF9E9E9E);
const _gold = Color(0xFFFFC107);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final cartCount = context.watch<CartProvider>().itemCount;
    final activeTab = homeProvider.activeTab;
    final screens = const [HomeTab(), ProfileScreen()];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final isFirstRouteInCurrentTab = !await homeProvider.navigatorKeys[activeTab]
            .currentState!
            .maybePop();
        if (isFirstRouteInCurrentTab) {
          if (activeTab != 0) {
            homeProvider.setActiveTab(0);
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
              key: homeProvider.navigatorKeys[index],
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
              homeProvider.setActiveTab(0);
            } else if (index == 1) {
              AppRoutes.pushMenu(context, rootNavigator: true);
            } else if (index == 2) {
              AppRoutes.pushCart(context, rootNavigator: true);
            } else if (index == 3) {
              AppRoutes.pushOrders(context, rootNavigator: true);
            } else if (index == 4) {
              homeProvider.setActiveTab(1);
            }
          },
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait([
            homeProvider.configFuture ?? Future.value(const SiteConfig()),
            homeProvider.categoriesFuture ?? Future.value(<Category>[]),
          ]),
          builder: (context, snapshot) {
            if (snapshot.hasError &&
                snapshot.connectionState != ConnectionState.waiting) {
              return ErrorRetryWidget(
                error: snapshot.error.toString(),
                onRetry: homeProvider.reload,
              );
            }
            if (snapshot.hasData) {
              final categories = snapshot.data![1] as List<Category>;
              homeProvider.precacheCategories(context, categories);
            }
            return Stack(
              children: [
                RefreshIndicator(
                  color: _brandRed,
                  backgroundColor: _panel,
                  onRefresh: () async {
                    homeProvider.reload();
                    await Future.wait([
                      homeProvider.productsFuture ?? Future.value(<Product>[]),
                      homeProvider.allProductsFuture ?? Future.value(<Product>[]),
                      homeProvider.categoriesFuture ?? Future.value(<Category>[]),
                      homeProvider.configFuture ?? Future.value(const SiteConfig()),
                      homeProvider.bannersFuture ?? Future.value(<AppBanner>[]),
                      homeProvider.ordersFuture ?? Future.value(<Order>[]),
                      homeProvider.activeCouponsFuture ?? Future.value(<Map<String, dynamic>>[]),
                    ]);
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Phase 1 — Premium Header (Dynamic)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: _HomeHeader(
                            currentUser: homeProvider.currentUser,
                            selectedAddress: homeProvider.selectedAddress,
                            isLoggedIn: homeProvider.isLoggedIn,
                            unreadNotificationCount: homeProvider.unreadNotificationCount,
                            onSelectAddress: () => _selectAddress(context, homeProvider),
                            onLoginPressed: () {
                              AppRoutes.pushLogin(context, rootNavigator: true)
                                  .then((_) {
                                    homeProvider.reload();
                                  });
                            },
                            onNotificationPressed: () => _openNotifications(context, homeProvider),
                          ),
                        ),
                      ),

                      // Phase 2 — Sticky Glassmorphic Search Bar
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickySearchDelegate(
                          child: _StickyGlassmorphicSearchBar(
                            onTap: () {
                              AppRoutes.pushMenu(context, autofocusSearch: true, rootNavigator: true);
                            },
                          ),
                        ),
                      ),

                      // Phase 2 — Kitchen Status Card (Dynamic)
                      SliverToBoxAdapter(
                        child: FutureBuilder<SiteConfig>(
                          future: homeProvider.configFuture,
                          builder: (context, snap) {
                            return _KitchenStatusCard(config: snap.data);
                          },
                        ),
                      ),

                      // Phase 3 — Hero Banner Carousel (Dynamic)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: FutureBuilder<List<AppBanner>>(
                            future: homeProvider.bannersFuture,
                            builder: (context, snap) {
                              if (snap.hasData) {
                                homeProvider.precacheBanners(context, snap.data!);
                              }
                              return _BannerCarousel(banners: snap.data ?? []);
                            },
                          ),
                        ),
                      ),

                      // Phase 4 — Categories (Dynamic)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 0, 8),
                          child: _CategoriesSection(
                            categoriesFuture: homeProvider.categoriesFuture ?? Future.value(<Category>[]),
                          ),
                        ),
                      ),

                      // Phase 5 — Today's Specials (Dynamic: config via is_featured)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 0, 8),
                          child: _SpecialsSection(
                            productsFuture: homeProvider.productsFuture ?? Future.value(<Product>[]),
                          ),
                        ),
                      ),

                      // Phase 7 — Combo Offers (Dynamic: parsed from category "Combos")
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 0, 8),
                          child: _ComboOffersSection(
                            allProductsFuture: homeProvider.allProductsFuture ?? Future.value(<Product>[]),
                            categoriesFuture: homeProvider.categoriesFuture ?? Future.value(<Category>[]),
                          ),
                        ),
                      ),

                      // Phase 8 — Offers & Coupons (Dynamic: fetched from active backend coupons)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 0, 8),
                          child: _CouponsSection(
                            activeCouponsFuture: homeProvider.activeCouponsFuture ?? Future.value(<Map<String, dynamic>>[]),
                          ),
                        ),
                      ),

                      // Phase 9 — New Arrivals & Trending (Dynamic: computed based on rating and date)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _TrendingAndNewSection(
                            productsFuture: homeProvider.allProductsFuture ?? Future.value(<Product>[]),
                          ),
                        ),
                      ),

                      // Phase 6 — Best Sellers (Dynamic: Products with rating >= 4.0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                          child: Text(
                            'Best Sellers 🌟',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      _BestSellersGrid(productsFuture: homeProvider.allProductsFuture ?? Future.value(<Product>[])),

                      // Phase 10 — Recently Ordered (Dynamic: fetched from order history)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: _RecentlyOrderedSection(
                            ordersFuture: homeProvider.ordersFuture ?? Future.value(<Order>[]),
                            onReload: homeProvider.reload,
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                ),
                // Phase 11 — Floating Cart Summary
                if (cart.itemCount > 0)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _FloatingCartSummary(
                      cartCount: cart.itemCount,
                      totalAmount: cart.totalAmount,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openNotifications(BuildContext context, HomeProvider homeProvider) async {
    await AppRoutes.pushNotifications(context);
    homeProvider.loadUserData();
  }

  Future<void> _selectAddress(BuildContext context, HomeProvider homeProvider) async {
    if (!homeProvider.isLoggedIn) {
      _promptLogin(context, homeProvider);
      return;
    }
    final result = await AppRoutes.pushAddresses<CustomerAddress>(
      context,
      selectionMode: true,
      rootNavigator: true,
    );
    if (result != null) {
      homeProvider.setSelectedAddress(result);
    }
  }

  void _promptLogin(BuildContext context, HomeProvider homeProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: Text(
          'Login Required',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Please login to manage and select delivery addresses.',
          style: GoogleFonts.poppins(color: _mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _mutedText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppRoutes.pushLogin(context, rootNavigator: true)
                  .then((_) {
                    homeProvider.reload();
                  });
            },
            child: const Text(
              'Login',
              style: TextStyle(color: _brandRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── SCALE ON TAP ANIMATOR ───────────────────────────────────────────────────
class ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const ScaleOnTap({super.key, required this.child, required this.onTap});

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

// Helper to map dynamic category names to premium Unsplash URLs
String _getCategoryImageUrl(String name) {
  final cleanName = name.trim().toLowerCase();
  if (cleanName.contains('pizza')) {
    return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=200&auto=format&fit=crop&q=80';
  } else if (cleanName.contains('burger')) {
    return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&auto=format&fit=crop&q=80';
  } else if (cleanName.contains('momo')) {
    return 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=200&auto=format&fit=crop&q=80';
  } else if (cleanName.contains('wrap')) {
    return 'https://images.unsplash.com/photo-1626700051175-6518c4793f4f?w=200&auto=format&fit=crop&q=80';
  } else if (cleanName.contains('boba')) {
    return 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=200&auto=format&fit=crop&q=80';
  } else if (cleanName.contains('fries')) {
    return 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=200&auto=format&fit=crop&q=80';
  } else if (cleanName.contains('drink') ||
      cleanName.contains('beverage') ||
      cleanName.contains('cold')) {
    return 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=200&auto=format&fit=crop&q=80';
  } else if (cleanName.contains('dessert') ||
      cleanName.contains('waffle') ||
      cleanName.contains('sweet')) {
    return 'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=200&auto=format&fit=crop&q=80';
  }
  return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=200&auto=format&fit=crop&q=80';
}

// Helper to look up Category Name dynamically
String _getCategoryName(int? categoryId, List<Category> categories) {
  if (categoryId == null) return '';
  for (final c in categories) {
    if (c.id == categoryId) return c.name;
  }
  return '';
}

// ── PHASE 1: PREMIUM HEADER ────────────────────────────────────────────────
class _HomeHeader extends StatelessWidget {
  final User? currentUser;
  final CustomerAddress? selectedAddress;
  final bool isLoggedIn;
  final int unreadNotificationCount;
  final VoidCallback onSelectAddress;
  final VoidCallback onLoginPressed;
  final VoidCallback onNotificationPressed;

  const _HomeHeader({
    required this.currentUser,
    required this.selectedAddress,
    required this.isLoggedIn,
    required this.unreadNotificationCount,
    required this.onSelectAddress,
    required this.onLoginPressed,
    required this.onNotificationPressed,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = currentUser?.name.isNotEmpty == true
        ? currentUser!.name.split(' ').first
        : 'Foodie';

    return Row(
      children: [
        // App Logo
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _brandRed.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/hdk-logo.png',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Greeting & Delivery Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getGreeting()}, $name 👋',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              GestureDetector(
                onTap: onSelectAddress,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: _brandRed,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        isLoggedIn
                            ? (selectedAddress != null
                                  ? '${selectedAddress!.label}: ${selectedAddress!.lineOne}'
                                  : 'Add/Select Address')
                            : 'Login to set address',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: _mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _mutedText,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Notification Icon with Badge / Login Button
        if (isLoggedIn)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onNotificationPressed,
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              if (unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _brandRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: _surface, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$unreadNotificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          )
        else
          ElevatedButton(
            onPressed: onLoginPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Login',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

// ── PHASE 2: STICKY GLASSMORPHIC SEARCH BAR ───────────────────────────────
class _StickySearchDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickySearchDelegate({required this.child});

  @override
  double get minExtent => 72.0;
  @override
  double get maxExtent => 72.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickySearchDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

class _StickyGlassmorphicSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _StickyGlassmorphicSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: _surface.withValues(alpha: 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _panel.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _stroke.withValues(alpha: 0.5)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: _mutedText,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Search Pizza, Momos, Boba...',
                          style: GoogleFonts.poppins(
                            color: _mutedText,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: _panel.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _stroke.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: _brandRed,
                    size: 22,
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

class _StatusItem {
  final String text;
  final IconData icon;
  final Color color;

  const _StatusItem({
    required this.text,
    required this.icon,
    required this.color,
  });
}

class _KitchenStatusCard extends StatefulWidget {
  final SiteConfig? config;
  const _KitchenStatusCard({required this.config});

  @override
  State<_KitchenStatusCard> createState() => _KitchenStatusCardState();
}

class _KitchenStatusCardState extends State<_KitchenStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 3.0,
      end: 8.0,
    ).animate(_pulseController);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      final items = _getItems();
      if (items.length > 1) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % items.length;
          });
        }
      } else {
        if (_currentIndex != 0 && mounted) {
          setState(() {
            _currentIndex = 0;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _KitchenStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startTimer();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  List<_StatusItem> _getItems() {
    final cfg = widget.config;
    if (cfg == null) return const [];

    final isOpen = cfg.isCurrentlyOpen;
    final openTime = cfg.formattedOpenTime;
    final List<_StatusItem> items = [];

    // 1. Kitchen Status Item
    if (isOpen) {
      items.add(
        _StatusItem(
          text: 'Kitchen Open • Fresh food is being prepared.',
          icon: Icons.restaurant_rounded,
          color: Colors.greenAccent,
        ),
      );
    } else {
      final closedMsg = cfg.storeClosedMsg.isNotEmpty
          ? cfg.storeClosedMsg
          : 'We\'re closed. Opens at $openTime.';
      items.add(
        _StatusItem(
          text: 'Kitchen Closed • $closedMsg',
          icon: Icons.storefront_rounded,
          color: Colors.redAccent,
        ),
      );
    }

    // 2. Announcement Items (split by '|')
    if (cfg.announcement.isNotEmpty) {
      final parts = cfg.announcement
          .split('|')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      for (final part in parts) {
        items.add(
          _StatusItem(
            text: part,
            icon: Icons.campaign_rounded,
            color: Colors.amberAccent,
          ),
        );
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _getItems();
    if (items.isEmpty) return const SizedBox.shrink();

    if (_currentIndex >= items.length) {
      _currentIndex = 0;
    }

    final current = items[_currentIndex];
    final color = current.color;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.3), // slide up slightly
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Row(
            key: ValueKey<int>(_currentIndex),
            children: [
              if (current.icon == Icons.restaurant_rounded ||
                  current.icon == Icons.storefront_rounded)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: _pulseAnimation.value,
                            spreadRadius: _pulseAnimation.value / 3,
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                Icon(current.icon, color: color, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  current.text,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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

// ── PHASE 3: HERO BANNER CAROUSEL ──────────────────────────────────────────
class _BannerCarousel extends StatefulWidget {
  final List<AppBanner> banners;
  const _BannerCarousel({required this.banners});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  // Modern default mock banners with Unsplash food photography (fallback only)
  final List<Map<String, String>> _fallbackBanners = [
    {
      'title': 'Premium Tandoori Pizza',
      'subtitle': 'Extra cheese & hot garlic base',
      'image':
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Gourmet Cheese Burgers',
      'subtitle': 'Double patty grilled to perfection',
      'image':
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Chilled Boba Coolers',
      'subtitle': 'Sweet brown sugar & tapioca pearls',
      'image':
          'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=600&auto=format&fit=crop&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final total = widget.banners.isNotEmpty
          ? widget.banners.length
          : _fallbackBanners.length;
      final next = (_currentPage + 1) % total;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useFallback = widget.banners.isEmpty;
    final totalCount = useFallback
        ? _fallbackBanners.length
        : widget.banners.length;

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              final String title = useFallback
                  ? _fallbackBanners[index]['title']!
                  : widget.banners[index].title;
              final String subtitle = useFallback
                  ? _fallbackBanners[index]['subtitle']!
                  : widget.banners[index].subtitle;
              final String image = useFallback
                  ? _fallbackBanners[index]['image']!
                  : widget.banners[index].imageUrl;

              return ScaleOnTap(
                onTap: () {
                  AppRoutes.pushMenu(context, rootNavigator: true);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 300),
                          fadeOutDuration: const Duration(milliseconds: 300),
                          placeholder: (context, url) =>
                              Container(color: _panel),
                          errorWidget: (context, url, error) =>
                              Container(color: _panel),
                        ),
                        // Black overlay gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                        // Banner text content
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _brandRed,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Order Now',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Smooth animated indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalCount, (index) {
            final active = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? _brandRed : _stroke,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── PHASE 4: CATEGORIES REDESIGN ───────────────────────────────────────────
class _CategoriesSection extends StatelessWidget {
  final Future<List<Category>> categoriesFuture;
  const _CategoriesSection({required this.categoriesFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 115,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) => Container(
                width: 90,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          );
        }

        final categories = snapshot.data ?? [];
        if (categories.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Explore Categories 🍕',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      AppRoutes.pushMenu(context, rootNavigator: true);
                    },
                    child: Text(
                      'See All',
                      style: GoogleFonts.poppins(
                        color: _brandRed,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 115,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final imageUrl = cat.image.isNotEmpty
                      ? cat.image
                      : _getCategoryImageUrl(cat.name);

                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: ScaleOnTap(
                      onTap: () {
                        AppRoutes.pushMenu(
                          context,
                          initialCategoryId: cat.id,
                          rootNavigator: true,
                        );
                      },
                      child: Container(
                        width: 95,
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _stroke),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(milliseconds: 300),
                                  fadeOutDuration: const Duration(milliseconds: 300),
                                  placeholder: (context, url) =>
                                      Container(color: _stroke),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.fastfood_rounded,
                                        color: _brandRed,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat.name,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── PHASE 5: TODAY'S SPECIALS ───────────────────────────────────────────────
class _SpecialsSection extends StatelessWidget {
  final Future<List<Product>> productsFuture;
  const _SpecialsSection({required this.productsFuture});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return FutureBuilder<List<Product>>(
      future: productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const SizedBox.shrink();
        final products = snapshot.data ?? [];
        if (products.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 12),
              child: Text(
                'Today\'s Specials 🔥',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  final qty = cart.quantityFor(p);

                  return ScaleOnTap(
                    onTap: () {
                      AppRoutes.pushMenu(
                        context,
                        initialCategoryId: p.categoryId,
                        initialProductId: p.id,
                        rootNavigator: true,
                      );
                    },
                    child: Container(
                      width: 175,
                      margin: const EdgeInsets.only(right: 14),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _stroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Food Image + Badges
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: p.image.isNotEmpty
                                      ? p.image
                                      : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=300&auto=format&fit=crop&q=80',
                                  height: 120,
                                  width: 175,
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(milliseconds: 300),
                                  fadeOutDuration: const Duration(milliseconds: 300),
                                  placeholder: (context, url) =>
                                      Container(color: _stroke, height: 120),
                                  errorWidget: (context, url, s) =>
                                      Container(color: _stroke, height: 120),
                                ),
                              ),
                              // Rating Badge
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: _gold,
                                        size: 11,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        p.rating > 0
                                            ? p.rating.toStringAsFixed(1)
                                            : 'New',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Promo Discount Tag
                              if (p.promoTag.isNotEmpty ||
                                  (p.strikePrice != null &&
                                      p.strikePrice! > p.price))
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _brandRed,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      p.promoTag.isNotEmpty
                                          ? p.promoTag
                                          : '${((p.strikePrice! - p.price) / p.strikePrice! * 100).round()}% OFF',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Food Info
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '₹${p.price.toStringAsFixed(0)}',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          if (p.strikePrice != null &&
                                              p.strikePrice! > p.price)
                                            Text(
                                              '₹${p.strikePrice!.toStringAsFixed(0)}',
                                              style: GoogleFonts.poppins(
                                                color: _mutedText,
                                                fontSize: 11,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (qty > 0)
                                        Container(
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: _brandRed,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                icon: const Icon(
                                                  Icons.remove,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                                onPressed: () =>
                                                    cart.decreaseQuantity(p),
                                              ),
                                              Text(
                                                '$qty',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                icon: const Icon(
                                                  Icons.add,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                                onPressed: () =>
                                                    cart.increaseQuantity(p),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Builder(
                                          builder: (btnCtx) => GestureDetector(
                                            onTap: () {
                                              FlyToCart.run(
                                                sourceContext: btnCtx,
                                                imageUrl: p.image,
                                              );
                                              cart.addProduct(p);
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _brandRed,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '+ Add',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── PHASE 6: BEST SELLERS GRID ──────────────────────────────────────────────
class _BestSellersGrid extends StatelessWidget {
  final Future<List<Product>> productsFuture;
  const _BestSellersGrid({required this.productsFuture});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return FutureBuilder<List<Product>>(
      future: productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.builder(
              itemCount: 2,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisExtent: 130,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          );
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty)
          return const SliverToBoxAdapter(child: SizedBox.shrink());

        // Filter products for dynamic best sellers: rating >= 4.0
        final bestSellers = products.where((p) => p.rating >= 4.0).toList();
        final displayList = bestSellers.isNotEmpty
            ? bestSellers
            : products; // Fallback to all if none are >= 4.0

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final p = displayList[index];
              final qty = cart.quantityFor(p);

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ScaleOnTap(
                  onTap: () {
                    AppRoutes.pushMenu(
                      context,
                      initialCategoryId: p.categoryId,
                      initialProductId: p.id,
                      rootNavigator: true,
                    );
                  },
                  child: Container(
                    height: 132,
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _stroke),
                    ),
                    child: Row(
                      children: [
                        // Large food image with Top Seller Badge
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(22),
                                bottomLeft: Radius.circular(22),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: p.image,
                                width: 120,
                                height: 132,
                                fit: BoxFit.cover,
                                fadeInDuration: const Duration(milliseconds: 300),
                                fadeOutDuration: const Duration(milliseconds: 300),
                                placeholder: (context, url) =>
                                    Container(color: _stroke),
                                errorWidget: (context, url, s) =>
                                    Container(color: _stroke),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _gold,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.flash_on_rounded,
                                      size: 10,
                                      color: Colors.black,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      p.promoTag.isNotEmpty
                                          ? p.promoTag
                                          : 'Top Seller',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Content Info
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      p.description.isNotEmpty
                                          ? p.description
                                          : 'A premium best-selling choice cooked with freshly sourced ingredients.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: _mutedText,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '₹${p.price.toStringAsFixed(0)}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (p.strikePrice != null &&
                                            p.strikePrice! > p.price) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '₹${p.strikePrice!.toStringAsFixed(0)}',
                                            style: GoogleFonts.poppins(
                                              color: _mutedText,
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (qty > 0)
                                      Container(
                                        height: 32,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _brandRed,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: const Icon(
                                                Icons.remove,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              onPressed: () =>
                                                  cart.decreaseQuantity(p),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$qty',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: const Icon(
                                                Icons.add,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              onPressed: () =>
                                                  cart.increaseQuantity(p),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Builder(
                                        builder: (btnCtx) => ElevatedButton(
                                          onPressed: () {
                                            FlyToCart.run(
                                              sourceContext: btnCtx,
                                              imageUrl: p.image,
                                            );
                                            cart.addProduct(p);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _brandRed,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            minimumSize: const Size(0, 32),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text(
                                            'Add to Cart',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
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
                      ],
                    ),
                  ),
                ),
              );
            }, childCount: displayList.length),
          ),
        );
      },
    );
  }
}

// ── PHASE 7: COMBO OFFERS SECTION ───────────────────────────────────────────
// ── PHASE 7: COMBO OFFERS SECTION ───────────────────────────────────────────
class _ComboOffersSection extends StatefulWidget {
  final Future<List<Product>> allProductsFuture;
  final Future<List<Category>> categoriesFuture;

  const _ComboOffersSection({
    required this.allProductsFuture,
    required this.categoriesFuture,
  });

  @override
  State<_ComboOffersSection> createState() => _ComboOffersSectionState();
}

class _ComboOffersSectionState extends State<_ComboOffersSection> {
  late Future<List<dynamic>> _combosFuture;

  @override
  void initState() {
    super.initState();
    _combosFuture = Future.wait([
      widget.allProductsFuture,
      widget.categoriesFuture,
    ]);
  }

  @override
  void didUpdateWidget(covariant _ComboOffersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allProductsFuture != oldWidget.allProductsFuture ||
        widget.categoriesFuture != oldWidget.categoriesFuture) {
      setState(() {
        _combosFuture = Future.wait([
          widget.allProductsFuture,
          widget.categoriesFuture,
        ]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return FutureBuilder<List<dynamic>>(
      future: _combosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const SizedBox.shrink();
        if (!snapshot.hasData) return const SizedBox.shrink();

        final products = snapshot.data![0] as List<Product>;
        final categories = snapshot.data![1] as List<Category>;

        // Filter products where product name contains "Combo" or category is "Combos/Combo"
        final combos = products.where((p) {
          final catName = _getCategoryName(
            p.categoryId,
            categories,
          ).toLowerCase();
          final prodName = p.name.toLowerCase();
          return catName.contains('combo') || prodName.contains('combo');
        }).toList();

        // If admin hasn't configured combos, we hide the section to keep it dynamically clean
        if (combos.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 12),
              child: Text(
                'Mega Combos 🍱',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: combos.length,
                itemBuilder: (context, index) {
                  final p = combos[index];
                  // Calculate dynamic discount original price and savings
                  final original =
                      p.strikePrice ?? (p.price * 1.25).roundToDouble();
                  final savings = original - p.price;

                  return ScaleOnTap(
                    onTap: () {
                      AppRoutes.pushMenu(
                        context,
                        initialCategoryId: p.categoryId,
                        initialProductId: p.id,
                        rootNavigator: true,
                      );
                    },
                    child: Container(
                      width: 280,
                      margin: const EdgeInsets.only(right: 14),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _stroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: p.image.isNotEmpty
                                  ? p.image
                                  : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&auto=format&fit=crop&q=80',
                              height: 120,
                              width: 280,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 300),
                              fadeOutDuration: const Duration(milliseconds: 300),
                              placeholder: (context, url) =>
                                  Container(color: _stroke),
                              errorWidget: (context, url, s) =>
                                  Container(color: _stroke),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        p.description.isNotEmpty
                                            ? p.description
                                            : 'Enjoy this dynamic combo option freshly prepared straight from our kitchen.',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          color: _mutedText,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '₹${p.price.toStringAsFixed(0)}',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '₹${original.toStringAsFixed(0)}',
                                            style: GoogleFonts.poppins(
                                              color: _mutedText,
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Save ₹${savings.toStringAsFixed(0)}',
                                            style: GoogleFonts.poppins(
                                              color: Colors.greenAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Builder(
                                        builder: (btnCtx) => ScaleOnTap(
                                          onTap: () {
                                            FlyToCart.run(
                                              sourceContext: btnCtx,
                                              imageUrl: p.image,
                                            );
                                            cart.addProduct(p);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _brandRed,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Order Now',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w900,
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── PHASE 8: OFFERS & COUPONS SECTION ───────────────────────────────────────
class _CouponsSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> activeCouponsFuture;
  const _CouponsSection({required this.activeCouponsFuture});

  void _copyCoupon(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _panel,
        content: Text(
          'Coupon code "$code" copied to clipboard!',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: activeCouponsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const SizedBox.shrink();
        final coupons = snapshot.data ?? [];
        // Hide if admin has configured no coupons
        if (coupons.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 12),
              child: Text(
                'Offers & Coupons 🏷️',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: coupons.length,
                itemBuilder: (context, index) {
                  final c = coupons[index];
                  final code = c['code'] ?? 'COUPON';
                  final discVal = c['discount_value'] ?? '10';
                  final discType = c['discount_type'] ?? 'percentage';
                  final title = discType == 'percentage'
                      ? '$discVal% OFF'
                      : 'Flat ₹$discVal OFF';
                  final minAmt = c['min_order_amount'] ?? '0';
                  final maxAmt = c['max_discount_amount'];
                  final subtitle =
                      'Min order ₹${double.parse(minAmt.toString()).toStringAsFixed(0)}';
                  final desc = maxAmt != null
                      ? 'Save up to ₹${double.parse(maxAmt.toString()).toStringAsFixed(0)}'
                      : 'Applicable on cloud kitchen menu.';

                  // Generate visual color based on coupon ID
                  final cid = c['id'] ?? index;
                  final List<Color> colors = [
                    Colors.orangeAccent,
                    Colors.greenAccent,
                    Colors.blueAccent,
                  ];
                  final badgeColor = colors[cid % colors.length];

                  return Container(
                    width: 250,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _stroke),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: _stroke.withValues(alpha: 0.8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            title,
                                            style: GoogleFonts.poppins(
                                              color: badgeColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      desc,
                                      style: GoogleFonts.poppins(
                                        color: _mutedText,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Coupon code action
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      code,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ScaleOnTap(
                                    onTap: () => _copyCoupon(context, code),
                                    child: Text(
                                      'COPY',
                                      style: GoogleFonts.poppins(
                                        color: _brandRed,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// Dashed border layout helper
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double dashWidth = 5.0;
    const double dashSpace = 4.0;
    double startX = size.width - 80;

    // Draw vertical dotted line to divide coupon info from copy button
    double startY = 5.0;
    while (startY < size.height - 5) {
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── PHASE 9: NEW ARRIVALS & TRENDING SECTION ────────────────────────────────
class _TrendingAndNewSection extends StatelessWidget {
  final Future<List<Product>> productsFuture;
  const _TrendingAndNewSection({required this.productsFuture});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return FutureBuilder<List<Product>>(
      future: productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const SizedBox.shrink();
        final products = snapshot.data ?? [];
        if (products.isEmpty) return const SizedBox.shrink();

        // Dynamically compute Trending (rating >= 3.8) and New Arrivals (sorted by id desc)
        final trending = products.where((p) => p.rating >= 3.8).toList();
        final newArrivals = products.reversed.toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trending
            if (trending.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Trending Today ⚡',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 195,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: trending.length,
                  itemBuilder: (context, index) {
                    final p = trending[index];
                    final qty = cart.quantityFor(p);

                    return ScaleOnTap(
                      onTap: () {
                        AppRoutes.pushMenu(
                          context,
                          initialCategoryId: p.categoryId,
                          initialProductId: p.id,
                          rootNavigator: true,
                        );
                      },
                      child: Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _stroke),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: p.image.isNotEmpty
                                        ? p.image
                                        : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=300&auto=format&fit=crop&q=80',
                                    height: 95,
                                    width: 150,
                                    fit: BoxFit.cover,
                                    fadeInDuration: const Duration(milliseconds: 300),
                                    fadeOutDuration: const Duration(milliseconds: 300),
                                    placeholder: (context, url) =>
                                        Container(color: _stroke, height: 95),
                                    errorWidget: (context, url, s) =>
                                        Container(color: _stroke, height: 95),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.9,
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      p.promoTag.isNotEmpty
                                          ? p.promoTag
                                          : 'TRENDING',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '₹${p.price.toStringAsFixed(0)}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (qty > 0)
                                          GestureDetector(
                                            onTap: () =>
                                                cart.decreaseQuantity(p),
                                            child: CircleAvatar(
                                              radius: 12,
                                              backgroundColor: _brandRed,
                                              child: Text(
                                                '$qty',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Builder(
                                            builder: (btnCtx) =>
                                                GestureDetector(
                                                  onTap: () {
                                                    FlyToCart.run(
                                                      sourceContext: btnCtx,
                                                      imageUrl: p.image,
                                                    );
                                                    cart.addProduct(p);
                                                  },
                                                  child: const Icon(
                                                    Icons.add_circle_rounded,
                                                    color: _brandRed,
                                                    size: 24,
                                                  ),
                                                ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
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

            // New Arrivals
            const SizedBox(height: 20),
            Text(
              'New Arrivals ✨',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 195,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: newArrivals.length,
                itemBuilder: (context, index) {
                  final p = newArrivals[index];
                  final qty = cart.quantityFor(p);

                  return ScaleOnTap(
                    onTap: () {
                      AppRoutes.pushMenu(
                        context,
                        initialCategoryId: p.categoryId,
                        initialProductId: p.id,
                        rootNavigator: true,
                      );
                    },
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _stroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: p.image.isNotEmpty
                                      ? p.image
                                      : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=300&auto=format&fit=crop&q=80',
                                  height: 95,
                                  width: 150,
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(milliseconds: 300),
                                  fadeOutDuration: const Duration(milliseconds: 300),
                                  placeholder: (context, url) =>
                                      Container(color: _stroke, height: 95),
                                  errorWidget: (context, url, s) =>
                                      Container(color: _stroke, height: 95),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    p.promoTag.isNotEmpty ? p.promoTag : 'NEW',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '₹${p.price.toStringAsFixed(0)}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (qty > 0)
                                        GestureDetector(
                                          onTap: () => cart.decreaseQuantity(p),
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundColor: _brandRed,
                                            child: Text(
                                              '$qty',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Builder(
                                          builder: (btnCtx) => GestureDetector(
                                            onTap: () {
                                              FlyToCart.run(
                                                sourceContext: btnCtx,
                                                imageUrl: p.image,
                                              );
                                              cart.addProduct(p);
                                            },
                                            child: const Icon(
                                              Icons.add_circle_rounded,
                                              color: _brandRed,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
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
        );
      },
    );
  }
}

// ── PHASE 10: RECENTLY ORDERED SECTION ──────────────────────────────────────
class _RecentlyOrderedSection extends StatefulWidget {
  final Future<List<Order>> ordersFuture;
  final VoidCallback onReload;
  const _RecentlyOrderedSection({
    required this.ordersFuture,
    required this.onReload,
  });

  @override
  State<_RecentlyOrderedSection> createState() =>
      _RecentlyOrderedSectionState();
}

class _RecentlyOrderedSectionState extends State<_RecentlyOrderedSection> {
  bool _isReordering = false;

  Future<void> _handleReorder(Order order) async {
    setState(() {
      _isReordering = true;
    });
    try {
      final products = await ProductService.getProducts();
      if (!mounted) return;
      final cart = Provider.of<CartProvider>(context, listen: false);
      int added = 0;
      for (final line in order.items) {
        Product? match;
        for (final p in products) {
          if (p.id == line.productId) {
            match = p;
            break;
          }
        }
        if (match != null) {
          for (int i = 0; i < line.quantity; i++) {
            cart.addProduct(match, haptic: false);
          }
          added++;
        }
      }
      if (added > 0) HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Added $added items from your previous order to your cart!',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        widget.onReload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Failed to reorder: $e',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReordering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Order>>(
      future: widget.ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const SizedBox.shrink();
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) return const SizedBox.shrink();

        // Get the most recent order
        final recentOrder = orders.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recently Ordered 🍕',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _stroke),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reorder Previous Meal',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          recentOrder.items
                              .map((e) => '${e.productName} (x${e.quantity})')
                              .join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: _mutedText,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ₹${recentOrder.totalAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ScaleOnTap(
                    onTap: _isReordering
                        ? () {}
                        : () => _handleReorder(recentOrder),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _brandRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isReordering
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Reorder',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
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
        );
      },
    );
  }
}

// ── PHASE 11: FLOATING CART SUMMARY ─────────────────────────────────────────
class _FloatingCartSummary extends StatelessWidget {
  final int cartCount;
  final double totalAmount;

  const _FloatingCartSummary({
    required this.cartCount,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleOnTap(
      onTap: () {
        AppRoutes.pushCart(context, rootNavigator: true);
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: _brandRed,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _brandRed.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$cartCount ${cartCount == 1 ? 'item' : 'items'} added',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'View Cart',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── BOTTOM NAVIGATION BAR CONTAINER ──────────────────────────────────────────
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
                label: 'Menu',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.shopping_bag_rounded,
                label: 'Cart',
                selected: currentIndex == 2,
                badgeCount: cartCount,
                iconKey: FlyToCart.targetKey,
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
  final Key? iconKey;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
    this.iconKey,
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
                key: iconKey,
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
