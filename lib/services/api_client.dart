import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';
import '../utils/app_logger.dart';

class ApiClient {
  /// Backend API base. Configurable via `--dart-define=API_BASE=...`.
  static const String baseUrl = Env.apiBase;

  /// Live stream base. Configurable via `--dart-define=LIVE_STREAM_BASE=...`.
  static const String liveStreamBaseUrl = Env.liveStreamBase;

  /// Network timeout applied to every request to avoid infinite spinners.
  static const Duration _timeout = Duration(seconds: 20);

  final Future<SharedPreferences> _prefsFuture =
      SharedPreferences.getInstance();
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  void Function()? onSessionExpired;

  // In-memory token cache to avoid a platform-channel read on every request.
  String? _cachedAccessToken;
  bool _accessTokenLoaded = false;

  ApiClient({this.onSessionExpired});

  Future<String?> _getAccessToken() async {
    if (_accessTokenLoaded) return _cachedAccessToken;
    if (kIsWeb) {
      final prefs = await _prefsFuture;
      _cachedAccessToken = prefs.getString('accessToken');
    } else {
      try {
        _cachedAccessToken = await _secureStorage.read(key: 'accessToken');
      } catch (e) {
        // Fail closed: do NOT fall back to plaintext SharedPreferences.
        logE('Secure storage read failed (accessToken)', e);
        _cachedAccessToken = null;
      }
    }
    _accessTokenLoaded = true;
    return _cachedAccessToken;
  }

  Future<String?> _getRefreshToken() async {
    if (kIsWeb) {
      final prefs = await _prefsFuture;
      return prefs.getString('refreshToken');
    }
    try {
      return await _secureStorage.read(key: 'refreshToken');
    } catch (e) {
      // Fail closed: never read a plaintext refresh token.
      logE('Secure storage read failed (refreshToken)', e);
      return null;
    }
  }

  Future<void> _clearTokens() async {
    _cachedAccessToken = null;
    _accessTokenLoaded = true;
    if (kIsWeb) {
      final prefs = await _prefsFuture;
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      await prefs.remove('user_data');
      return;
    }
    try {
      await _secureStorage.delete(key: 'accessToken');
      await _secureStorage.delete(key: 'refreshToken');
    } catch (e) {
      logE('Secure storage delete failed', e);
    }
    final prefs = await _prefsFuture;
    // Also strip any legacy plaintext tokens written by older builds.
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('user_data');
  }

  Future<String?> getAccessToken() => _getAccessToken();
  Future<String?> getRefreshToken() => _getRefreshToken();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    // Update the in-memory cache immediately so the session works this run
    // even if persistence fails.
    _cachedAccessToken = accessToken;
    _accessTokenLoaded = true;

    if (kIsWeb) {
      final prefs = await _prefsFuture;
      await prefs.setString('accessToken', accessToken);
      await prefs.setString('refreshToken', refreshToken);
      return;
    }
    try {
      await _secureStorage.write(key: 'accessToken', value: accessToken);
      await _secureStorage.write(key: 'refreshToken', value: refreshToken);
    } catch (e) {
      // Fail closed: do NOT persist tokens in plaintext. Session survives in
      // memory for this run; user re-authenticates on next launch.
      logE('Secure storage write failed — tokens not persisted', e);
    }
  }

  Future<void> clearTokens() => _clearTokens();

  /// Endpoints reachable without authentication. A token is still attached
  /// when available (so authenticated users are rate-limited per-account),
  /// and a 401 here never forces a logout.
  static bool _isPublicPath(String path) {
    const publicPrefixes = [
      '/auth/login',
      '/auth/register',
      '/auth/send-otp',
      '/auth/verify-otp',
      '/temples',
      '/categories',
      '/products',
      '/prasad',
      '/vr-experiences',
      '/experts',
    ];
    for (final p in publicPrefixes) {
      if (path.startsWith(p)) return true;
    }
    return false;
  }

  Map<String, String> _buildHeaders(String? token) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String path) => _sendWithRetry('GET', path);

  Future<http.Response> post(String path, {Object? body}) =>
      _sendWithRetry('POST', path, body: body);

  Future<http.Response> put(String path, {Object? body}) =>
      _sendWithRetry('PUT', path, body: body);

  Future<http.Response> patch(String path, {Object? body}) =>
      _sendWithRetry('PATCH', path, body: body);

  Future<http.Response> delete(String path) => _sendWithRetry('DELETE', path);

  Future<http.Response> _sendRequest(
    String method,
    String path, {
    Object? body,
    String? overrideToken,
  }) async {
    // Attach the access token whenever one is available — even on "public"
    // endpoints — so the backend can rate-limit authenticated traffic.
    final token = overrideToken ?? await _getAccessToken();
    final uri = Uri.parse('$baseUrl$path');
    final headers = _buildHeaders(token);
    final bodyStr = body != null ? jsonEncode(body) : null;

    try {
      switch (method) {
        case 'GET':
          return await http.get(uri, headers: headers).timeout(_timeout);
        case 'POST':
          return await http
              .post(uri, headers: headers, body: bodyStr)
              .timeout(_timeout);
        case 'PUT':
          return await http
              .put(uri, headers: headers, body: bodyStr)
              .timeout(_timeout);
        case 'PATCH':
          return await http
              .patch(uri, headers: headers, body: bodyStr)
              .timeout(_timeout);
        case 'DELETE':
          return await http.delete(uri, headers: headers).timeout(_timeout);
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }
    } on TimeoutException {
      throw ApiException(
          'The request timed out. Please check your connection and try again.');
    }
  }

  Future<http.Response> _sendWithRetry(
    String method,
    String path, {
    Object? body,
  }) async {
    try {
      var response = await _sendRequest(method, path, body: body);

      // Only attempt refresh / forced-logout for authenticated endpoints.
      if (response.statusCode == 401 &&
          !_isPublicPath(path) &&
          path != '/auth/refresh') {
        final refreshed = await _refreshSession();
        if (refreshed) {
          final newToken = await _getAccessToken();
          response = await _sendRequest(
            method,
            path,
            body: body,
            overrideToken: newToken,
          );
        } else {
          await _clearTokens();
          if (onSessionExpired != null) {
            onSessionExpired!();
          }
          throw ApiException('Session expired, please login again.', 401);
        }
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool>? _refreshFuture;

  Future<bool> _refreshSession() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = _doRefresh();
    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<bool> _doRefresh() async {
    try {
      final refreshToken = await _getRefreshToken();
      if (refreshToken == null) {
        return false;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: _buildHeaders(null),
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          String? newAccessToken;
          String? newRefreshToken;

          if (data['data'] != null && data['data'] is Map) {
            newAccessToken = data['data']['accessToken'] as String?;
            newRefreshToken = data['data']['refreshToken'] as String?;
          }
          if (newAccessToken == null &&
              data['tokens'] != null &&
              data['tokens'] is Map) {
            newAccessToken = data['tokens']['accessToken'] as String?;
            newRefreshToken = data['tokens']['refreshToken'] as String?;
          }
          newAccessToken ??= data['accessToken'] as String?;
          newRefreshToken ??= data['refreshToken'] as String?;

          if (newAccessToken != null) {
            await saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken ?? refreshToken,
            );
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      logE('Token refresh failed', e);
      return false;
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
