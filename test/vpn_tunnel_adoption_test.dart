import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vpn_state_test.dart' show TestApi, TestPlatform;

// A tunnel survives the app being closed, so a relaunch must show it. Adoption
// is an explicit native query; a late CONNECTED event after a deliberate
// Disconnect must still be ignored (see vpn_connection_flow_test.dart).

/// Records that the latency probe ran while the account refresh was pending.
class _ProbeSignallingRefresh extends ServerLatencyProbe {
  _ProbeSignallingRefresh(this.probeStarted);

  final Completer<void> probeStarted;

  @override
  Future<int?> measure(
    VpnProfile profile, {
    bool Function()? shouldContinue,
    Future<void>? cancellation,
  }) async {
    if (!probeStarted.isCompleted) probeStarted.complete();
    return 10;
  }
}

/// Holds the connect-time account refresh until the probe has started. A serial
/// implementation would never release it, so the test fails instead of passing.
class _GatedRefreshApi extends TestApi {
  _GatedRefreshApi(this.probeStarted);

  final Completer<void> probeStarted;

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async {
    // The first request is the session restore in setUp; only the connect-time
    // revalidation waits for the parallel probe.
    if (path == '/api/user/me' && requests.isNotEmpty) {
      await probeStarted.future;
    }
    return super.request(path, body: body, method: method, headers: headers);
  }
}

void main() {
  late TestPlatform platform;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    platform = TestPlatform();
    VlessPlatform.instance = platform;
    container = ProviderContainer(
      overrides: [apiProvider.overrideWithValue(TestApi())],
    );
    await container.read(sessionProvider.notifier).refresh();
  });
  tearDown(() => container.dispose());

  test('a tunnel left running before startup is adopted and shown', () async {
    platform.tunnelStatus = 'CONNECTED';

    await container.read(vpnProvider.notifier).restoreTunnel();

    expect(container.read(vpnProvider), VpnState.connected);
    expect(container.read(vpnTunnelAdoptedProvider), isTrue);
    // Direct latency probes must stay off while that tunnel routes traffic.
    expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
    expect(platform.starts, 0);
    expect(platform.stops, 0);
  });

  test('an adopted tunnel can be disconnected', () async {
    platform.tunnelStatus = 'CONNECTED';
    final controller = container.read(vpnProvider.notifier);
    await controller.restoreTunnel();

    await controller.disconnect();

    expect(platform.stops, 1);
    expect(container.read(vpnProvider), VpnState.disconnected);
    expect(container.read(vpnTunnelAdoptedProvider), isFalse);
    expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
    expect(container.read(vpnErrorProvider), isNull);
  });

  test('adoption accepts the later connected event of a live tunnel', () async {
    platform.tunnelStatus = 'CONNECTING';

    await container.read(vpnProvider.notifier).restoreTunnel();
    expect(container.read(vpnProvider), VpnState.connecting);

    platform.emit(VlessStatus(state: 'CONNECTED'));
    expect(container.read(vpnProvider), VpnState.connected);
  });

  test('an adopted tunnel that ends is not reported as a failure', () async {
    platform.tunnelStatus = 'CONNECTED';
    await container.read(vpnProvider.notifier).restoreTunnel();

    platform.emit(VlessStatus(state: 'DISCONNECTED'));

    expect(container.read(vpnProvider), VpnState.disconnected);
    expect(container.read(vpnErrorProvider), isNull);
    expect(container.read(vpnTunnelAdoptedProvider), isFalse);
    expect(platform.starts, 0);
  });

  test(
    'a late connected event after a manual disconnect stays ignored',
    () async {
      final controller = container.read(vpnProvider.notifier);
      await controller.connect();
      platform.emit(VlessStatus(state: 'CONNECTED'));
      await controller.disconnect();

      platform.emit(VlessStatus(state: 'CONNECTED'));

      expect(container.read(vpnProvider), VpnState.disconnected);
      expect(container.read(vpnTunnelAdoptedProvider), isFalse);
    },
  );

  test('no tunnel is adopted when native cannot report one', () async {
    platform.tunnelStatus = null;

    await container.read(vpnProvider.notifier).restoreTunnel();

    expect(container.read(vpnProvider), VpnState.disconnected);
    expect(container.read(vpnTunnelAdoptedProvider), isFalse);
    expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
  });

  test('a disconnected native answer is not adopted', () async {
    platform.tunnelStatus = 'DISCONNECTED';

    await container.read(vpnProvider.notifier).restoreTunnel();

    expect(container.read(vpnProvider), VpnState.disconnected);
    expect(container.read(vpnTunnelAdoptedProvider), isFalse);
  });

  test('account refresh and Optimal selection run concurrently', () async {
    final probeStarted = Completer<void>();
    container.dispose();
    container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(_GatedRefreshApi(probeStarted)),
        serverLatencyProbeProvider.overrideWithValue(
          _ProbeSignallingRefresh(probeStarted),
        ),
      ],
    );
    await container.read(sessionProvider.notifier).refresh();
    container.read(selectedServerProvider.notifier).state = optimalServerId;

    await container
        .read(vpnProvider.notifier)
        .connect()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail(
            'The account refresh waited for the latency probe, so the two were '
            'still serialized.',
          ),
        );

    expect(probeStarted.isCompleted, isTrue);
    expect(platform.starts, 1);
    expect(container.read(optimalServerProfileProvider), isNotNull);
  });
}
