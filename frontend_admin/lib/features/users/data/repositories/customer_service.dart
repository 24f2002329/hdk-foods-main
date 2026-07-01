import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';

class Customer {
  final int id;
  final String name;
  final String phone;
  final bool isActive;
  final DateTime? createdAt;
  final int orderCount;
  final int loyaltyCoins;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.isActive,
    this.createdAt,
    required this.orderCount,
    required this.loyaltyCoins,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as int,
        name: json['name'] ?? '',
        phone: json['phone_number'] ?? '',
        isActive: json['is_active'] ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'])
            : null,
        orderCount: json['order_count'] ?? 0,
        loyaltyCoins: json['loyalty_coins'] ?? 0,
      );

  String get displayName =>
      name.isNotEmpty ? name : phone;
  String get initials =>
      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
}

class CustomerDetail {
  final Customer customer;
  final List<Order> recentOrders;

  const CustomerDetail({
    required this.customer,
    required this.recentOrders,
  });
}

class CustomerService {
  static final String _base = '${ApiConfig.baseUrl}/customers';

  Future<List<Customer>> getCustomers({String? search}) async {
    final uri = Uri.parse('$_base/').replace(
      queryParameters: search != null && search.isNotEmpty
          ? {'search': search}
          : null,
    );
    final res = await ApiClient().get(uri.toString());
    if (res.statusCode != 200) throw Exception('Failed to load customers');
    final body = jsonDecode(res.body);
    final list = body is List ? body : body['results'] as List;
    return list
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getCustomersPaged({int page = 1, String? search}) async {
    final params = <String, String>{'page': page.toString()};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$_base/').replace(queryParameters: params);
    final res = await ApiClient().get(uri.toString());
    if (res.statusCode != 200) throw Exception('Failed to load customers');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<CustomerDetail> getCustomerDetail(int id) async {
    final res = await ApiClient().get('$_base/$id/');
    if (res.statusCode != 200) throw Exception('Failed to load customer');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final rawOrders = data['recent_orders'] as List? ?? [];
    return CustomerDetail(
      customer: Customer.fromJson(data),
      recentOrders: rawOrders
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<Customer> toggleStatus(int id) async {
    final res = await ApiClient().patch('$_base/$id/toggle-status/', {});
    if (res.statusCode != 200) throw Exception('Failed to update status');
    return Customer.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteCustomer(int id) async {
    final res = await ApiClient().delete('$_base/$id/delete/');
    if (res.statusCode != 204) throw Exception('Failed to delete customer');
  }
}
