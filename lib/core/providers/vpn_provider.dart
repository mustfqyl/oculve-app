import 'dart:async';
import 'dart:io';
import '../vpn/linux_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import '../models/vpn_state.dart';
import '../vpn/xray_preferences.dart';
import '../vpn/server_latency.dart';
import '../vpn/profile.dart';
import '../../features/auth/data/auth_repository.dart';

final selectedServerProvider = StateProvider<String?>((ref) => null);
const optimalServerId = '__oculve_optimal__';
final vpnErrorProvider = StateProvider<String?>((ref) => null);
final trafficProvider = StateProvider<VlessStatus?>((ref) => null);
final vpnProvider = StateNotifierProvider<VpnNotifier, VpnState>(
  (ref) => VpnNotifier(ref),
);

class VpnNotifier extends StateNotifier<VpnState> {
  VpnNotifier(this.ref) : super(VpnState.disconnected) {
    if (Platform.isLinux) VlessPlatform.instance = LinuxXrayPlatform();
    _engine = FlutterVless(onStatusChanged: _onStatus);
  }
  final Ref ref;
  late final FlutterVless _engine;
  bool _initialized = false;
  bool _busy = false;
  bool _requested = false;
  Timer? _timeout;
  final List<String> events = [];
  void _record(String text) {
    events.add('${DateTime.now().toIso8601String()} $text');
    if (events.length > 100) events.removeAt(0);
  }

  void _onStatus(VlessStatus status) {
    if (!mounted) return;
    if (status.state == 'ERROR') {
      _fail(
        'The VPN runtime failed. Check permissions and connection settings.',
      );
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
    _busy = true;
    ref.read(vpnErrorProvider.notifier).state = null;
    state = VpnState.connecting;
    try {
      // Revalidate account status without downloading the subscription again.
      // The server list is refreshed during session restore/sign-in; connecting
      // must not trigger another HWID-gated subscription request.
      await ref.read(sessionProvider.notifier).refreshAccount();
      final account = ref.read(sessionProvider).valueOrNull;
      if (account == null || !account.canConnect) {
        throw StateError('Your subscription is not active.');
      }
      if (account.profiles.isEmpty) {
        throw StateError('No compatible servers are available.');
      }
      final selected = ref.read(selectedServerProvider);
      final profile = selected == optimalServerId
          ? await _chooseOptimalProfile(account.profiles)
          : account.profiles.firstWhere(
              (p) => p.id == selected,
              orElse: () => account.profiles.first,
            );
      await initialize();
      if (!await _engine.requestPermission()) {
        throw StateError('VPN permission was not granted.');
      }
      _requested = true;
      final fingerprint = await XrayPreferences.fingerprint();
      final tlsSettings = await XrayPreferences.tlsSettings();
      final logLevel = await XrayPreferences.logLevel();
      final dnsSettings = await XrayPreferences.dnsSettings();
      final xhttpSettings = await XrayPreferences.xhttpSettings();
      final policySettings = await XrayPreferences.policySettings();
      final tcpSettings = await XrayPreferences.tcpSettings();
      final muxSettings = await XrayPreferences.muxSettings();
      final sniffingSettings = await XrayPreferences.sniffingSettings();
      final versionRequirement = await XrayPreferences.versionRequirement();
      final finalMaskSettings = await XrayPreferences.finalMaskSettings();
      final customConfigOverrides =
          await XrayPreferences.customConfigOverrides();
      final vlessEncryptionSettings = profile.proxyProtocol == 'vless'
          ? await XrayPreferences.vlessEncryptionSettingsFor(profile.id)
          : null;
      final bypassDomains = await XrayPreferences.bypassDomains();
      final routingRules = await XrayPreferences.routingRules();
      final blockedApps = Platform.isAndroid
          ? await XrayPreferences.blockedApps()
          : const <String>[];
      await _engine.startVless(
        remark: profile.name,
        config: XrayPreferences.configure(
          profile.config,
          fingerprint,
          tlsSettings: tlsSettings,
          logLevel: logLevel,
          bypassDomains: bypassDomains,
          routingRules: routingRules,
          dnsSettings: dnsSettings,
          xhttpSettings: xhttpSettings,
          policySettings: policySettings,
          tcpSettings: tcpSettings,
          muxSettings: muxSettings,
          vlessEncryptionSettings: vlessEncryptionSettings,
          sniffingSettings: sniffingSettings,
          versionRequirement: versionRequirement,
          finalMaskSettings: finalMaskSettings,
          customConfigOverrides: customConfigOverrides,
        ),
        androidDnsPolicy: AndroidDnsPolicy.proxy,
        androidDnsProxyOutboundTag: 'proxy',
        blockedApps: blockedApps,
      );
      // A successful start call is acceptance, not proof of a working tunnel.
      // Only native forwarding readiness events can set CONNECTED.
      if (state != VpnState.connected) {
        _timeout = Timer(const Duration(seconds: 45), () async {
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
      try {
        if (_initialized) await _engine.stopVless();
      } catch (_) {}
      _fail(
        error is FormatException
            ? error.message.toString()
            : 'Could not establish the VPN. Check your account, VPN permission and server availability.',
      );
    } finally {
      _busy = false;
    }
  }

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
    ref.read(vpnErrorProvider.notifier).state = message;
    _record(message);
    state = VpnState.error;
  }

  Future<void> disconnect() async {
    _timeout?.cancel();
    _requested = false;
    state = VpnState.disconnecting;
    try {
      if (_initialized) await _engine.stopVless();
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
    super.dispose();
  }
}
