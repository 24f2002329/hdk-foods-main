import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hdk_core/hdk_core.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../address/data/models/customer_address.dart';
import '../../../address/domain/repositories/address_repository.dart';
import '../../../accounts/domain/repositories/user_repository.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../data/repositories/config_service.dart';
import '../../data/repositories/product_service.dart';
import '../../data/repositories/notification_service.dart';

class HomeProvider extends ChangeNotifier {
  int _activeTab = 0;
  int get activeTab => _activeTab;

  final List<GlobalKey<NavigatorState>> navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // Tab switching
  void setActiveTab(int index) {
    if (_activeTab == index) {
      // Pop to first route
      navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      _activeTab = index;
      notifyListeners();
    }
  }

  // Futures for landing page
  Future<List<Product>>? productsFuture;
  Future<List<Product>>? allProductsFuture;
  Future<List<Category>>? categoriesFuture;
  Future<SiteConfig>? configFuture;
  Future<List<AppBanner>>? bannersFuture;
  Future<List<Order>>? ordersFuture;
  Future<List<Map<String, dynamic>>>? activeCouponsFuture;

  // Active Session & User Info States
  User? currentUser;
  CustomerAddress? selectedAddress;
  bool isLoggedIn = false;
  int unreadNotificationCount = 0;

  Timer? _autoReloadTimer;
  final Set<String> _precachedUrls = {};

  HomeProvider() {
    reload();
    _autoReloadTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (isLoggedIn) {
        ordersFuture = _fetchOrdersSafely();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _autoReloadTimer?.cancel();
    super.dispose();
  }

  void reload() {
    _precachedUrls.clear();
    
    // 1. Populate immediately from cache
    productsFuture = ProductService.getFeaturedProducts(fromCache: true);
    allProductsFuture = ProductService.getProducts(fromCache: true);
    categoriesFuture = ProductService.getCategories(fromCache: true);
    configFuture = ConfigService().getConfig(fromCache: true);
    bannersFuture = ConfigService().getBanners(fromCache: true);
    activeCouponsFuture = OrderRepository.instance.getActiveCoupons();
    ordersFuture = _fetchOrdersSafely();
    
    loadUserData(fromCacheOnly: true).then((_) {
      notifyListeners();
    });
    
    notifyListeners();

    // 2. Fetch fresh data in the background
    _fetchFreshData();
  }

  Future<void> _fetchFreshData() async {
    try {
      final freshFeatured = ProductService.getFeaturedProducts(fromCache: false);
      final freshAll = ProductService.getProducts(fromCache: false);
      final freshCategories = ProductService.getCategories(fromCache: false);
      final freshConfig = ConfigService().getConfig(fromCache: false);
      final freshBanners = ConfigService().getBanners(fromCache: false);

      await Future.wait([
        freshFeatured,
        freshAll,
        freshCategories,
        freshConfig,
        freshBanners,
      ]);

      productsFuture = freshFeatured;
      allProductsFuture = freshAll;
      categoriesFuture = freshCategories;
      configFuture = freshConfig;
      bannersFuture = freshBanners;
      
      await loadUserData(fromCacheOnly: false);
      notifyListeners();
    } catch (_) {}
  }

  Future<List<Order>> _fetchOrdersSafely() async {
    final loggedIn = await TokenStorage.isLoggedIn();
    if (!loggedIn) return <Order>[];
    try {
      return await OrderRepository.instance.getMyOrders();
    } catch (_) {
      return <Order>[];
    }
  }

  Future<void> loadUserData({bool fromCacheOnly = false}) async {
    final loggedIn = await TokenStorage.isLoggedIn();
    isLoggedIn = loggedIn;
    if (!loggedIn) {
      currentUser = null;
      selectedAddress = null;
      unreadNotificationCount = 0;
      notifyListeners();
      return;
    }
    
    try {
      final cachedUser = await UserRepository.instance.getCurrentUser(fromCache: true);
      currentUser = cachedUser;
      if (fromCacheOnly) {
        notifyListeners();
        return;
      }
    } catch (_) {}

    try {
      final user = await UserRepository.instance.getCurrentUser(fromCache: false);
      List<CustomerAddress> addresses = [];
      try {
        addresses = await AddressRepository.instance.getAddresses();
      } catch (_) {}

      CustomerAddress? activeAddr;
      if (addresses.isNotEmpty) {
        activeAddr = addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );
      }

      int unreadCount = 0;
      try {
        final res = await NotificationService().getNotifications();
        unreadCount = res['unread_count'] as int;
      } catch (_) {}

      currentUser = user;
      selectedAddress = activeAddr;
      unreadNotificationCount = unreadCount;
      notifyListeners();
    } catch (_) {}
  }

  void setSelectedAddress(CustomerAddress address) {
    selectedAddress = address;
    notifyListeners();
  }

  void precacheCategories(BuildContext context, List<Category> categories) {
    for (final cat in categories) {
      final url = cat.image.isNotEmpty ? cat.image : '';
      if (url.isNotEmpty && !_precachedUrls.contains(url)) {
        _precachedUrls.add(url);
        precacheImage(CachedNetworkImageProvider(url), context);
      }
    }
  }

  void precacheBanners(BuildContext context, List<AppBanner> banners) {
    for (final b in banners) {
      final url = b.imageUrl;
      if (url.isNotEmpty && !_precachedUrls.contains(url)) {
        _precachedUrls.add(url);
        precacheImage(CachedNetworkImageProvider(url), context);
      }
    }
  }
}
