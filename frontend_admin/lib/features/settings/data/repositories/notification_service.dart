import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';

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

  Future<Map<String, dynamic>> getNotifications() async {
    final response = await ApiClient().get('$_baseUrl/config/notifications/');
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
    final response = await ApiClient().post('$_baseUrl/config/notifications/', {});
    if (response.statusCode != 200) {
      throw Exception('Failed to mark all notifications as read');
    }
  }

  Future<void> markAsRead(int id) async {
    final response = await ApiClient().post('$_baseUrl/config/notifications/$id/read/', {});
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }
}
