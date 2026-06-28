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
      final body = jsonDecode(response.body);
      // Handle paginated response {count, results, ...} and plain list
      final list = body is List ? body : body['results'] as List;
      return list
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load orders (${response.statusCode})');
  }

  Future<List<Order>> getPendingOrders() => _getList('$_base/pending/');

  Future<List<Order>> getAllOrders() => _getList('$_base/');

  Future<List<Order>> getDeliveryOrders() => _getList('$_base/delivery/');

  /// Paginated all-orders. Returns raw {count, results, next, previous}.
  Future<Map<String, dynamic>> getAllOrdersPaged({int page = 1}) async {
    final response = await http.get(
        Uri.parse('$_base/?page=$page'), headers: await _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load orders (${response.statusCode})');
  }

  Future<Map<String, dynamic>> getAnalytics({int days = 30}) async {
    final uri = Uri.parse('$_base/admin/analytics/')
        .replace(queryParameters: {'days': days.toString()});
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load analytics');
  }

  // ── Coupon management ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCoupons() async {
    final response = await http.get(
        Uri.parse('$_base/coupons/'), headers: await _headers());
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    throw Exception('Failed to load coupons');
  }

  Future<Map<String, dynamic>> createCoupon(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_base/coupons/'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create coupon: ${response.body}');
  }

  Future<Map<String, dynamic>> toggleCoupon(int id) async {
    final response = await http.patch(
        Uri.parse('$_base/coupons/$id/toggle/'), headers: await _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to toggle coupon');
  }

  Future<void> deleteCoupon(int id) async {
    final response = await http.delete(
        Uri.parse('$_base/coupons/$id/'), headers: await _headers());
    if (response.statusCode != 204) {
      throw Exception('Failed to delete coupon');
    }
  }

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

  Future<List<Order>> getOrders() => getAllOrders();

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

  Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/me/'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load profile');
  }

  Future<Map<String, dynamic>> getDashboard({String period = 'today'}) async {
    final uri = Uri.parse('$_base/admin/dashboard/')
        .replace(queryParameters: {'period': period});
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load dashboard');
  }

  /// Edit order items before confirmation (chef/admin only).
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

  Future<Order> adminCreateOrder(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$_base/admin/create/'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode == 201) {
      return Order.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final body = jsonDecode(response.body);
    final detail = body is Map ? (body['detail'] ?? response.body) : response.body;
    throw Exception(detail);
  }

  Future<Map<String, dynamic>> getCustomerInfo(String phone) async {
    final response = await http.get(
      Uri.parse('$_base/admin/customer-info/?phone=${Uri.encodeComponent(phone)}'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load customer info');
  }

  Future<Order> adminHandleCancellation({
    required int orderId,
    required String action,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/$orderId/admin-handle-cancellation/'),
      headers: await _headers(),
      body: jsonEncode({'action': action, 'reason': reason}),
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final body = jsonDecode(response.body);
    final detail = body is Map ? (body['detail'] ?? response.body) : response.body;
    throw Exception(detail);
  }

  Future<Order> adminCancelOrder({
    required int orderId,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/$orderId/admin-cancel/'),
      headers: await _headers(),
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final body = jsonDecode(response.body);
    final detail = body is Map ? (body['detail'] ?? response.body) : response.body;
    throw Exception(detail);
  }
}
