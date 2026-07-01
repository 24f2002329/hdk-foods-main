import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';

class OrderRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<Order>> _getList(String path) async {
    final response = await _apiClient.get(path);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load orders (${response.statusCode})');
  }

  Future<List<Order>> getPendingOrders() => _getList('orders/pending/');

  Future<List<Order>> getAllOrders() => _getList('orders/');

  Future<List<Order>> getDeliveryOrders() => _getList('orders/delivery/');

  Future<Order> getOrder(int id) async {
    final response = await _apiClient.get('orders/$id/');
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Order not found');
  }

  Future<Order> confirmOrder(int id, int prepTime) async {
    final response = await _apiClient.patch('orders/$id/confirm/', {
      'estimated_preparation_time': prepTime,
    });
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to confirm: ${response.body}');
  }

  Future<Order> rejectOrder(int id, String reason) async {
    final response = await _apiClient.patch('orders/$id/reject/', {
      'reason': reason,
    });
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to reject: ${response.body}');
  }

  String _errorDetail(dynamic response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return response.body;
  }

  Future<Order> updateStatus(int id, String status) async {
    final response = await _apiClient.patch('orders/$id/status/', {
      'status': status,
    });
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception(_errorDetail(response));
  }

  Future<Order> assignDelivery(int orderId, int deliveryUserId) async {
    final response = await _apiClient.patch(
      'orders/$orderId/assign-delivery/',
      {'delivery_user_id': deliveryUserId},
    );
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to assign delivery: ${response.body}');
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _apiClient.get('orders/admin/dashboard/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load dashboard');
  }

  Future<Order> applyDiscount(int orderId, double amount, String reason) async {
    final response = await _apiClient.patch('orders/$orderId/apply-discount/', {
      'discount_amount': amount.toStringAsFixed(2),
      'discount_reason': reason,
    });
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to apply discount: ${response.body}');
  }

  /// Edit order items before confirmation (admin only).
  /// [items] is a list of {product_id, quantity}.
  Future<Order> editItems(int orderId, List<Map<String, dynamic>> items) async {
    final response = await _apiClient.patch('orders/$orderId/edit-items/', {
      'items': items,
    });
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to edit items: ${response.body}');
  }

  Future<Map<String, dynamic>> driverInitiatePayment(int orderId) async {
    final response = await _apiClient.post(
      'orders/$orderId/driver-payment/',
      {},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      jsonDecode(response.body)['detail'] ?? 'Failed to initiate payment',
    );
  }

  Future<Map<String, dynamic>> driverVerifyPayment(
    int orderId, {
    String? utr,
  }) async {
    final Map<String, dynamic> payload = {};
    if (utr != null) {
      payload['utr'] = utr;
    }
    final response = await _apiClient.post(
      'orders/$orderId/driver-verify/',
      payload,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      jsonDecode(response.body)['detail'] ?? 'Failed to verify payment',
    );
  }
}
