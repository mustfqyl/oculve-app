import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/vpn/profile.dart';

final apiProvider = Provider((ref) => OculveApi());
final sessionProvider =
    StateNotifierProvider<SessionController, AsyncValue<Account?>>(
      (ref) => SessionController(ref.watch(apiProvider)),
    );

class Account {
  const Account(this.data, this.profiles);
  final Map<String, dynamic> data;
  final List<VpnProfile> profiles;
  String get plan => data['plan']?.toString() ?? 'Subscription';
  String get status => data['status']?.toString() ?? 'unknown';
  String? get expiresAt => data['expiresAt'] as String?;
  String? get createdAt => data['createdAt'] as String?;
  String get authCode => data['authCode']?.toString() ?? '';
  Map<String, dynamic> get security => data['security'] is Map<String, dynamic>
      ? data['security'] as Map<String, dynamic>
      : const {};
  Map<String, dynamic> get usage => data['usage'] is Map<String, dynamic>
      ? data['usage'] as Map<String, dynamic>
      : const {};
  Map<String, dynamic> get billing => data['billing'] is Map<String, dynamic>
      ? data['billing'] as Map<String, dynamic>
      : const {};
  int get onlineCount => (data['onlineCount'] as num?)?.toInt() ?? 0;
  String get subscriptionUrl => data['subscriptionUrl']?.toString() ?? '';
  List<Map<String, dynamic>> get devices =>
      (data['devices'] as List?)
          ?.whereType<Map>()
          .map((device) => Map<String, dynamic>.from(device))
          .toList() ??
      const [];
  bool get canConnect {
    final expiry = DateTime.tryParse(expiresAt ?? '');
    return ['active', 'on_hold'].contains(status) &&
        (expiry == null || expiry.isAfter(DateTime.now()));
  }
}

class SecondFactorRequired implements Exception {
  const SecondFactorRequired(this.challenge);
  final String challenge;
}

class RegistrationCreatedButNotReady implements Exception {
  const RegistrationCreatedButNotReady(this.cause);
  final Object cause;
  @override
  String toString() =>
      'Account created, but servers are not ready yet. Save your code and sign in again shortly. ($cause)';
}

class SessionController extends StateNotifier<AsyncValue<Account?>> {
  SessionController(this.api) : super(const AsyncValue.loading());
  final OculveApi api;
  int _sessionRevision = 0;
  Future<void> restore() async {
    final revision = ++_sessionRevision;
    try {
      await api.restore();
      if (revision != _sessionRevision || !mounted) return;
      if (!api.hasSession) {
        state = const AsyncValue.data(null);
        return;
      }
      await refresh();
    } on ApiFailure catch (e) {
      if (revision != _sessionRevision || !mounted) return;
      if (e.status == 401) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(e, StackTrace.current);
      }
    } catch (e, st) {
      if (revision != _sessionRevision || !mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String code, {String? challenge}) async {
    final revision = ++_sessionRevision;
    final data = await api.request(
      challenge == null ? '/api/auth/login' : '/api/auth/login/two-factor',
      body: challenge == null
          ? {'authCode': code.trim().toUpperCase()}
          : {'challengeToken': challenge, 'code': code.trim()},
    );
    if (data['requiresTwoFactor'] == true) {
      throw SecondFactorRequired(data['challengeToken'] as String);
    }
    if (revision != _sessionRevision || !mounted) return;
    await refresh();
  }

  Future<String> generateRegistrationCode() async {
    final result = await api.request(
      '/api/auth/generate-code',
      headers: await api.registrationHeaders(),
    );
    final code = result['code']?.toString() ?? '';
    if (code.isEmpty) {
      throw const ApiFailure('Could not generate an access code.');
    }
    return code;
  }

  Future<void> register(String code) async {
    final revision = ++_sessionRevision;
    await api.request(
      '/api/auth/register',
      body: {'authCode': code, 'planCode': 'open'},
      headers: await api.registrationHeaders(),
    );
    if (revision != _sessionRevision || !mounted) return;
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        try {
          await refresh();
          return;
        } on ApiFailure catch (error) {
          if (error.status != 404 || attempt == 4) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      }
    } catch (error) {
      throw RegistrationCreatedButNotReady(error);
    }
  }

  Future<void> refresh() async {
    final revision = _sessionRevision;
    final data = await api.request('/api/user/me');
    final url = data['subscriptionUrl'] as String?;
    final active = Account(data, const []).canConnect;
    final subscription = active && url != null && url.isNotEmpty
        ? await api.subscriptionResponse(url)
        : null;
    final profiles = subscription == null
        ? <VpnProfile>[]
        : VpnProfile.parseSubscription(
            subscription.body,
            responseHeaders: subscription.headers,
          );
    if (revision != _sessionRevision || !mounted) return;
    state = AsyncValue.data(Account(data, profiles));
  }

  /// Update account/security details without re-registering the VPN device.
  Future<void> refreshAccount() async {
    final revision = _sessionRevision;
    final data = await api.request('/api/user/me');
    if (revision != _sessionRevision || !mounted || state.valueOrNull == null) {
      return;
    }
    state = AsyncValue.data(
      Account(data, state.valueOrNull?.profiles ?? const []),
    );
  }

  Future<void> logout() async {
    ++_sessionRevision;
    try {
      await api.request('/api/auth/logout', body: {});
    } finally {
      await api.clear();
      state = const AsyncValue.data(null);
    }
  }

  void clearLocalSession() {
    ++_sessionRevision;
    state = const AsyncValue.data(null);
  }
}
