import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hdk_core/hdk_core.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/name_collection_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/notification_screen.dart';
import '../../features/menu/presentation/screens/menu_screen.dart';
import '../../features/menu/presentation/screens/category_products_screen.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/checkout/presentation/screens/checkout_screen.dart';
import '../../features/checkout/presentation/screens/kitchen_closed_screen.dart';
import '../../features/checkout/presentation/screens/payment_screen.dart';
import '../../features/checkout/presentation/screens/waiting_room_screen.dart';
import '../../features/checkout/presentation/screens/order_status_screens.dart';
import '../../features/address/presentation/screens/address_screen.dart';
import '../../features/address/presentation/screens/location_picker_screen.dart';
import '../../features/profile/presentation/screens/coins_screen.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';
import '../../features/orders/presentation/screens/order_tracking_screen.dart';
import '../../features/orders/presentation/screens/order_chat_screen.dart';
import '../../features/orders/presentation/screens/premium_review_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String nameCollection = '/name-collection';
  static const String home = '/home';
  static const String menu = '/menu';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String addresses = '/addresses';
  static const String locationPicker = '/location-picker';
  static const String coins = '/coins';
  static const String orders = '/orders';
  static const String orderTracking = '/order-tracking';
  static const String orderChat = '/order-chat';
  static const String waitingRoom = '/waiting-room';
  static const String payment = '/payment';
  static const String kitchenClosed = '/kitchen-closed';
  static const String orderConfirmed = '/order-confirmed';
  static const String orderRejected = '/order-rejected';
  static const String notifications = '/notifications';
  static const String categoryProducts = '/category-products';
  static const String premiumReview = '/premium-review';

  // Strongly-typed navigation helpers
  static Future<T?> pushSplash<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, splash);
  }

  static Future<T?> pushReplacementOnboarding<T, TO>(BuildContext context) {
    return Navigator.pushReplacementNamed<T, TO>(context, onboarding);
  }

  static Future<T?> pushLogin<T>(BuildContext context, {bool rootNavigator = false}) {
    return Navigator.of(context, rootNavigator: rootNavigator).pushNamed<T>(login);
  }

  static Future<T?> pushReplacementLogin<T, TO>(BuildContext context) {
    return Navigator.pushReplacementNamed<T, TO>(context, login);
  }

  static Future<T?> pushOtp<T>(
    BuildContext context, {
    required String verificationId,
    required String phoneNumber,
  }) {
    return Navigator.pushNamed<T>(
      context,
      otp,
      arguments: {
        'verificationId': verificationId,
        'phoneNumber': phoneNumber,
      },
    );
  }

  static Future<T?> pushReplacementNameCollection<T, TO>(BuildContext context) {
    return Navigator.pushReplacementNamed<T, TO>(context, nameCollection);
  }

  static Future<T?> pushReplacementHome<T, TO>(BuildContext context) {
    return Navigator.pushReplacementNamed<T, TO>(context, home);
  }

  static Future<T?> pushMenu<T>(
    BuildContext context, {
    int? initialCategoryId,
    int? initialProductId,
    bool autofocusSearch = false,
    bool rootNavigator = false,
  }) {
    return Navigator.of(context, rootNavigator: rootNavigator).pushNamed<T>(
      menu,
      arguments: {
        'initialCategoryId': initialCategoryId,
        'initialProductId': initialProductId,
        'autofocusSearch': autofocusSearch,
      },
    );
  }

  static Future<T?> pushCart<T>(BuildContext context, {bool rootNavigator = false}) {
    return Navigator.of(context, rootNavigator: rootNavigator).pushNamed<T>(cart);
  }

  static Future<T?> pushCheckout<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, checkout);
  }

  static Future<T?> pushAddresses<T>(BuildContext context, {bool selectionMode = false, bool rootNavigator = false}) {
    return Navigator.of(context, rootNavigator: rootNavigator).pushNamed<T>(
      addresses,
      arguments: {'selectionMode': selectionMode},
    );
  }

  static Future<T?> pushLocationPicker<T>(
    BuildContext context, {
    required LatLng initialLocation,
    String? initialAddress,
  }) {
    return Navigator.pushNamed<T>(
      context,
      locationPicker,
      arguments: {
        'initialLocation': initialLocation,
        'initialAddress': initialAddress,
      },
    );
  }

  static Future<T?> pushCoins<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, coins);
  }

  static Future<T?> pushOrders<T>(BuildContext context, {bool rootNavigator = false}) {
    return Navigator.of(context, rootNavigator: rootNavigator).pushNamed<T>(orders);
  }

  static Future<T?> pushOrderTracking<T>(BuildContext context, {required int orderId}) {
    return Navigator.pushNamed<T>(context, orderTracking, arguments: orderId);
  }

  static Future<T?> pushReplacementOrderTracking<T, TO>(BuildContext context, {required int orderId}) {
    return Navigator.pushReplacementNamed<T, TO>(context, orderTracking, arguments: orderId);
  }

  static Future<T?> pushOrderChat<T>(
    BuildContext context, {
    required int orderId,
    required String orderNumber,
  }) {
    return Navigator.pushNamed<T>(
      context,
      orderChat,
      arguments: {
        'orderId': orderId,
        'orderNumber': orderNumber,
      },
    );
  }

  static Future<T?> pushReplacementWaitingRoom<T, TO>(
    BuildContext context, {
    required int orderId,
    required String orderNumber,
    String paymentMethod = 'cod',
  }) {
    return Navigator.pushReplacementNamed<T, TO>(
      context,
      waitingRoom,
      arguments: {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'paymentMethod': paymentMethod,
      },
    );
  }

  static Future<T?> pushReplacementPayment<T, TO>(
    BuildContext context, {
    required int orderId,
    required String orderNumber,
    required double totalAmount,
    String? lockedMethod,
  }) {
    return Navigator.pushReplacementNamed<T, TO>(
      context,
      payment,
      arguments: {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'totalAmount': totalAmount,
        'lockedMethod': lockedMethod,
      },
    );
  }

  static Future<T?> pushKitchenClosed<T>(
    BuildContext context, {
    required String closedMessage,
    String? openTime,
    String? closeTime,
  }) {
    return Navigator.pushNamed<T>(
      context,
      kitchenClosed,
      arguments: {
        'closedMessage': closedMessage,
        'openTime': openTime,
        'closeTime': closeTime,
      },
    );
  }

  static Future<T?> pushReplacementKitchenClosed<T, TO>(
    BuildContext context, {
    required String closedMessage,
    String? openTime,
    String? closeTime,
  }) {
    return Navigator.pushReplacementNamed<T, TO>(
      context,
      kitchenClosed,
      arguments: {
        'closedMessage': closedMessage,
        'openTime': openTime,
        'closeTime': closeTime,
      },
    );
  }

  static Future<T?> pushReplacementOrderConfirmed<T, TO>(
    BuildContext context, {
    required String orderNumber,
    WidgetBuilder? nextScreenBuilder,
    String? nextRouteName,
    Map<String, dynamic>? nextRouteArgs,
    bool isOnlinePayment = false,
  }) {
    return Navigator.pushReplacementNamed<T, TO>(
      context,
      orderConfirmed,
      arguments: {
        'orderNumber': orderNumber,
        'nextScreenBuilder': nextScreenBuilder,
        'nextRouteName': nextRouteName,
        'nextRouteArgs': nextRouteArgs,
        'isOnlinePayment': isOnlinePayment,
      },
    );
  }

  static Future<T?> pushReplacementOrderRejected<T, TO>(
    BuildContext context, {
    required String orderNumber,
    String? reason,
    bool isOnlinePaid = false,
  }) {
    return Navigator.pushReplacementNamed<T, TO>(
      context,
      orderRejected,
      arguments: {
        'orderNumber': orderNumber,
        'reason': reason,
        'isOnlinePaid': isOnlinePaid,
      },
    );
  }

  static Future<T?> pushNotifications<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, notifications);
  }

  static Future<T?> pushCategoryProducts<T>(
    BuildContext context, {
    required Category category,
    required List<Product> products,
  }) {
    return Navigator.pushNamed<T>(
      context,
      categoryProducts,
      arguments: {
        'category': category,
        'products': products,
      },
    );
  }

  static Future<T?> pushPremiumReview<T>(
    BuildContext context, {
    required Order order,
  }) {
    return Navigator.pushNamed<T>(
      context,
      premiumReview,
      arguments: {
        'order': order,
      },
    );
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case onboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          settings: settings,
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case otp:
        final args = settings.arguments as Map<String, dynamic>;
        final verificationId = args['verificationId'] as String;
        final phoneNumber = args['phoneNumber'] as String;
        return MaterialPageRoute(
          builder: (_) => OtpScreen(
            verificationId: verificationId,
            phoneNumber: phoneNumber,
          ),
          settings: settings,
        );
      case nameCollection:
        return MaterialPageRoute(
          builder: (_) => const NameCollectionScreen(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case menu:
        final args = settings.arguments as Map<String, dynamic>?;
        final initialCategoryId = args?['initialCategoryId'] as int?;
        final initialProductId = args?['initialProductId'] as int?;
        final autofocusSearch = args?['autofocusSearch'] as bool? ?? false;
        return MaterialPageRoute(
          builder: (_) => MenuScreen(
            initialCategoryId: initialCategoryId,
            initialProductId: initialProductId,
            autofocusSearch: autofocusSearch,
          ),
          settings: settings,
        );
      case cart:
        return MaterialPageRoute(
          builder: (_) => const CartScreen(),
          settings: settings,
        );
      case checkout:
        return MaterialPageRoute(
          builder: (_) => const CheckoutScreen(),
          settings: settings,
        );
      case addresses:
        final args = settings.arguments as Map<String, dynamic>?;
        final selectionMode = args?['selectionMode'] as bool? ?? false;
        return MaterialPageRoute(
          builder: (_) => AddressScreen(selectionMode: selectionMode),
          settings: settings,
        );
      case locationPicker:
        final args = settings.arguments as Map<String, dynamic>;
        final initialLocation = args['initialLocation'] as LatLng;
        final initialAddress = args['initialAddress'] as String?;
        return MaterialPageRoute(
          builder: (_) => LocationPickerScreen(
            initialLocation: initialLocation,
            initialAddress: initialAddress ?? '',
          ),
          settings: settings,
        );
      case coins:
        return MaterialPageRoute(
          builder: (_) => const CoinsScreen(),
          settings: settings,
        );
      case orders:
        return MaterialPageRoute(
          builder: (_) => const OrdersScreen(),
          settings: settings,
        );
      case orderTracking:
        final orderId = settings.arguments as int;
        return MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: orderId),
          settings: settings,
        );
      case orderChat:
        final args = settings.arguments as Map<String, dynamic>;
        final orderId = args['orderId'] as int;
        final orderNumber = args['orderNumber'] as String;
        return MaterialPageRoute(
          builder: (_) => OrderChatScreen(
            orderId: orderId,
            orderNumber: orderNumber,
          ),
          settings: settings,
        );
      case waitingRoom:
        final args = settings.arguments as Map<String, dynamic>;
        final orderId = args['orderId'] as int;
        final orderNumber = args['orderNumber'] as String;
        final paymentMethod = args['paymentMethod'] as String? ?? 'cod';
        return MaterialPageRoute(
          builder: (_) => WaitingRoomScreen(
            orderId: orderId,
            orderNumber: orderNumber,
            paymentMethod: paymentMethod,
          ),
          settings: settings,
        );
      case payment:
        final args = settings.arguments as Map<String, dynamic>;
        final orderId = args['orderId'] as int;
        final orderNumber = args['orderNumber'] as String;
        final totalAmount = args['totalAmount'] as double;
        final lockedMethod = args['lockedMethod'] as String?;
        return MaterialPageRoute(
          builder: (_) => PaymentScreen(
            orderId: orderId,
            orderNumber: orderNumber,
            totalAmount: totalAmount,
            lockedMethod: lockedMethod,
          ),
          settings: settings,
        );
      case kitchenClosed:
        final args = settings.arguments as Map<String, dynamic>;
        final closedMessage = args['closedMessage'] as String;
        final openTime = args['openTime'] as String?;
        final closeTime = args['closeTime'] as String?;
        return MaterialPageRoute(
          builder: (_) => KitchenClosedScreen(
            closedMessage: closedMessage,
            openTime: openTime,
            closeTime: closeTime,
          ),
          settings: settings,
        );
      case orderConfirmed:
        final args = settings.arguments as Map<String, dynamic>;
        final orderNumber = args['orderNumber'] as String;
        final nextScreenBuilder = args['nextScreenBuilder'] as WidgetBuilder?;
        final nextRouteName = args['nextRouteName'] as String?;
        final nextRouteArgs = args['nextRouteArgs'] as Map<String, dynamic>?;
        final isOnlinePayment = args['isOnlinePayment'] as bool? ?? false;
        return MaterialPageRoute(
          builder: (_) => OrderConfirmedScreen(
            orderNumber: orderNumber,
            nextScreenBuilder: nextScreenBuilder,
            nextRouteName: nextRouteName,
            nextRouteArgs: nextRouteArgs,
            isOnlinePayment: isOnlinePayment,
          ),
          settings: settings,
        );
      case orderRejected:
        final args = settings.arguments as Map<String, dynamic>;
        final orderNumber = args['orderNumber'] as String;
        final reason = args['reason'] as String?;
        final isOnlinePaid = args['isOnlinePaid'] as bool? ?? false;
        return MaterialPageRoute(
          builder: (_) => OrderRejectedScreen(
            orderNumber: orderNumber,
            reason: reason,
            isOnlinePaid: isOnlinePaid,
          ),
          settings: settings,
        );
      case notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationScreen(),
          settings: settings,
        );
      case categoryProducts:
        final args = settings.arguments as Map<String, dynamic>;
        final category = args['category'] as Category;
        final products = args['products'] as List<Product>;
        return MaterialPageRoute(
          builder: (_) => CategoryProductsScreen(
            category: category,
            products: products,
          ),
          settings: settings,
        );
      case premiumReview:
        final args = settings.arguments as Map<String, dynamic>;
        final order = args['order'] as Order;
        return MaterialPageRoute(
          builder: (_) => PremiumReviewScreen(
            order: order,
          ),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
