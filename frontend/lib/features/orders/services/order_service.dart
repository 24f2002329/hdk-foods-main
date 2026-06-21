import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/storage/token_storage.dart';
import '../models/order.dart';

class OrderService {
  static final String baseUrl = "${ApiConfig.baseUrl}/orders";

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getAccessToken();

    if (token == null) {
      throw Exception('Please login again');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Order> createOrder({
    required int addressId,
    required List<Map<String, dynamic>> items,
    String paymentMethod = 'cod',
    String deliveryNotes = '',
    String couponCode = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/create/'),
      headers: await _headers(),
      body: jsonEncode({
        'address_id': addressId,
        'items': items,
        'payment_method': paymentMethod,
        'delivery_notes': deliveryNotes,
        if (couponCode.isNotEmpty) 'coupon_code': couponCode,
      }),
    );

    if (response.statusCode == 201) {
      return Order.fromJson(jsonDecode(response.body));
    }

    throw Exception('Failed to create order: ${response.body}');
  }

  Future<Map<String, dynamic>?> validateCoupon({
    required String code,
    required double orderTotal,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/coupons/validate/'),
      headers: await _headers(),
      body: jsonEncode({'code': code, 'order_total': orderTotal.toString()}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  /// Paginated my-orders. Returns {results, count, next, previous}.
  Future<Map<String, dynamic>> getMyOrdersPaged({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-orders/?page=$page'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load orders');
  }

  Future<Order> getOrder(int orderId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$orderId/'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }

    throw Exception('Failed to load order');
  }

  Future<List<Order>> getMyOrders() async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-orders/'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((e) => Order.fromJson(e)).toList();
    }

    throw Exception('Failed to load orders');
  }

  /// Selects the payment method for a confirmed order.
  ///
  /// For 'cod' the returned map contains the updated order under 'order'.
  /// For 'online' it also contains 'payment_session_id', 'cf_order_id' and
  /// 'environment' for opening the Cashfree checkout.
  Future<Map<String, dynamic>> selectPayment({
    required int orderId,
    required String method,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$orderId/select-payment/'),
      headers: await _headers(),
      body: jsonEncode({'payment_method': method}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to start payment: ${response.body}');
  }

  /// Customer acknowledges a staff-modified order.
  /// accepted=true continues the order; accepted=false cancels it.
  Future<Order> acknowledgeChanges({
    required int orderId,
    required bool accepted,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$orderId/acknowledge-changes/'),
      headers: await _headers(),
      body: jsonEncode({'accepted': accepted}),
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to acknowledge changes: ${response.body}');
  }

  /// Confirms a Cashfree payment. The backend fetches the order status from
  /// Cashfree server-to-server, so no client-side signature is needed.
  Future<Order> verifyPayment({
    required int orderId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$orderId/verify-payment/'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Order.fromJson(data['order']);
    }

    throw Exception('Payment verification failed: ${response.body}');
  }

  Future<int?> getQueuePosition(int orderId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$orderId/queue-position/'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['position'] as int?;
    }
    return null;
  }

  Future<bool> hasReview(int orderId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$orderId/review/'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body)['submitted'] as bool?) ?? false;
    }
    return false;
  }

  Future<void> submitReview({
    required int orderId,
    required int rating,
    String comment = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$orderId/review/'),
      headers: await _headers(),
      body: jsonEncode({'rating': rating, 'comment': comment}),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to submit review: ${response.body}');
    }
  }
}
