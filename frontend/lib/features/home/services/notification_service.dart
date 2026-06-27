import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../../../core/storage/token_storage.dart';

class NotificationModel {
  final int id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class NotificationService {
  static final String _baseUrl = ApiConfig.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getNotifications() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/config/notifications/'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['notifications'] as List? ?? [])
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final count = (data['unread_count'] as num?)?.toInt() ?? 0;
      return {
        'notifications': list,
        'unread_count': count,
      };
    }
    throw Exception('Failed to load notifications');
  }

  Future<void> markAllAsRead() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/config/notifications/'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark all notifications as read');
    }
  }

  Future<void> markAsRead(int id) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/config/notifications/$id/read/'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }
}
