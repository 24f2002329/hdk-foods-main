import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:hdk_core/hdk_core.dart';

abstract class _ReconnectingWebSocket {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  WebSocketChannel? _channel;
  bool _disposed = false;
  int _retrySeconds = 2;

  Future<Uri?> buildUri();

  Future<void> connect() async {
    if (_disposed) return;

    final uri = await buildUri();
    if (uri == null || _disposed) return;

    try {
      _channel = WebSocketChannel.connect(uri);
      // Await ready so a rejected upgrade is caught here rather than
      // propagating as an unhandled Future rejection.
      await _channel!.ready;
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

class OrderWebSocketService extends _ReconnectingWebSocket {
  final int orderId;
  OrderWebSocketService(this.orderId);

  @override
  Future<Uri?> buildUri() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return null;
    return Uri.parse(
        '${ApiConfig.wsBaseUrl}/ws/orders/$orderId/?token=$token');
  }
}

/// Delivery-staff variant — connects to `wss://.../ws/delivery/orders/`.
class AdminOrderWebSocketService extends _ReconnectingWebSocket {
  @override
  Future<Uri?> buildUri() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return null;
    return Uri.parse(
        '${ApiConfig.wsBaseUrl}/ws/delivery/orders/?token=$token');
  }
}
