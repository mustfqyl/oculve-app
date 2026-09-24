import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiFailure implements Exception {
  final String message;
  final int? status;
  const ApiFailure(this.message, [this.status]);
  @override
  String toString() => message;
}

class SubscriptionResponse {
  const SubscriptionResponse({required this.body, this.headers = const {}});

  final String body;
  final Map<String, String> headers;
}

class _ApiResponse {
  const _ApiResponse(this.body, this.subscriptionHeaders);

  final String body;
  final Map<String, String> subscriptionHeaders;
}

/// Native client for the existing Oculve cookie-authenticated API.
/// Credentials never travel in URLs or to the subscription host.
class OculveApi {
  OculveApi({Uri? origin, FlutterSecureStorage? storage})
    // The public apex redirects POST requests to www with HTTP 307. Keep the
    // mobile client pinned to the canonical API origin so it never has to
    // repeat a credential-bearing request through a redirect.
    : origin = origin ?? Uri.parse('https://www.oculve.com'),
      _storage = storage ?? const FlutterSecureStorage();
  final Uri origin;
  final FlutterSecureStorage _storage;
  String? _token;
  String? _deviceId;
  bool get hasSession => _token != null && _token!.isNotEmpty;
  String get _key => 'oculve.session.${origin.origin}';

  Future<void> restore() async {
    try {
      _token = await _storage.read(key: _key);
    } catch (_) {
      // Unsigned macOS preview builds cannot always access the App Group
      // Keychain. A missing persisted session is safe: the user signs in.
      _token = null;
    }
  }

  Future<void> clear() async {
    _token = null;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async {
    final uri = origin.resolve(path);
    if (uri.origin != origin.origin) {
      throw const ApiFailure('Invalid API address.');
    }
    final result = await _send(
      uri,
      body: body,
      method: method,
      headers: headers,
      authenticated: true,
    );
    try {
      return jsonDecode(result.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiFailure('The service returned an invalid response.');
    }
  }

  Future<String> subscription(String url) async {
    return (await subscriptionResponse(url)).body;
  }

  Future<SubscriptionResponse> subscriptionResponse(String url) async {
    final uri = origin.resolve(url);
    final response = await _send(
      uri,
      authenticated: false,
      // Oculve's PasarGuard subscription rule accepts Happ clients and returns
      // the Xray configuration format that its existing subscriptions use.
      headers: {
        HttpHeaders.userAgentHeader: 'Happ/1.0',
        'X-HWID': await _hwid(),
        'X-Device-OS': Platform.operatingSystem,
      },
    );
    return SubscriptionResponse(
      body: response.body,
      headers: response.subscriptionHeaders,
    );
  }

  Future<Map<String, String>> registrationHeaders() async {
    // Derive the registration ID from the persistent device secret. Hashing
    // also handles older stored IDs that were not 64-character hex strings.
    final hex = sha256
        .convert(utf8.encode(await _hwid()))
        .toString()
        .substring(0, 32)
        .split('');
    hex[12] = '4';
    hex[16] = '8';
    final id =
        '${hex.sublist(0, 8).join()}-${hex.sublist(8, 12).join()}-'
        '${hex.sublist(12, 16).join()}-${hex.sublist(16, 20).join()}-'
        '${hex.sublist(20, 32).join()}';
    return {'x-oculve-device-id': id};
  }

  Future<String> _hwid() async {
    if (_deviceId != null) return _deviceId!;
    const key = 'oculve.device.hwid.v1';
    try {
      final stored = await _storage.read(key: key);
      if (stored != null && stored.isNotEmpty) return _deviceId = stored;
    } catch (_) {}
    final preferences = await SharedPreferences.getInstance();
    final fallback = preferences.getString(key);
    if (fallback != null && fallback.isNotEmpty) return _deviceId = fallback;

    final random = Random.secure();
    final seed = List<int>.generate(32, (_) => random.nextInt(256));
    final generated = sha256.convert(seed).toString();
    _deviceId = generated;
    try {
      await _storage.write(key: key, value: generated);
    } catch (_) {
      await preferences.setString(key, generated);
    }
    return generated;
  }

  Future<_ApiResponse> _send(
    Uri uri, {
    Map<String, dynamic>? body,
    String? method,
    required bool authenticated,
    Map<String, String>? headers,
  }) async {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      throw const ApiFailure('A secure HTTPS service address is required.');
    }
    final tokenForRequest = authenticated ? _token : null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.openUrl(
        method ?? (body == null ? 'GET' : 'POST'),
        uri,
      );
      // Do not forward session credentials through redirects.
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'Oculve/1.0');
      headers?.forEach(request.headers.set);
      if (authenticated) {
        request.headers.set('Origin', origin.origin);
        if (tokenForRequest != null) {
          request.cookies.add(Cookie('token', tokenForRequest));
        }
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) {
          throw const ApiFailure('Service response is too large.');
        }
      }
      final text = utf8.decode(bytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // A 401 from a TOTP challenge can mean an invalid code while the
        // session is still valid. Only the account endpoint establishes that
        // the stored session itself has expired.
        if (response.statusCode == 401 &&
            authenticated &&
            uri.path == '/api/user/me' &&
            _token == tokenForRequest) {
          await clear();
        }
        final message = !authenticated && response.statusCode == 403
            ? 'Subscription access was rejected. Your device limit may be reached.'
            : switch (response.statusCode) {
                400 =>
                  _serviceError(text) ?? 'The service rejected this request.',
                401 =>
                  'Your access code or session is invalid. Please sign in again.',
                403 => 'Access denied. Check your account status.',
                429 => 'Too many attempts. Please wait before trying again.',
                _ =>
                  'Service unavailable (${response.statusCode}). Please try again.',
              };
        throw ApiFailure(message, response.statusCode);
      }
      if (authenticated) {
        for (final cookie in response.cookies.where((c) => c.name == 'token')) {
          if (_token != tokenForRequest) break;
          _token = cookie.value;
          // An unsigned macOS development build cannot access the App Group
          // Keychain. Keep the authenticated session in memory in that case;
          // signed releases still persist it in secure storage.
          try {
            await _storage.write(key: _key, value: _token);
          } catch (_) {}
        }
      }
      const subscriptionHeaderNames = {
        'server-address-resolve-enable',
        'server-address-resolve-dns-domain',
        'server-address-resolve-dns-ip',
      };
      final subscriptionHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        final normalized = name.toLowerCase();
        if (subscriptionHeaderNames.contains(normalized)) {
          subscriptionHeaders[normalized] = values.join(',').trim();
        }
      });
      return _ApiResponse(text, subscriptionHeaders);
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure(
        'Could not reach the service securely. Check your connection.',
      );
    } finally {
      client.close(force: true);
    }
  }

  String? _serviceError(String responseText) {
    try {
      final payload = jsonDecode(responseText);
      if (payload is Map<String, dynamic>) {
        final detail =
            payload['detail'] ?? payload['error'] ?? payload['message'];
        if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      }
    } catch (_) {}
    return null;
  }
}
