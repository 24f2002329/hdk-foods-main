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
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/create/'),
      headers: await _headers(),
      body: jsonEncode({
        'address_id': addressId,
        'items': items,
        'payment_method': paymentMethod,
        'delivery_notes': deliveryNotes,
      }),
    );

    if (response.statusCode == 201) {
      return Order.fromJson(jsonDecode(response.body));
    }

    throw Exception('Failed to create order: ${response.body}');
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
}
