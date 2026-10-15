import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/vpn/profile.dart';

final apiProvider = Provider((ref) {
  final api = OculveApi();
  ref.onDispose(api.close);
  return api;
});
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
  const SecondFactorRequired(
    this.challenge, {
    this.totp = true,
    this.passkey = false,
    this.passkeyOptions,
    this.nativePasskeySupported = false,
  });
  final String challenge;
  final bool totp;
  final bool passkey;
  final Map<String, dynamic>? passkeyOptions;
  final bool nativePasskeySupported;
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
  int _accountRequest = 0;
  int _appliedAccountRequest = 0;
  Future<void>? _refreshInFlight;
  int? _refreshRevision;
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
      headers: challenge == null
          ? {'X-Oculve-Passkey-Platform': Platform.operatingSystem}
          : null,
    );
    if (revision != _sessionRevision || !mounted) return;
    if (data['requiresTwoFactor'] == true) {
      final methods = data['methods'];
      throw SecondFactorRequired(
        data['challengeToken'] as String,
        totp: methods is Map ? methods['totp'] == true : true,
        passkey: methods is Map && methods['passkey'] == true,
        passkeyOptions: data['passkeyOptions'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['passkeyOptions'] as Map)
            : null,
        nativePasskeySupported: data['nativePasskeySupported'] == true,
      );
    }
    await refresh();
  }

  Future<void> loginWithPasskey(
    String challenge,
    Map<String, dynamic> response,
  ) async {
    final revision = ++_sessionRevision;
    await api.request(
      '/api/auth/login/passkey',
      body: {'challengeToken': challenge, 'response': response},
    );
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
    final headers = await api.registrationHeaders();
    if (revision != _sessionRevision || !mounted) return;
    try {
      await api.request(
        '/api/auth/register',
        body: {'authCode': code, 'planCode': 'open'},
        headers: headers,
      );
    } on ApiFailure catch (error) {
      // HTTP 201 confirms creation even when its session acknowledgement is
      // incomplete. Keep the saved-code/sign-in recovery path instead of retrying creation.
      if (error.status == 201) throw RegistrationCreatedButNotReady(error);
      rethrow;
    }
    if (revision != _sessionRevision || !mounted) return;
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        try {
          await refresh();
          return;
        } on ApiFailure catch (error) {
          if (error.status != 404 || attempt == 4) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 700));
          if (revision != _sessionRevision || !mounted) return;
        }
      }
    } catch (error) {
      throw RegistrationCreatedButNotReady(error);
    }
  }

  Future<void> refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null && _refreshRevision == _sessionRevision) {
      return inFlight;
    }
    final refresh = _loadAccount();
    _refreshInFlight = refresh;
    _refreshRevision = _sessionRevision;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  Future<void> _loadAccount() async {
    final revision = _sessionRevision;
    var request = ++_accountRequest;
    var data = await api.request('/api/user/me');
    if (revision != _sessionRevision || !mounted) return;
    // A newer account read can settle while the old subscription downloads.
    // Merge its details only with profiles from that account's current URL.
    for (var version = 0; version < 3; version++) {
      final latestBeforeLoad = state.valueOrNull;
      if (_appliedAccountRequest > request && latestBeforeLoad != null) {
        data = latestBeforeLoad.data;
        request = _appliedAccountRequest;
      }
      final url = data['subscriptionUrl'] as String?;
      final active = Account(data, const []).canConnect;
      final subscription = active && url != null && url.isNotEmpty
          ? await api.subscriptionResponse(url)
          : null;
      if (revision != _sessionRevision || !mounted) return;
      final latest = state.valueOrNull;
      if (_appliedAccountRequest > request && latest != null) {
        data = latest.data;
        request = _appliedAccountRequest;
        if (latest.subscriptionUrl != (url ?? '')) continue;
      }
      final profiles =
          subscription == null || !Account(data, const []).canConnect
          ? <VpnProfile>[]
          : VpnProfile.parseSubscription(
              subscription.body,
              responseHeaders: subscription.headers,
            );
      _appliedAccountRequest = request;
      state = AsyncValue.data(Account(data, profiles));
      return;
    }
    throw const ApiFailure(
      'The request could not be completed. Please try again.',
    );
  }

  /// Update account/security details without re-registering the VPN device.
  Future<void> refreshAccount() async {
    final revision = _sessionRevision;
    final request = ++_accountRequest;
    final data = await api.request('/api/user/me');
    if (revision != _sessionRevision ||
        !mounted ||
        state.valueOrNull == null ||
        request < _appliedAccountRequest) {
      return;
    }
    _appliedAccountRequest = request;
    state = AsyncValue.data(
      Account(data, state.valueOrNull?.profiles ?? const []),
    );
  }

  Future<void> logout() async {
    final revision = ++_sessionRevision;
    final request = api.request('/api/auth/logout', body: {});
    final authentication = api.authenticationRevision;
    try {
      await request;
    } finally {
      if (revision == _sessionRevision &&
          authentication == api.authenticationRevision) {
        await api.clear();
        if (mounted && revision == _sessionRevision) {
          state = const AsyncValue.data(null);
        }
      }
    }
  }

  void clearLocalSession() {
    ++_sessionRevision;
    state = const AsyncValue.data(null);
  }
}
