import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import '../models/vpn_state.dart';
import '../vpn/xray_preferences.dart';
import '../vpn/server_latency.dart';
import '../vpn/profile.dart';
import '../../features/auth/data/auth_repository.dart';

final selectedServerProvider = StateProvider<String?>((ref) => null);
const optimalServerId = '__oculve_optimal__';
const dpiBypassServerId = '__oculve_dpi_bypass__';
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
  bool _requested = false;
  bool _runtimeErrorHandled = false;
  Timer? _timeout;
  Timer? _errorTimer;
  final List<String> events = [];
  void _record(String text) {
    events.add('${DateTime.now().toIso8601String()} $text');
    if (events.length > 100) events.removeAt(0);
  }

  void _onStatus(VlessStatus status) {
    if (!mounted) return;
    if (status.state == 'ERROR') {
      // Native runtimes may report the same error again as the tunnel is
      // stopping. Replaying _fail would restart the dismiss timer indefinitely
      // and make a single failure look permanent in the home screen.
      if (_runtimeErrorHandled) return;
      _runtimeErrorHandled = true;
      _fail(
        'The VPN runtime failed. Check permissions and connection settings.',
      );
      unawaited(_stopAfterRuntimeError());
      return;
    }
    if (!_requested &&
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
    if (next == VpnState.disconnected) {
      ref.read(vpnTunnelMayBeActiveProvider.notifier).state = false;
    }
    if (next == VpnState.disconnected && _requested) {
      _requested = false;
      _fail('VPN disconnected. Reconnect to protect your traffic.');
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
      keychainAccessGroup: 'group.com.oculve.app',
    );
    _initialized = true;
  }

  Future<void> connect() async {
    if (_busy || state == VpnState.connected || state == VpnState.connecting) {
      return;
    }
    if (ref.read(vpnTunnelMayBeActiveProvider)) {
      await disconnect();
      return;
    }
    _busy = true;
    _runtimeErrorHandled = false;
    dismissError();
    state = VpnState.connecting;
    try {
      final selected = ref.read(selectedServerProvider);
      final dpiBypass = selected == dpiBypassServerId;
      VpnProfile? profile;
      if (!dpiBypass) {
        // Revalidate account status without downloading the subscription again.
        // DPI Bypass is client-side and does not depend on a selected Oculve node.
        await ref.read(sessionProvider.notifier).refreshAccount();
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
      await initialize();
      if (!await _engine.requestPermission()) {
        throw StateError('VPN permission was not granted.');
      }
      _requested = true;
      final logLevel = await XrayPreferences.logLevel();
      final dnsSettings = await XrayPreferences.userDnsSettings();
      final bypassDomains = await XrayPreferences.bypassDomains();
      final routingRules = await XrayPreferences.routingRules();
      final blockedApps = Platform.isAndroid
          ? await XrayPreferences.blockedApps()
          : const <String>[];
      final config = dpiBypass
          ? XrayPreferences.configureDpiBypass(
              localProxyPort: 65535,
              dnsSettings: dnsSettings,
              bypassDomains: bypassDomains,
              routingRules: routingRules,
            )
          : await _configureVpnProfile(
              profile!,
              dnsSettings,
              bypassDomains,
              logLevel,
            );
      ref.read(vpnTunnelMayBeActiveProvider.notifier).state = true;
      await _engine.startVless(
        remark: dpiBypass ? 'DPI Bypass' : profile!.name,
        config: config,
        dpiBypass: dpiBypass,
        dpiProfile: 0,
        androidDnsPolicy: AndroidDnsPolicy.proxy,
        androidDnsProxyOutboundTag: dpiBypass ? 'byedpi' : 'proxy',
        blockedApps: blockedApps,
      );
      // A successful start call is acceptance, not proof of a working tunnel.
      // Only native forwarding readiness events can set CONNECTED.
      if (state != VpnState.connected) {
        final connectionTimeout = dpiBypass
            ? const Duration(seconds: 90)
            : const Duration(seconds: 45);
        _timeout = Timer(connectionTimeout, () async {
          if (mounted && state == VpnState.connecting) {
            await disconnect();
            if (mounted) {
              _fail('Connection timed out. Please try another location.');
            }
          }
        });
      }
    } catch (error) {
      _requested = false;
      var tunnelStopped = !_initialized;
      try {
        if (_initialized) {
          await _engine.stopVless();
          tunnelStopped = true;
        }
      } catch (_) {}
      if (tunnelStopped && mounted) {
        ref.read(vpnTunnelMayBeActiveProvider.notifier).state = false;
      }
      _fail(
        error is FormatException
            ? error.message.toString()
            : 'Could not establish the VPN. Check your account, VPN permission and server availability.',
      );
    } finally {
      _busy = false;
    }
  }

  Future<String> _configureVpnProfile(
    VpnProfile profile,
    XrayDnsSettings dnsSettings,
    List<String> bypassDomains,
    XrayLogLevel logLevel,
  ) async => XrayPreferences.configure(
    profile.config,
    profile.supportsTlsFingerprint
        ? await XrayPreferences.fingerprint()
        : RealityFingerprint.serverDefault,
    logLevel: logLevel,
    bypassDomains: bypassDomains,
    dnsSettings: dnsSettings,
    finalMaskSettings: profile.supportsTlsHelloFragmentation
        ? await XrayPreferences.userFinalMaskSettings()
        : const XrayFinalMaskSettings(),
  );

  Future<VpnProfile> _chooseOptimalProfile(List<VpnProfile> profiles) async {
    final probe = ref.read(serverLatencyProbeProvider);
    final samples = await Future.wait(profiles.map(probe.measure));
    final latencyById = <String, int?>{
      for (var index = 0; index < profiles.length; index++)
        profiles[index].id: samples[index],
    };
    return sortProfilesByLatency(profiles, latencyById).first;
  }

  void _fail(String message) {
    if (!mounted) return;
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
    _timeout?.cancel();
    _requested = false;
    state = VpnState.disconnecting;
    try {
      if (_initialized) await _engine.stopVless();
      ref.read(vpnTunnelMayBeActiveProvider.notifier).state = false;
      state = VpnState.disconnected;
    } catch (_) {
      _fail('The VPN could not be stopped. Check the system VPN settings.');
      rethrow;
    }
  }

  Future<void> toggle() async {
    if (_busy) return;
    if (state == VpnState.connected || state == VpnState.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _errorTimer?.cancel();
    super.dispose();
  }
}
