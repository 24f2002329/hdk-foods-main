import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';

/// Maintains a WebSocket connection to `ws://.../ws/orders/<orderId>/`.
/// Emits decoded JSON maps via [stream]. Auto-reconnects with backoff.
class OrderWebSocketService {
  final int orderId;
  OrderWebSocketService(this.orderId);

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  WebSocketChannel? _channel;
  bool _disposed = false;
  int _retrySeconds = 2;

  Future<void> connect() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || _disposed) return;

    final uri = Uri.parse(
      '${ApiConfig.wsBaseUrl}/ws/orders/$orderId/?token=$token',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _retrySeconds = 2;

      await for (final raw in _channel!.stream) {
        if (_disposed) break;
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(data);
        } catch (_) {}
      }
    } catch (_) {}

    if (!_disposed) {
      await Future.delayed(Duration(seconds: _retrySeconds));
      _retrySeconds = (_retrySeconds * 2).clamp(2, 30);
      connect();
    }
  }

  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    _controller.close();
  }
}

/// Admin variant — connects to `ws://.../ws/admin/orders/`.
class AdminOrderWebSocketService {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  WebSocketChannel? _channel;
  bool _disposed = false;
  int _retrySeconds = 2;

  Future<void> connect() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || _disposed) return;

    final uri = Uri.parse(
      '${ApiConfig.wsBaseUrl}/ws/admin/orders/?token=$token',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _retrySeconds = 2;

      await for (final raw in _channel!.stream) {
        if (_disposed) break;
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(data);
        } catch (_) {}
      }
    } catch (_) {}

    if (!_disposed) {
      await Future.delayed(Duration(seconds: _retrySeconds));
      _retrySeconds = (_retrySeconds * 2).clamp(2, 30);
      connect();
    }
  }

  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    _controller.close();
  }
}
