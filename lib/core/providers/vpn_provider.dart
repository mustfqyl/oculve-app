import 'package:oculve/core/connection/dpi_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../connection/connection_preferences.dart';
import '../connection/lan_proxy_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import '../models/vpn_state.dart';
import '../models/user_facing_failure.dart';
import '../vpn/xray_preferences.dart';
import '../vpn/server_latency.dart';
import '../vpn/profile.dart';
import '../../features/auth/data/auth_repository.dart';

final selectedServerProvider = StateProvider<String?>((ref) => null);
const optimalServerId = '__oculve_optimal__';
const dpiBypassServerId = '__oculve_dpi_bypass__';
final optimalServerProfileProvider = StateProvider<String?>((ref) => null);
final vpnErrorProvider = StateProvider<String?>((ref) => null);

/// True until the native tunnel has confirmed that it stopped. Direct TCP
/// measurements must not accidentally run through an active VPN route.
final vpnTunnelMayBeActiveProvider = StateProvider<bool>((ref) => false);
final trafficProvider = StateProvider<VlessStatus?>((ref) => null);
final vpnProvider = StateNotifierProvider<VpnNotifier, VpnState>(
  (ref) => VpnNotifier(ref),
);

class VpnNotifier extends StateNotifier<VpnState> {
  VpnNotifier(this.ref) : super(VpnState.disconnected) {
    _engine = FlutterVless(onStatusChanged: _onStatus);
  }
  final Ref ref;
  late final FlutterVless _engine;
  bool _initialized = false;
  bool _busy = false;
  int _connectAttempt = 0;
  bool _requested = false;
  bool _runtimeErrorHandled = false;
  bool _wanted = false;
  Timer? _retry;
  int _retryCount = 0;
  int _lanAttempt = 0;
  bool _sessionLanConfigured = false;
  bool _protectedSwitch = false;
  bool _switchAwaitingNative = false;
  Timer? _timeout;
  Timer? _errorTimer;
  final List<String> events = [];
  void _record(String text) {
    events.add('${DateTime.now().toIso8601String()} $text');
    if (events.length > 100) events.removeAt(0);
  }

  void _onStatus(VlessStatus status) {
    if (!mounted) return;
    if (_switchAwaitingNative &&
        status.connectionState == VlessConnectionState.connected) {
      return;
    }
    if (status.state == 'ERROR') {
      // Native runtimes may report the same error again as the tunnel is
      // stopping. Replaying _fail would restart the dismiss timer indefinitely
      // and make a single failure look permanent in the home screen.
      if (!_requested || _runtimeErrorHandled) return;
      _runtimeErrorHandled = true;
      _fail(
        'The VPN runtime failed. Check permissions and connection settings.',
      );
      unawaited(ref.read(lanProxyProvider).stop());
      // Native tunnel backends retain their traffic barrier during recovery.
      // Stopping Linux here would explicitly remove its nftables guard.
      if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux &&
          !_protectedSwitch) {
        unawaited(_stopAfterRuntimeError());
      }
      _scheduleReconnect();
      return;
    }
    if (!_requested &&
        !_wanted &&
        [
          VlessConnectionState.connected,
          VlessConnectionState.connecting,
        ].contains(status.connectionState)) {
      return;
    }
    ref.read(trafficProvider.notifier).state = status;
    final next = switch (status.connectionState) {
      VlessConnectionState.connected => VpnState.connected,
      VlessConnectionState.connecting => VpnState.connecting,
      VlessConnectionState.disconnecting => VpnState.disconnecting,
      _ => VpnState.disconnected,
    };
    if (next == VpnState.connected || next == VpnState.disconnected) {
      _timeout?.cancel();
    }
    if (next != VpnState.connected) {
      ++_lanAttempt;
      unawaited(ref.read(lanProxyProvider).stop());
    }
    if (next == VpnState.disconnected &&
        !_protectedSwitch &&
        (!_wanted || !Platform.isMacOS)) {
      ref.read(vpnTunnelMayBeActiveProvider.notifier).state = false;
    }
    if (next == VpnState.connected) {
      _requested = true;
      _retry?.cancel();
      _retryCount = 0;
      if (state != VpnState.connected) unawaited(syncLanSharing());
    }
    if (next == VpnState.disconnected && _requested) {
      _requested = false;
      _fail('VPN disconnected. Reconnect to protect your traffic.');
      _scheduleReconnect();
      return;
    }
    if (state == VpnState.error && next == VpnState.disconnected) return;
    if (state != next) _record(next.name);
    state = next;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await _engine.initializeVless(
      providerBundleIdentifier: 'com.oculve.app',
      groupIdentifier: 'group.com.oculve.app',
      // Shared Keychain references belong to the iOS Packet Tunnel backend.
      // Passing this on Android requires a capability that Android cannot have.
      keychainAccessGroup: Platform.isIOS ? 'group.com.oculve.app' : null,
    );
    _initialized = true;
  }

  /// Shared by the locations page and desktop tray. A switch never calls stop.
  Future<void> selectServer(String id) async {
    if (_busy ||
        state == VpnState.connecting ||
        state == VpnState.disconnecting) {
      return;
    }
    if (ref.read(selectedServerProvider) == id) return;
    final active = ref.read(vpnTunnelMayBeActiveProvider);
    ref.read(selectedServerProvider.notifier).state = id;
    ref.read(optimalServerProfileProvider.notifier).state = null;
    if (active) await connect(replacing: true);
  }

  Future<void> connect({bool automatic = false, bool replacing = false}) async {
    replacing = replacing ||
        _protectedSwitch ||
        (automatic && Platform.isLinux &&
            ref.read(vpnTunnelMayBeActiveProvider));
    if (_busy ||
        (!replacing && state == VpnState.connected) ||
        state == VpnState.connecting) {
      return;
    }
    if (!automatic && !replacing && ref.read(vpnTunnelMayBeActiveProvider)) {
      await disconnect();
      return;
    }
    if (replacing) _protectedSwitch = true;
    _switchAwaitingNative = replacing;
    _wanted = true;
    _retry?.cancel();
    _busy = true;
    final attempt = ++_connectAttempt;
    bool cancelled() => !mounted || attempt != _connectAttempt;
    _runtimeErrorHandled = false;
    dismissError();
    state = VpnState.connecting;
    try {
      final selected = ref.read(selectedServerProvider);
      final dpiBypass = selected == dpiBypassServerId;
      if (selected != optimalServerId) {
        ref.read(optimalServerProfileProvider.notifier).state = null;
      }
      VpnProfile? profile;
      if (!dpiBypass) {
        // Revalidate account status without downloading the subscription again.
        // DPI Bypass is client-side and does not depend on a selected Oculve node.
        await ref.read(sessionProvider.notifier).refreshAccount();
        if (cancelled()) return;
        final account = ref.read(sessionProvider).valueOrNull;
        if (account == null || !account.canConnect) {
          throw StateError('Your subscription is not active.');
        }
        if (account.profiles.isEmpty) {
          throw StateError('No compatible servers are available.');
        }
        profile = selected == optimalServerId
            ? await _chooseOptimalProfile(account.profiles)
            : account.profiles.firstWhere(
                (p) => p.id == selected,
                orElse: () => account.profiles.first,
              );
      }
      if (cancelled()) return;
      await initialize();
      if (cancelled()) return;
      final permission = automatic || replacing
          ? _initialized
          : await _engine.requestPermission();
      if (cancelled()) return;
      if (!permission) {
        throw StateError('VPN permission was not granted.');
      }
      _requested = true;
      final logLevel = await XrayPreferences.logLevel();
      final dnsSettings = await XrayPreferences.userDnsSettings();
      final bypassDomains = await XrayPreferences.bypassDomains();
      final vpnOnlyDomains = await XrayPreferences.vpnOnlyDomainsEnabled();
      final routingRules = await XrayPreferences.routingRules();
      final blockedApps = Platform.isAndroid
          ? await XrayPreferences.blockedApps()
          : const <String>[];
      final dpiStrategy = await DpiPreferences.read();
      var config = dpiBypass
          ? XrayPreferences.configureDpiBypass(
              localProxyPort: 65535,
              dpiProfile: dpiStrategy.engineProfile,
              dnsSettings: dnsSettings,
              bypassDomains: bypassDomains,
              vpnOnlyDomains: vpnOnlyDomains,
              routingRules: routingRules,
            )
          : await _configureVpnProfile(
              profile!,
              dnsSettings,
              bypassDomains,
              vpnOnlyDomains,
              logLevel,
            );
      final options = await ConnectionPreferences.read();
      _sessionLanConfigured = Platform.isMacOS && options.shareLan;
      if (_sessionLanConfigured) {
        // Replies to LAN proxy clients use protected Xray direct routing rather
        // than OS route exclusions; global IPv6/DNS protection still takes priority.
        final root = jsonDecode(config) as Map<String, dynamic>;
        final routing = root['routing'] as Map<String, dynamic>? ?? {};
        final rules = List<dynamic>.from(routing['rules'] as List? ?? []);
        final direct = (root['outbounds'] as List)
            .whereType<Map>()
            .where((o) => o['protocol'] == 'freedom')
            .firstOrNull;
        if (direct == null) {
          throw StateError('Could not configure LAN sharing.');
        }
        rules.insert(0, {
          'type': 'field',
          'ip': ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'],
          'outboundTag': direct['tag'],
        });
        routing['rules'] = rules;
        root['routing'] = routing;
        config = jsonEncode(root);
      }
      if (cancelled()) return;
      ref.read(vpnTunnelMayBeActiveProvider.notifier).state = true;
      final start = replacing ? _engine.replaceVless : _engine.startVless;
      await start(
        remark: dpiBypass ? 'DPI Bypass' : profile!.name,
        config: config,
        dpiBypass: dpiBypass,
        dpiProfile: dpiStrategy.engineProfile,
        androidDnsPolicy: Platform.isAndroid
            ? AndroidDnsPolicy.proxy
            : AndroidDnsPolicy.config,
        androidDnsProxyOutboundTag: Platform.isAndroid
            ? (dpiBypass ? 'byedpi' : 'proxy')
            : null,
        blockedApps: blockedApps,
      );
      _switchAwaitingNative = false;
      if (cancelled()) {
        try {
          await _engine.stopVless();
          if (mounted) {
            ref.read(vpnTunnelMayBeActiveProvider.notifier).state = false;
          }
        } catch (_) {
          if (mounted) {
            ref.read(vpnTunnelMayBeActiveProvider.notifier).state = true;
            _fail(
              'The VPN could not be stopped. Check the system VPN settings.',
            );
          }
        }
        return;
      }
      // A successful start call is acceptance, not proof of a working tunnel.
      // Only native forwarding readiness events can set CONNECTED.
      if (state != VpnState.connected) {
        final connectionTimeout = dpiBypass
            ? const Duration(seconds: 90)
            : const Duration(seconds: 45);
        _timeout = Timer(connectionTimeout, () async {
          if (mounted && state == VpnState.connecting) {
            if (!replacing) await disconnect();
            if (mounted) {
              _fail('Connection timed out. Please try another location.');
            }
          }
        });
      }
    } catch (error) {
      if (cancelled()) return;
      _requested = false;
      if (!automatic && !replacing) _wanted = false;
      var tunnelStopped = !_initialized;
      try {
        if (_initialized && !replacing && !(automatic && Platform.isMacOS)) {
          await _engine.stopVless();
          tunnelStopped = true;
        }
      } catch (_) {}
      if (tunnelStopped && mounted) {
        ref.read(vpnTunnelMayBeActiveProvider.notifier).state = false;
      }
      _fail(
        UserFacingFailure.message(
          error,
          fallback:
              'Could not establish the VPN. Check your account, VPN permission and server availability.',
        ),
      );
    } finally {
      _busy = false;
      if (automatic && _wanted && state != VpnState.connected) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    if (!_wanted || !mounted || _retryCount >= 5 || _retry?.isActive == true) {
      return;
    }
    final attempt = _connectAttempt;
    _retry = Timer(Duration(seconds: 3 * (1 << _retryCount)), () async {
      if (!mounted || !_wanted || attempt != _connectAttempt) return;
      if (!(await ConnectionPreferences.read()).reconnect) return;
      if (!mounted ||
          !_wanted ||
          attempt != _connectAttempt ||
          state == VpnState.connected) {
        return;
      }
      if (_busy) {
        _scheduleReconnect();
        return;
      }
      _retryCount++;
      _record('automatic reconnect attempt $_retryCount');
      await connect(automatic: true);
    });
  }

  Future<void> syncLanSharing() async {
    final attempt = ++_lanAttempt;
    final service = ref.read(lanProxyProvider);
    await service.stop();
    if (!Platform.isMacOS || !mounted) return;
    try {
      final options = await ConnectionPreferences.read();
      if (!_sessionLanConfigured ||
          !options.shareLan ||
          state != VpnState.connected ||
          !_wanted ||
          attempt != _lanAttempt) {
        return;
      }
      final addresses = await LanProxyService.addresses();
      final address = options.address.isEmpty
          ? addresses.firstOrNull
          : options.address;
      if (address == null || !addresses.contains(address)) {
        throw StateError('Local network address unavailable.');
      }
      final password = await ConnectionPreferences.password();
      if (!mounted || attempt != _lanAttempt || state != VpnState.connected) {
        return;
      }
      await service.start(
        address: address,
        port: options.port,
        username: options.username,
        password: password,
        ready: () =>
            mounted &&
            _wanted &&
            state == VpnState.connected &&
            attempt == _lanAttempt,
      );
    } catch (_) {
      if (mounted && attempt == _lanAttempt) {
        service.reportFailure(
          'Could not start LAN sharing. Check your address, port and password.',
        );
        _record('LAN sharing unavailable');
      }
    }
  }

  Future<String> _configureVpnProfile(
    VpnProfile profile,
    XrayDnsSettings dnsSettings,
    List<String> bypassDomains,
    bool vpnOnlyDomains,
    XrayLogLevel logLevel,
  ) async => XrayPreferences.configure(
    profile.config,
    profile.supportsTlsFingerprint
        ? await XrayPreferences.fingerprint()
        : RealityFingerprint.serverDefault,
    logLevel: logLevel,
    bypassDomains: bypassDomains,
    vpnOnlyDomains: vpnOnlyDomains,
    dnsSettings: dnsSettings,
    finalMaskSettings: profile.supportsTlsHelloFragmentation
        ? await XrayPreferences.userFinalMaskSettings()
        : const XrayFinalMaskSettings(),
  );

  Future<VpnProfile> _chooseOptimalProfile(List<VpnProfile> profiles) async {
    final probe = ref.read(serverLatencyProbeProvider);
    // Do not launch direct endpoint probes during a protected switch.
    final cached = ref.read(serverLatencyLastKnownProvider);
    final samples = ref.read(vpnTunnelMayBeActiveProvider)
        ? profiles.map((profile) => cached[profile.id]).toList()
        : await Future.wait(profiles.map(probe.measure));
    final latencyById = <String, int?>{
      for (var index = 0; index < profiles.length; index++)
        profiles[index].id: samples[index],
    };
    final selected = sortProfilesByLatency(profiles, latencyById).first;
    ref.read(optimalServerProfileProvider.notifier).state = selected.id;
    return selected;
  }

  void _fail(String message) {
    if (!mounted) return;
    _timeout?.cancel();
    _requested = false;
    _errorTimer?.cancel();
    ref.read(vpnErrorProvider.notifier).state = message;
    _errorTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && ref.read(vpnErrorProvider) == message) {
        ref.read(vpnErrorProvider.notifier).state = null;
        if (state == VpnState.error) {
          _record('error dismissed');
          state = VpnState.disconnected;
        }
      }
    });
    _record(message);
    state = VpnState.error;
  }

  void dismissError() {
    _errorTimer?.cancel();
    _errorTimer = null;
    if (mounted) ref.read(vpnErrorProvider.notifier).state = null;
  }

  Future<void> _stopAfterRuntimeError() async {
    try {
      if (_initialized) await _engine.stopVless();
      if (!mounted) return;
      ref.read(vpnTunnelMayBeActiveProvider.notifier).state = false;
    } catch (_) {
      // Keep direct probes disabled when native tunnel shutdown is uncertain.
    }
  }

  Future<void> disconnect() async {
    ++_connectAttempt;
    _wanted = false;
    _switchAwaitingNative = false;
    _retryCount = 0;
    _retry?.cancel();
    ++_lanAttempt;
    await ref.read(lanProxyProvider).stop();
    _timeout?.cancel();
    _requested = false;
    state = VpnState.disconnecting;
    try {
      if (_initialized) await _engine.stopVless();
      _protectedSwitch = false;
      ref.read(vpnTunnelMayBeActiveProvider.notifier).state = false;
      state = VpnState.disconnected;
    } catch (_) {
      _fail('The VPN could not be stopped. Check the system VPN settings.');
      rethrow;
    }
  }

  Future<void> toggle() async {
    if (_busy && state != VpnState.connecting) return;
    if (state == VpnState.connected || state == VpnState.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _timeout?.cancel();
    _errorTimer?.cancel();
    super.dispose();
  }
}
