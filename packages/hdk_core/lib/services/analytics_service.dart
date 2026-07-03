import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class HdkAnalytics {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Log when the app is opened
  static Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
      if (kDebugMode) {
        print('[HdkAnalytics] App Opened event logged');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HdkAnalytics] Error logging app open: $e');
      }
    }
  }

  /// Log when a user adds an item to the cart
  static Future<void> logAddToCart({
    required String itemId,
    required String itemName,
    required double price,
    required int quantity,
    String? category,
  }) async {
    try {
      await _analytics.logAddToCart(
        items: [
          AnalyticsEventItem(
            itemId: itemId,
            itemName: itemName,
            price: price,
            quantity: quantity,
            itemCategory: category,
          ),
        ],
        value: price * quantity,
        currency: 'INR',
      );
      if (kDebugMode) {
        print('[HdkAnalytics] Add To Cart event logged: $itemName x $quantity');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HdkAnalytics] Error logging add to cart: $e');
      }
    }
  }

  /// Log when the user starts the checkout process
  static Future<void> logCheckoutStarted({
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final analyticsItems = items.map((item) {
        return AnalyticsEventItem(
          itemId: item['id']?.toString() ?? '',
          itemName: item['name']?.toString() ?? '',
          price: double.tryParse(item['price']?.toString() ?? '0') ?? 0.0,
          quantity: int.tryParse(item['quantity']?.toString() ?? '1') ?? 1,
        );
      }).toList();

      await _analytics.logBeginCheckout(
        value: totalAmount,
        currency: 'INR',
        items: analyticsItems,
      );
      if (kDebugMode) {
        print('[HdkAnalytics] Begin Checkout event logged: value=$totalAmount');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HdkAnalytics] Error logging begin checkout: $e');
      }
    }
  }

  /// Log when the checkout/purchase is completed successfully
  static Future<void> logCheckoutCompleted({
    required String orderId,
    required double totalAmount,
  }) async {
    try {
      await _analytics.logPurchase(
        transactionId: orderId,
        value: totalAmount,
        currency: 'INR',
      );
      if (kDebugMode) {
        print(
          '[HdkAnalytics] Purchase/Checkout Completed event logged: orderId=$orderId, value=$totalAmount',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HdkAnalytics] Error logging checkout completed: $e');
      }
    }
  }

  /// Log when a payment fails
  static Future<void> logPaymentFailed({
    required String orderId,
    required String errorMessage,
    String? method,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'payment_failed',
        parameters: {
          'order_id': orderId,
          'error_message': errorMessage,
          'payment_method': method ?? 'online',
        },
      );
      if (kDebugMode) {
        print(
          '[HdkAnalytics] Payment Failed event logged: orderId=$orderId, error=$errorMessage',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HdkAnalytics] Error logging payment failure: $e');
      }
    }
  }

  /// Log when an order is cancelled
  static Future<void> logOrderCancelled({
    required String orderId,
    required String reason,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'order_cancelled',
        parameters: {'order_id': orderId, 'reason': reason},
      );
      if (kDebugMode) {
        print(
          '[HdkAnalytics] Order Cancelled event logged: orderId=$orderId, reason=$reason',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HdkAnalytics] Error logging order cancellation: $e');
      }
    }
  }

  /// Log when a product is viewed (helps identify most ordered/popular items)
  static Future<void> logProductView({
    required String itemId,
    required String itemName,
    double? price,
  }) async {
    try {
      await _analytics.logViewItem(
        items: [
          AnalyticsEventItem(itemId: itemId, itemName: itemName, price: price),
        ],
        value: price,
        currency: 'INR',
      );
      if (kDebugMode) {
        print('[HdkAnalytics] View Product event logged: $itemName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HdkAnalytics] Error logging product view: $e');
      }
    }
  }

  /// Set current user ID for analytics tracking
  static Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (_) {}
  }
}
