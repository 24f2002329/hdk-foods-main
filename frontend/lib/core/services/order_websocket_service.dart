import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:hdk_core/hdk_core.dart';

/// Shared retry-with-backoff WebSocket loop.
///
/// `_connect` must be called without `await` from `initState`.  All exceptions
/// — including the `WebSocketChannel.ready` rejection that fires when the
/// server has not been upgraded to speak WebSocket yet — are caught inside the
/// method so they never become unhandled Future rejections.
abstract class _ReconnectingWebSocket {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  WebSocketChannel? _channel;
  bool _disposed = false;
  int _retrySeconds = 2;

  /// Override to return the WebSocket URI for this service.
  Future<Uri?> buildUri();

  Future<void> connect() async {
    if (_disposed) return;

    final uri = await buildUri();
    if (uri == null || _disposed) return;

    try {
      _channel = WebSocketChannel.connect(uri);

      // `ready` throws (and propagates to the stream) when the server rejects
      // the upgrade.  Awaiting it here means the rejection is caught by the
      // surrounding try/catch instead of escaping as an unhandled Future error.
      await _channel!.ready;

      _retrySeconds = 2;

      await for (final raw in _channel!.stream) {
        if (_disposed) break;
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(data);
        } catch (_) {}
      }
    } catch (_) {
      // Connection refused, server not upgraded, or stream closed with error.
      // Retry after backoff — do not rethrow.
    }

    if (!_disposed) {
      await Future.delayed(Duration(seconds: _retrySeconds));
      _retrySeconds = (_retrySeconds * 2).clamp(2, 30);
      connect(); // tail-recursive retry; intentionally not awaited
    }
  }

  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    _controller.close();
  }
}

/// Watches a single order — used by the customer order-tracking screen.
/// Connects to `wss://.../ws/orders/<orderId>/`.
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

/// Watches all orders — used by the admin dashboard / active-orders tab.
/// Connects to `wss://.../ws/admin/orders/`.
class AdminOrderWebSocketService extends _ReconnectingWebSocket {
  @override
  Future<Uri?> buildUri() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return null;
    return Uri.parse('${ApiConfig.wsBaseUrl}/ws/admin/orders/?token=$token');
  }
}
