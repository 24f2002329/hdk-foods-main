import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import '../services/token_storage.dart';

/// Central HTTP client that handles 401 → token refresh → retry automatically.
/// All service classes should use this instead of calling http directly for
/// authenticated requests.
class ApiClient {
  static final ApiClient _instance = ApiClient._();
  ApiClient._();
  factory ApiClient() => _instance;

  Future<Map<String, String>> _authHeaders() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw _AuthException();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(String path) => _withRefresh(
    () async => http.get(Uri.parse(_url(path)), headers: await _authHeaders()),
  );

  Future<http.Response> post(String path, Map<String, dynamic> body) =>
      _withRefresh(
        () async => http.post(
          Uri.parse(_url(path)),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        ),
      );

  Future<http.Response> patch(String path, Map<String, dynamic> body) =>
      _withRefresh(
        () async => http.patch(
          Uri.parse(_url(path)),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        ),
      );

  Future<http.Response> put(String path, Map<String, dynamic> body) =>
      _withRefresh(
        () async => http.put(
          Uri.parse(_url(path)),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        ),
      );

  Future<http.Response> delete(String path) => _withRefresh(
    () async =>
        http.delete(Uri.parse(_url(path)), headers: await _authHeaders()),
  );

  String _url(String path) {
    if (path.startsWith('http')) return path;
    final base = ApiConfig.baseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return base.endsWith('/')
        ? '$base$normalizedPath'
        : '$base/$normalizedPath';
  }

  Future<http.Response> _withRefresh(
    Future<http.Response> Function() call,
  ) async {
    try {
      final response = await call();
      if (response.statusCode != 401) return response;
      // Try to refresh the token
      final refreshed = await _tryRefresh();
      if (!refreshed) throw _AuthException();
      return await call(); // Retry with new token
    } on _AuthException {
      await TokenStorage.logout();
      rethrow;
    }
  }

  Future<bool> _tryRefresh() async {
    final refresh = await TokenStorage.getRefreshToken();
    if (refresh == null) return false;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccess = data['access'] as String?;
        if (newAccess != null) {
          await TokenStorage.saveTokens(access: newAccess, refresh: refresh);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }
}

class _AuthException implements Exception {
  const _AuthException();
}
