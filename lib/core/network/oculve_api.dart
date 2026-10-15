import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'device_hwid.dart';
import 'subscription_device_info.dart';

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
  OculveApi({
    Uri? origin,
    FlutterSecureStorage? storage,
    DeviceHwid? deviceHwid,
    SubscriptionDeviceInfo? deviceInfo,
  })
    // The public apex redirects POST requests to www with HTTP 307. Keep the
    // mobile client pinned to the canonical API origin so it never has to
    // repeat a credential-bearing request through a redirect.
    : origin = origin ?? Uri.parse('https://www.oculve.com'),
       _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(
               migrateOnAlgorithmChange: true,
               migrateWithBackup: true,
               resetOnError: false,
             ),
           ),
       _subscriptionHwid = deviceHwid ?? DeviceHwid(),
       _subscriptionDeviceInfo = deviceInfo ?? SubscriptionDeviceInfo(),
       _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final Uri origin;
  final FlutterSecureStorage _storage;
  final HttpClient _client;
  final DeviceHwid _subscriptionHwid;
  final SubscriptionDeviceInfo _subscriptionDeviceInfo;
  String? _token;
  int _sessionRevision = 0;
  int _authenticationRevision = 0;
  Future<void> _storageMutation = Future<void>.value();
  String? _deviceId;
  Future<String>? _registrationSecretPending;
  Future<String>? _clientUserAgent;
  int get authenticationRevision => _authenticationRevision;
  bool get hasSession => _token != null && _token!.isNotEmpty;
  String get _key => 'oculve.session.${origin.origin}';

  void close() => _client.close(force: true);

  Future<void> restore() async {
    final revision = _sessionRevision;
    try {
      final token = await _storage.read(key: _key);
      if (revision == _sessionRevision) _token = token;
    } catch (_) {
      // Unsigned macOS preview builds cannot always access the App Group
      // Keychain. A missing persisted session is safe: the user signs in.
      if (revision == _sessionRevision) _token = null;
    }
  }

  Future<void> clear() => _clearSession(cancelAuthentication: true);

  Future<void> _clearSession({required bool cancelAuthentication}) async {
    if (cancelAuthentication) ++_authenticationRevision;
    ++_sessionRevision;
    _token = null;
    await _mutateSessionStorage(() => _storage.delete(key: _key));
  }

  // Keychain writes can finish after a logout delete. Preserve mutation order
  // so an older token cannot survive locally and reappear on the next launch.
  Future<void> _mutateSessionStorage(Future<void> Function() mutation) {
    return _storageMutation = _storageMutation.then((_) async {
      try {
        await mutation();
      } catch (_) {
        // Unsigned previews may only keep a session in memory.
      }
    });
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
      // Identify Oculve explicitly so provider rules can select its format.
      headers: await subscriptionRequestHeaders(),
    );
    return SubscriptionResponse(
      body: response.body,
      headers: response.subscriptionHeaders,
    );
  }

  Future<Map<String, String>> subscriptionRequestHeaders() async {
    try {
      return {
        HttpHeaders.userAgentHeader: await _userAgent(),
        'X-HWID': await _subscriptionHwid.get(),
        ...await _subscriptionDeviceInfo.headers(),
      };
    } on DeviceHwidUnavailable {
      throw const ApiFailure(
        'Could not read your device identity. Please restart the app and try again.',
      );
    }
  }

  Future<String> _userAgent() => _clientUserAgent ??= _readUserAgent();

  static Future<String> _readUserAgent() async {
    try {
      final version = (await PackageInfo.fromPlatform()).version.trim();
      if (version.isNotEmpty &&
          version.length <= 64 &&
          RegExp(r'^[a-zA-Z0-9.+_-]+$').hasMatch(version)) {
        return 'oculve/$version';
      }
    } catch (_) {
      // Keep our own identity even if native package metadata is unavailable.
    }
    return 'oculve/unknown';
  }

  Future<Map<String, String>> registrationHeaders() async {
    // Derive the registration ID from the persistent device secret. Hashing
    // also handles older stored IDs that were not 64-character hex strings.
    final hex = sha256
        .convert(utf8.encode(await _registrationDeviceSecret()))
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

  // Preserve the existing registration identity; it is not subscription HWID.
  Future<String> _registrationDeviceSecret() {
    final pending = _registrationSecretPending;
    if (pending != null) return pending;
    if (_deviceId != null) return Future.value(_deviceId!);
    return _registrationSecretPending = _loadRegistrationDeviceSecret()
        .whenComplete(() => _registrationSecretPending = null);
  }

  Future<String> _loadRegistrationDeviceSecret() async {
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
    try {
      await _storage.write(key: key, value: generated);
    } catch (_) {
      await preferences.setString(key, generated);
    }
    return _deviceId = generated;
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
    final requestMethod = method ?? (body == null ? 'GET' : 'POST');
    final authenticationRequest =
        authenticated &&
            requestMethod == 'POST' &&
            const {
              '/api/auth/login',
              '/api/auth/login/two-factor',
              '/api/auth/login/passkey',
              '/api/auth/register',
            }.contains(uri.path)
        ? ++_authenticationRevision
        : null;
    if (authenticated &&
        requestMethod == 'POST' &&
        uri.path == '/api/auth/logout') {
      ++_authenticationRevision;
    }
    final tokenForRequest = authenticated ? _token : null;
    final sessionRevision = _sessionRevision;
    HttpClientRequest? request;
    try {
      request = await _client.openUrl(requestMethod, uri);
      // Do not forward session credentials through redirects.
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, await _userAgent());
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
      final text = await _readResponseBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // A 401 from a TOTP challenge can mean an invalid code while the
        // session is still valid. Only the account endpoint establishes that
        // the stored session itself has expired.
        if (response.statusCode == 401 &&
            authenticated &&
            uri.path == '/api/user/me' &&
            _sessionRevision == sessionRevision) {
          // An expired old session must not cancel a newer authentication
          // already in flight. Explicit clear/logout still invalidates it.
          await _clearSession(cancelAuthentication: false);
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
                >= 500 =>
                  'The service is temporarily unavailable. Please try again.',
                _ => 'The request could not be completed. Please try again.',
              };
        throw ApiFailure(message, response.statusCode);
      }
      var authenticationChallenge = false;
      if (authenticationRequest != null &&
          authenticationRequest == _authenticationRevision) {
        // A completed login must acknowledge its own session. Otherwise a
        // missing cookie could make a different-code login reuse the old account.
        Map<String, dynamic> acknowledgement;
        try {
          acknowledgement = jsonDecode(text) as Map<String, dynamic>;
        } catch (_) {
          throw ApiFailure(
            'The service returned an invalid response.',
            response.statusCode,
          );
        }
        authenticationChallenge =
            uri.path == '/api/auth/login' &&
            acknowledgement['requiresTwoFactor'] == true;
        final tokenCookie = response.cookies
            .where((cookie) => cookie.name == 'token')
            .firstOrNull;
        if (!authenticationChallenge &&
            (tokenCookie == null || tokenCookie.value.isEmpty)) {
          throw ApiFailure(
            'The service returned an invalid response.',
            response.statusCode,
          );
        }
      }
      if (authenticated && !authenticationChallenge) {
        for (final cookie in response.cookies.where((c) => c.name == 'token')) {
          if (authenticationRequest == null
              ? _sessionRevision != sessionRevision
              : _authenticationRevision != authenticationRequest) {
            break;
          }
          ++_sessionRevision;
          _token = cookie.value;
          // An unsigned macOS development build cannot access the App Group
          // Keychain. Keep the authenticated session in memory in that case;
          // signed releases still persist it in secure storage.
          await _mutateSessionStorage(
            () => _storage.write(key: _key, value: cookie.value),
          );
          break;
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
      request?.abort();
      rethrow;
    } catch (_) {
      request?.abort();
      throw const ApiFailure(
        'Could not reach the service securely. Check your connection.',
      );
    }
  }

  Future<String> _readResponseBody(HttpClientResponse response) async {
    final chunks = StreamIterator<List<int>>(response);
    final bytes = BytesBuilder(copy: false);
    try {
      // Bound the entire body transfer. An idle timeout alone lets a slow
      // server keep the loading flow and its connection alive indefinitely.
      await (() async {
        while (await chunks.moveNext()) {
          final chunk = chunks.current;
          if (bytes.length + chunk.length > 2 * 1024 * 1024) {
            throw const ApiFailure('Service response is too large.');
          }
          bytes.add(chunk);
        }
      })().timeout(const Duration(seconds: 20));
      return utf8.decode(bytes.takeBytes());
    } finally {
      // Cancels the underlying response also on overflow or timeout.
      await chunks.cancel();
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
