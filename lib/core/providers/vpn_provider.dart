import 'package:oculve/core/connection/dpi_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../connection/connection_preferences.dart';
import '../connection/lan_proxy_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import '../models/vpn_state.dart';
import '../models/user_facing_failure.dart';
import '../vpn/xray_preferences.dart';
import '../vpn/server_latency.dart';
import '../connection/server_selection_store.dart';
import '../vpn/profile.dart';
import '../../features/auth/data/auth_repository.dart';

const optimalServerId = '__oculve_optimal__';
const dpiBypassServerId = '__oculve_dpi_bypass__';
final selectedServerProvider = StateProvider<String?>((ref) => optimalServerId);
final optimalServerProfileProvider = StateProvider<String?>((ref) => null);
final vpnErrorProvider = StateProvider<String?>((ref) => null);

/// True until the native tunnel has confirmed that it stopped. Direct TCP
/// measurements must not accidentally run through an active VPN route.
final vpnTunnelMayBeActiveProvider = StateProvider<bool>((ref) => false);

/// True when the app adopted a tunnel that was already running before this app
/// session asked for one (relaunch, logout or session expiry while connected).
///
/// The tunnel is shown and can be stopped, but no reconnect or replacement is
/// scheduled for it because the user expressed no intent in this session.
final vpnTunnelAdoptedProvider = StateProvider<bool>((ref) => false);
final trafficProvider = StateProvider<VlessStatus?>((ref) => null);
final vpnProvider = StateNotifierProvider<VpnNotifier, VpnState>(
  (ref) => VpnNotifier(ref),
);

bool shouldRequestVpnPermission({
  required bool isWindows,
  required bool automatic,
  required bool replacing,
}) => isWindows || (!automatic && !replacing);

class VpnNotifier extends StateNotifier<VpnState> {
  VpnNotifier(this.ref) : super(VpnState.disconnected) {
    _engine = FlutterVless(onStatusChanged: _onStatus);
  }
  final Ref ref;
  late final FlutterVless _engine;
  bool _initialized = false;
  Future<void>? _initialization;
  bool _busy = false;
  int _connectAttempt = 0;
  Completer<void>? _optimalProbeCancellation;
  bool _requested = false;
  bool _runtimeErrorHandled = false;
  bool _wanted = false;
  bool _adopted = false;
  bool _restored = false;
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
    if (status.state == 'PERMISSION_REQUIRED') {
      ++_connectAttempt;
      _cancelOptimalProbes();
      _wanted = false;
      _requested = false;
      _protectedSwitch = false;
      _switchAwaitingNative = false;
      _retry?.cancel();
      _retryCount = 0;
      ++_lanAttempt;
      unawaited(ref.read(lanProxyProvider).stop());
      ref.read(trafficProvider.notifier).state = status;
      _fail(
        UserFacingFailure.permissionDeniedMessage(
          isWindows: Platform.isWindows,
          isLinux: Platform.isLinux,
        ),
      );
      return;
    }
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
      if (!Platform.isMacOS &&
          !Platform.isWindows &&
          !Platform.isLinux &&
          !_protectedSwitch) {
        unawaited(_stopAfterRuntimeError());
      }
      _scheduleReconnect();
      return;
    }
    if (!_requested &&
        !_wanted &&
        !_adopted &&
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
      if (_adopted) {
        // The adopted tunnel ended on its own. This session never asked for
        // it, so there is nothing to reconnect and no failure to report.
        _clearAdopted();
        _record('adopted tunnel ended');
        state = VpnState.disconnected;
        return;
      }
      _fail('VPN disconnected. Reconnect to protect your traffic.');
      _scheduleReconnect();
      return;
    }
    if (state == VpnState.error && next == VpnState.disconnected) return;
    if (state != next) _record(next.name);
    state = next;
  }

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initialization ??= _initializeEngine().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initializeEngine() async {
    // iOS reads its signing-expanded shared Keychain group from Runner's
    // Info.plist; the App Group identifier is not a Keychain access group.
    await _engine.initializeVless(
      providerBundleIdentifier: 'com.oculve.app',
      groupIdentifier: 'group.com.oculve.app',
    );
    _initialized = true;
  }

  /// Adopts a tunnel that was still running before this app session started.
  ///
  /// Leaving the app does not stop the tunnel, so the UI must show it after a
  /// relaunch. A status event cannot prove this by itself: the same CONNECTED
  /// event can arrive late after a deliberate Disconnect. Only this explicit
  /// native query marks the tunnel as adopted, and an adopted tunnel is never
  /// reconnected automatically because no user intent exists in this session.
  Future<void> restoreTunnel() async {
    if (_restored) return;
    _restored = true;
    if (_wanted || _requested || _busy) return;
    try {
      await initialize();
      if (!mounted || _wanted || _requested) return;
      // A native backend that never answers must not hold up the UI.
      final raw = await _engine.getTunnelStatus().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (!mounted || _wanted || _requested) return;
      final observed = VlessConnectionState.parse(raw);
      if (observed != VlessConnectionState.connected &&
          observed != VlessConnectionState.connecting) {
        return;
      }
      _adopted = true;
      await _restoreOptimalChoice();
      if (!mounted) return;
      ref.read(vpnTunnelAdoptedProvider.notifier).state = true;
      ref.read(vpnTunnelMayBeActiveProvider.notifier).state = true;
      _record('adopted existing tunnel ${observed.wireName}');
      _onStatus(VlessStatus(state: observed.wireName));
      if (observed == VlessConnectionState.connecting) {
        // Native reports CONNECTING until its readiness probe answers. Confirm
        // once so a missed status event cannot leave the UI on "connecting".
        Timer(const Duration(seconds: 2), () async {
          if (!mounted || !_adopted) return;
          try {
            final later = VlessConnectionState.parse(
              await _engine.getTunnelStatus(),
            );
            if (!mounted || !_adopted || later == observed) return;
            _onStatus(VlessStatus(state: later.wireName));
          } catch (_) {
            // Keep the state native already reported.
          }
        });
      }
    } catch (_) {
      // A backend without the query keeps the plain disconnected start.
    }
  }

  /// With Optimal selected, the live tunnel runs on the server Optimal picked
  /// back then; show that one instead of re-guessing from fresh pings.
  Future<void> _restoreOptimalChoice() async {
    try {
      if (ref.read(selectedServerProvider) != optimalServerId) return;
      final saved = await ServerSelectionStore.readOptimal();
      if (!mounted || saved == null) return;
      if (ref.read(optimalServerProfileProvider) == null) {
        ref.read(optimalServerProfileProvider.notifier).state = saved;
      }
    } catch (_) {
      // Showing a guess is better than failing to adopt the tunnel.
    }
  }

  void _clearAdopted() {
    if (!_adopted) return;
    _adopted = false;
    if (mounted) ref.read(vpnTunnelAdoptedProvider.notifier).state = false;
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
    replacing =
        replacing ||
        _protectedSwitch ||
        (automatic &&
            Platform.isLinux &&
            ref.read(vpnTunnelMayBeActiveProvider));
    if (_busy ||
        (!replacing && state == VpnState.connected) ||
        state == VpnState.connecting ||
        state == VpnState.disconnecting) {
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
    _record('connection preparation started');
    try {
      final selected = ref.read(selectedServerProvider);
      final dpiBypass = selected == dpiBypassServerId;
      if (selected != optimalServerId) {
        ref.read(optimalServerProfileProvider.notifier).state = null;
      }
      VpnProfile? profile;
      if (!dpiBypass) {
        // Revalidate account status without downloading the subscription again,
        // and select the endpoint at the same time: the profiles are already
        // known, so the latency probe does not have to wait for /api/user/me.
        // DPI Bypass is client-side and does not depend on a selected Oculve node.
        final knownProfiles =
            ref.read(sessionProvider).valueOrNull?.profiles ??
            const <VpnProfile>[];
        final refreshTimer = Stopwatch()..start();
        final selectionTimer = Stopwatch()..start();
        final refresh = ref.read(sessionProvider.notifier).refreshAccount();
        final selection =
            selected == optimalServerId && knownProfiles.isNotEmpty
            ? _chooseOptimalProfile(knownProfiles, cancelled)
            : Future<VpnProfile?>.value(null);
        // eagerError keeps the original failure (for example an expired
        // session) instead of wrapping it in a parallel-wait error.
        final results = await Future.wait<Object?>([
          refresh,
          selection,
        ], eagerError: true);
        _record(
          'account refresh finished in ${refreshTimer.elapsedMilliseconds}ms',
        );
        _record(
          'Optimal server selection completed in ${selectionTimer.elapsedMilliseconds}ms',
        );
        if (cancelled()) return;
        final account = ref.read(sessionProvider).valueOrNull;
        if (account == null || !account.canConnect) {
          throw StateError('Your subscription is not active.');
        }
        if (account.profiles.isEmpty) {
          throw StateError('No compatible servers are available.');
        }
        var chosen = results[1] as VpnProfile?;
        if (selected == optimalServerId && chosen == null) {
          // No profile list was cached when the probe would have started, so
          // the selection runs after the refresh instead of in parallel.
          final lateTimer = Stopwatch()..start();
          try {
            chosen = await _chooseOptimalProfile(account.profiles, cancelled);
          } finally {
            _record(
              'Optimal server selection completed in ${lateTimer.elapsedMilliseconds}ms',
            );
          }
          if (cancelled()) return;
        }
        // The refresh can replace the profile list; resolve the selection
        // against the refreshed list so a removed server cannot be started.
        final wantedId = selected == optimalServerId ? chosen?.id : selected;
        profile = account.profiles.firstWhere(
          (p) => p.id == wantedId,
          orElse: () => account.profiles.first,
        );
      }
      if (cancelled()) return;
      await initialize();
      if (cancelled()) return;
      final permission =
          shouldRequestVpnPermission(
            isWindows: Platform.isWindows,
            automatic: automatic,
            replacing: replacing,
          )
          ? await _engine.requestPermission()
          : _initialized;
      if (cancelled()) return;
      if (!permission) {
        throw StateError(
          UserFacingFailure.permissionDeniedMessage(
            isWindows: Platform.isWindows,
            isLinux: Platform.isLinux,
          ),
        );
      }
      _requested = true;
      // Independent preference reads: run them together so the tunnel start is
      // not delayed by a serial chain of SharedPreferences round trips.
      final (
        logLevel,
        dnsSettings,
        bypassDomains,
        vpnOnlyDomains,
        routingRules,
        blockedApps,
        dpiStrategy,
        options,
      ) = await (
        XrayPreferences.logLevel(),
        XrayPreferences.userDnsSettings(),
        XrayPreferences.bypassDomains(),
        XrayPreferences.vpnOnlyDomainsEnabled(),
        XrayPreferences.routingRules(),
        Platform.isAndroid
            ? XrayPreferences.blockedApps()
            : Future<List<String>>.value(const <String>[]),
        DpiPreferences.read(),
        ConnectionPreferences.read(),
      ).wait;
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
      if (!dpiBypass) {
        // The account can lapse while the config is prepared; never arm the
        // native tunnel for a subscription that can no longer connect.
        final current = ref.read(sessionProvider).valueOrNull;
        if (current == null || !current.canConnect) {
          throw StateError('Your subscription is not active.');
        }
      }
      ref.read(vpnTunnelMayBeActiveProvider.notifier).state = true;
      final start = replacing ? _engine.replaceVless : _engine.startVless;
      final nativeStartTimer = Stopwatch()..start();
      try {
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
      } finally {
        _record(
          'native start request finished in ${nativeStartTimer.elapsedMilliseconds}ms',
        );
      }
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
            if (!replacing) {
              final stoppingAttempt = _connectAttempt + 1;
              try {
                await disconnect();
              } catch (_) {
                // disconnect already reports the native shutdown failure and
                // retains the traffic barrier; a timer has no caller to rethrow to.
                return;
              }
              if (!mounted || _connectAttempt != stoppingAttempt) return;
            }
            if (mounted) {
              _fail('Connection timed out. Please try another location.');
            }
          }
        });
      }
    } catch (error) {
      if (cancelled()) return;
      _requested = false;
      final platformSetupRequired = UserFacingFailure.requiresPlatformSetup(
        error: error,
        isWindows: Platform.isWindows,
        isLinux: Platform.isLinux,
      );
      final permissionRequired =
          (error is PlatformException &&
              error.code == 'VPN_PERMISSION_REQUIRED') ||
          platformSetupRequired;
      if (permissionRequired) {
        _wanted = false;
        _protectedSwitch = false;
        _switchAwaitingNative = false;
        _retry?.cancel();
        _retryCount = 0;
      }
      if (!automatic && !replacing) _wanted = false;
      var tunnelStopped = !_initialized;
      try {
        if (_initialized &&
            (permissionRequired ||
                (!replacing && !(automatic && Platform.isMacOS)))) {
          await _engine.stopVless();
          tunnelStopped = true;
        }
      } catch (_) {}
      // Shutdown may finish after a user cancellation. Its old failure must
      // not overwrite the newer connection intent or tunnel state.
      if (cancelled()) return;
      if (tunnelStopped && mounted) {
        ref.read(vpnTunnelMayBeActiveProvider.notifier).state = false;
      }
      // A failed protected switch must not swallow later native connected
      // statuses: while _switchAwaitingNative stays set, _onStatus ignores
      // every connected event and the UI looks permanently unresponsive.
      // Reset only after the stop attempt above so a stale connected status
      // from the old session cannot be adopted mid-teardown.
      _switchAwaitingNative = false;
      _fail(
        UserFacingFailure.message(
          error,
          fallback:
              'Could not establish the VPN. Check your account, VPN permission and server availability.',
        ),
      );
    } finally {
      _busy = false;
      if (mounted && automatic && _wanted && state != VpnState.connected) {
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

  Future<VpnProfile> _chooseOptimalProfile(
    List<VpnProfile> profiles,
    bool Function() cancelled,
  ) async {
    final probe = ref.read(serverLatencyProbeProvider);
    // Do not launch direct endpoint probes during a protected switch.
    final cached = ref.read(serverLatencyLastKnownProvider);
    final measuredAt = ref.read(serverLatencyLastMeasuredAtProvider);
    final now = DateTime.now();
    final tunnelMayBeActive = ref.read(vpnTunnelMayBeActiveProvider);
    final freshSamples = <String, int?>{
      for (final profile in profiles)
        profile.id:
            hasFreshServerLatencySample(
              cached[profile.id],
              measuredAt[profile.id],
              now: now,
            )
            ? cached[profile.id]
            : null,
    };
    final cancellation = Completer<void>();
    _optimalProbeCancellation = cancellation;
    late final List<int?> samples;
    try {
      if (tunnelMayBeActive) {
        samples = profiles.map((profile) => cached[profile.id]).toList();
      } else {
        samples = await Future.wait(
          profiles.map((profile) async {
            final known = freshSamples[profile.id];
            if (known != null) return known;
            final measured = await probe.measure(
              profile,
              shouldContinue: () => !cancelled(),
              cancellation: cancellation.future,
            );
            if (!cancelled() && measured != null && measured > 0) {
              rememberServerLatency(ref, profile.id, measured);
            }
            return measured;
          }),
        );
      }
    } finally {
      if (identical(_optimalProbeCancellation, cancellation)) {
        _optimalProbeCancellation = null;
      }
    }
    // The connection may have been cancelled while selecting its endpoint.
    if (cancelled()) return profiles.first;
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
    _cancelOptimalProbes();
    ++_connectAttempt;
    _wanted = false;
    _switchAwaitingNative = false;
    _clearAdopted();
    _retryCount = 0;
    _retry?.cancel();
    ++_lanAttempt;
    await ref.read(lanProxyProvider).stop();
    if (!mounted) return;
    _timeout?.cancel();
    _requested = false;
    state = VpnState.disconnecting;
    try {
      if (_initialized) await _engine.stopVless();
      if (!mounted) return;
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

  void _cancelOptimalProbes() {
    final cancellation = _optimalProbeCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
  }

  @override
  void dispose() {
    _cancelOptimalProbes();
    _retry?.cancel();
    _timeout?.cancel();
    _errorTimer?.cancel();
    super.dispose();
  }
}
