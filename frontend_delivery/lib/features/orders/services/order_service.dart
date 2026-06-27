import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/storage/token_storage.dart';
import '../models/order.dart';

class OrderService {
  static final String _base = "${ApiConfig.baseUrl}/orders";

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw Exception('Not logged in');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Order>> _getList(String url) async {
    final response =
        await http.get(Uri.parse(url), headers: await _headers());
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load orders (${response.statusCode})');
  }

  Future<List<Order>> getPendingOrders() => _getList('$_base/pending/');

  Future<List<Order>> getAllOrders() => _getList('$_base/');

  Future<List<Order>> getDeliveryOrders() => _getList('$_base/delivery/');

  Future<Order> getOrder(int id) async {
    final response = await http.get(
        Uri.parse('$_base/$id/'),
        headers: await _headers());
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Order not found');
  }

  Future<Order> confirmOrder(int id, int prepTime) async {
    final response = await http.patch(
      Uri.parse('$_base/$id/confirm/'),
      headers: await _headers(),
      body: jsonEncode({'estimated_preparation_time': prepTime}),
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to confirm: ${response.body}');
  }

  Future<Order> rejectOrder(int id, String reason) async {
    final response = await http.patch(
      Uri.parse('$_base/$id/reject/'),
      headers: await _headers(),
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to reject: ${response.body}');
  }

  Future<Order> updateStatus(int id, String status) async {
    final response = await http.patch(
      Uri.parse('$_base/$id/status/'),
      headers: await _headers(),
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update status: ${response.body}');
  }

  Future<Order> assignDelivery(int orderId, int deliveryUserId) async {
    final response = await http.patch(
      Uri.parse('$_base/$orderId/assign-delivery/'),
      headers: await _headers(),
      body: jsonEncode({'delivery_user_id': deliveryUserId}),
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to assign delivery: ${response.body}');
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(
      Uri.parse('$_base/admin/dashboard/'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load dashboard');
  }

  Future<Order> applyDiscount(
      int orderId, double amount, String reason) async {
    final response = await http.patch(
      Uri.parse('$_base/$orderId/apply-discount/'),
      headers: await _headers(),
      body: jsonEncode({
        'discount_amount': amount.toStringAsFixed(2),
        'discount_reason': reason,
      }),
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to apply discount: ${response.body}');
  }

  /// Edit order items before confirmation (admin only).
  /// [items] is a list of {product_id, quantity}.
  Future<Order> editItems(
      int orderId, List<Map<String, dynamic>> items) async {
    final response = await http.patch(
      Uri.parse('$_base/$orderId/edit-items/'),
      headers: await _headers(),
      body: jsonEncode({'items': items}),
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to edit items: ${response.body}');
  }

  Future<Map<String, dynamic>> driverInitiatePayment(int orderId) async {
    final response = await http.post(
      Uri.parse('$_base/$orderId/driver-payment/'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to initiate payment');
  }

  Future<Map<String, dynamic>> driverVerifyPayment(int orderId) async {
    final response = await http.post(
      Uri.parse('$_base/$orderId/driver-verify/'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to verify payment');
  }
}
