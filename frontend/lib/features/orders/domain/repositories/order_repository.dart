import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';

abstract class OrderRepository {
  static OrderRepository? _instance;
  static OrderRepository get instance => _instance ??= HttpOrderRepository();
  static set instance(OrderRepository value) => _instance = value;

  Future<Order> createOrder({
    required int addressId,
    required List<Map<String, dynamic>> items,
    String paymentMethod = 'cod',
    String deliveryNotes = '',
    String couponCode = '',
    bool redeemCoins = false,
  });

  Future<Map<String, dynamic>?> validateCoupon({
    required String code,
    required double orderTotal,
  });

  Future<List<Map<String, dynamic>>> getActiveCoupons();

  Future<Map<String, dynamic>> getMyOrdersPaged({int page = 1});

  Future<Order> getOrder(int orderId);

  Future<List<Order>> getMyOrders();

  Future<Map<String, dynamic>> selectPayment({
    required int orderId,
    required String method,
  });

  Future<Order> acknowledgeChanges({
    required int orderId,
    required bool accepted,
  });

  Future<Order> verifyPayment({required int orderId});

  Future<int?> getQueuePosition(int orderId);

  Future<bool> hasReview(int orderId);

  Future<void> submitReview({
    required int orderId,
    required int rating,
    String comment = '',
    List<Map<String, dynamic>> items = const [],
  });

  Future<Order> requestCancellation({
    required int orderId,
    required String reason,
  });

  Future<List<Map<String, dynamic>>> getOrderMessages(int orderId);

  Future<Map<String, dynamic>> sendOrderMessage(int orderId, String message);

  Future<Order> reportNotReceived(int orderId);
}

class HttpOrderRepository implements OrderRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<Order> createOrder({
    required int addressId,
    required List<Map<String, dynamic>> items,
    String paymentMethod = 'cod',
    String deliveryNotes = '',
    String couponCode = '',
    bool redeemCoins = false,
  }) async {
    final body = {
      'address_id': addressId,
      'items': items,
      'payment_method': paymentMethod,
      'delivery_notes': deliveryNotes,
      if (couponCode.isNotEmpty) 'coupon_code': couponCode,
      'redeem_coins': redeemCoins,
    };
    final response = await _apiClient.post('orders/create/', body);
    if (response.statusCode == 201) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create order: ${response.body}');
  }

  @override
  Future<Map<String, dynamic>?> validateCoupon({
    required String code,
    required double orderTotal,
  }) async {
    final response = await _apiClient.post('orders/coupons/validate/', {
      'code': code,
      'order_total': orderTotal.toString(),
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveCoupons() async {
    try {
      final response = await _apiClient.get('orders/coupons/active/');
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<Map<String, dynamic>> getMyOrdersPaged({int page = 1}) async {
    final response = await _apiClient.get('orders/my-orders/?page=$page');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load orders');
  }

  @override
  Future<Order> getOrder(int orderId) async {
    final response = await _apiClient.get('orders/$orderId/');
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load order');
  }

  @override
  Future<List<Order>> getMyOrders() async {
    final response = await _apiClient.get('orders/my-orders/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((e) => Order.fromJson(e)).toList();
    }
    throw Exception('Failed to load orders');
  }

  @override
  Future<Map<String, dynamic>> selectPayment({
    required int orderId,
    required String method,
  }) async {
    final response = await _apiClient.post('orders/$orderId/select-payment/', {
      'payment_method': method,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to start payment: ${response.body}');
  }

  @override
  Future<Order> acknowledgeChanges({
    required int orderId,
    required bool accepted,
  }) async {
    final response = await _apiClient.post(
      'orders/$orderId/acknowledge-changes/',
      {'accepted': accepted},
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to acknowledge changes: ${response.body}');
  }

  @override
  Future<Order> verifyPayment({required int orderId}) async {
    final response = await _apiClient.post(
      'orders/$orderId/verify-payment/',
      {},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Order.fromJson(data['order']);
    }
    throw Exception('Payment verification failed: ${response.body}');
  }

  @override
  Future<int?> getQueuePosition(int orderId) async {
    final response = await _apiClient.get('orders/$orderId/queue-position/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['position'] as int?;
    }
    return null;
  }

  @override
  Future<bool> hasReview(int orderId) async {
    final response = await _apiClient.get('orders/$orderId/review/');
    if (response.statusCode == 200) {
      return (jsonDecode(response.body)['submitted'] as bool?) ?? false;
    }
    return false;
  }

  @override
  Future<void> submitReview({
    required int orderId,
    required int rating,
    String comment = '',
    List<Map<String, dynamic>> items = const [],
  }) async {
    final response = await _apiClient.post('orders/$orderId/review/', {
      'rating': rating,
      'comment': comment,
      'items': items,
    });
    if (response.statusCode != 201) {
      throw Exception('Failed to submit review: ${response.body}');
    }
  }

  @override
  Future<Order> requestCancellation({
    required int orderId,
    required String reason,
  }) async {
    final response = await _apiClient.post(
      'orders/$orderId/request-cancellation/',
      {'reason': reason},
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception(
      jsonDecode(response.body)['detail'] ?? 'Failed to request cancellation',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getOrderMessages(int orderId) async {
    final response = await _apiClient.get('orders/$orderId/messages/');
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Failed to load chat messages');
  }

  @override
  Future<Map<String, dynamic>> sendOrderMessage(
    int orderId,
    String message,
  ) async {
    final response = await _apiClient.post('orders/$orderId/messages/', {
      'message': message,
    });
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to send message: ${response.body}');
  }

  @override
  Future<Order> reportNotReceived(int orderId) async {
    final response = await _apiClient.post(
      'orders/$orderId/report-not-received/',
      {},
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    final body = jsonDecode(response.body);
    throw Exception(body['detail'] ?? 'Failed to report');
  }
}
