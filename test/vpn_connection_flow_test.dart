import 'dart:async';
import 'dart:io';

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

// Characterization tests for the connection-state flow of VpnNotifier
// (connect / disconnect / toggle / protected switch / cancel / native error
// and vpnTunnelMayBeActiveProvider). They pin CURRENT behaviour; the suites in
// vpn_state_test.dart and vpn_lifecycle_test.dart cover the remaining cases.

class _FailingStopPlatform extends TestPlatform {
  bool failStop = false;
  @override
  Future<void> stopVless() async {
    if (failStop) {
      stops++;
      throw StateError('Stop refused');
    }
    return super.stopVless();
  }
}

class _InstantProbe extends ServerLatencyProbe {
  @override
  Future<int?> measure(
    VpnProfile profile, {
    bool Function()? shouldContinue,
    Future<void>? cancellation,
  }) async => 10;
}

void main() {
  late _FailingStopPlatform platform;
  late ProviderContainer container;
  late VpnNotifier controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    platform = _FailingStopPlatform();
    VlessPlatform.instance = platform;
    container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(TestApi()),
        serverLatencyProbeProvider.overrideWithValue(_InstantProbe()),
      ],
    );
    await container.read(sessionProvider.notifier).refresh();
    controller = container.read(vpnProvider.notifier);
  });
  tearDown(() => container.dispose());

  Future<void> connected() async {
    await controller.connect();
    platform.emit(VlessStatus(state: 'CONNECTED'));
    expect(container.read(vpnProvider), VpnState.connected);
  }

  test('initial state is disconnected, Optimal and not tunnel-active', () {
    expect(container.read(vpnProvider), VpnState.disconnected);
    expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
    expect(container.read(vpnErrorProvider), isNull);
    expect(container.read(selectedServerProvider), optimalServerId);
    expect(container.read(optimalServerProfileProvider), isNull);
    expect(container.read(trafficProvider), isNull);
  });

  test(
    'connect marks the tunnel possibly active before native confirms',
    () async {
      await controller.connect();
      expect(platform.starts, 1);
      expect(container.read(vpnProvider), VpnState.connecting);
      expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
      // Optimal selection publishes the chosen profile id.
      expect(container.read(optimalServerProfileProvider), isNotNull);
    },
  );

  test('state sequence over a full connect and manual disconnect', () async {
    final seen = <VpnState>[];
    container.listen(vpnProvider, (_, next) => seen.add(next));
    await connected();
    await controller.disconnect();
    expect(seen, [
      VpnState.connecting,
      VpnState.connected,
      VpnState.disconnecting,
      VpnState.disconnected,
    ]);
    expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
    expect(container.read(vpnErrorProvider), isNull);
  });

  test(
    'connected status publishes traffic; native connecting and disconnecting map to state',
    () async {
      await controller.connect();
      platform.emit(VlessStatus(state: 'CONNECTING'));
      expect(container.read(vpnProvider), VpnState.connecting);
      platform.emit(VlessStatus(state: 'CONNECTED', duration: 5));
      expect(container.read(trafficProvider)?.state, 'CONNECTED');
      platform.emit(VlessStatus(state: 'DISCONNECTING'));
      expect(container.read(vpnProvider), VpnState.disconnecting);
    },
  );

  test(
    'unsolicited connected/connecting status is ignored (no user intent)',
    () async {
      await controller.initialize();
      platform.emit(VlessStatus(state: 'CONNECTED'));
      platform.emit(VlessStatus(state: 'CONNECTING'));
      expect(container.read(vpnProvider), VpnState.disconnected);
      expect(container.read(trafficProvider), isNull);
      expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
    },
  );

  test(
    'toggle connects, then disconnects from connecting and connected',
    () async {
      await controller.toggle();
      expect(platform.starts, 1);
      expect(container.read(vpnProvider), VpnState.connecting);
      await controller.toggle(); // connecting -> disconnect
      expect(platform.stops, 1);
      expect(container.read(vpnProvider), VpnState.disconnected);
      await connected();
      await controller.toggle(); // connected -> disconnect
      expect(platform.stops, 2);
      expect(container.read(vpnProvider), VpnState.disconnected);
    },
  );

  test('a second connect while one is preparing is ignored', () async {
    platform.permissionGate = Completer<bool>();
    final first = controller.connect();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await controller.connect();
    platform.permissionGate!.complete(true);
    await first;
    expect(platform.starts, 1);
  });

  test(
    'native start failure stops the tunnel and releases the barrier',
    () async {
      platform.startFailure = StateError('boom');
      await controller.connect();
      expect(platform.starts, 1);
      expect(platform.stops, 1);
      expect(container.read(vpnProvider), VpnState.error);
      expect(container.read(vpnErrorProvider), isNotNull);
      expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
    },
  );

  test(
    'replacement skips the permission prompt and keeps the barrier on failure',
    () async {
      await connected();
      platform.permission = false; // would fail a normal connect
      platform.replacementFailure = StateError('replace failed');
      await controller.selectServer(dpiBypassServerId);
      expect(platform.replacements, 1);
      expect(platform.stops, 0);
      expect(container.read(vpnProvider), VpnState.error);
      expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
    },
  );

  test(
    'selecting a server while disconnected only changes the selection',
    () async {
      container.read(optimalServerProfileProvider.notifier).state = 'stale';
      await controller.selectServer(dpiBypassServerId);
      expect(container.read(selectedServerProvider), dpiBypassServerId);
      expect(container.read(optimalServerProfileProvider), isNull);
      expect(platform.starts, 0);
      expect(platform.replacements, 0);
    },
  );

  test('selecting a server while connecting is ignored', () async {
    await controller.connect();
    expect(container.read(vpnProvider), VpnState.connecting);
    await controller.selectServer(dpiBypassServerId);
    expect(container.read(selectedServerProvider), optimalServerId);
    expect(platform.replacements, 0);
  });

  test(
    'a disconnected status during a protected switch keeps the barrier',
    () async {
      await connected();
      await controller.selectServer(dpiBypassServerId);
      expect(platform.replacements, 1);
      platform.emit(VlessStatus()); // old session reports it ended
      expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
    },
  );

  test('cancelling a pending protected switch stops the tunnel twice', () async {
    // Mevcut davranış: disconnect() stops once; when the accepted replace call
    // returns, the cancelled branch issues a second stopVless.
    await connected();
    platform.startGate = Completer<void>();
    final pending = controller.selectServer(dpiBypassServerId);
    while (platform.replacements == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await controller.disconnect();
    expect(platform.stops, 1);
    platform.startGate!.complete();
    await pending;
    expect(platform.stops, 2);
    expect(container.read(vpnProvider), VpnState.disconnected);
    expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
    expect(container.read(vpnErrorProvider), isNull);
  });

  test(
    'failed stop keeps the barrier; manual connect retries the stop instead of starting',
    () async {
      // Mevcut davranış: with the tunnel possibly active, a non-replacing manual
      // connect() is turned into disconnect().
      await connected();
      platform.failStop = true;
      await expectLater(controller.disconnect(), throwsStateError);
      expect(container.read(vpnProvider), VpnState.error);
      expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
      platform.failStop = false;
      await controller.connect();
      expect(platform.starts, 1);
      expect(platform.stops, 2);
      expect(container.read(vpnProvider), VpnState.disconnected);
      expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
    },
  );

  test(
    'runtime error while connected surfaces a failure and never retries when reconnect is off',
    () async {
      await (await SharedPreferences.getInstance()).setBool(
        'connection.reconnect',
        false,
      );
      await connected();
      platform.emit(VlessStatus(state: 'ERROR'));
      expect(container.read(vpnProvider), VpnState.error);
      expect(
        container.read(vpnErrorProvider),
        'The VPN runtime failed. Check permissions and connection settings.',
      );
      await Future<void>.delayed(Duration.zero);
      // Mevcut davranış: Apple/desktop runtimes keep their barrier; only
      // Android (and others) stop the tunnel after a runtime error.
      final keepsBarrier =
          Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      expect(platform.stops, keepsBarrier ? 0 : 1);
      expect(container.read(vpnTunnelMayBeActiveProvider), keepsBarrier);
    },
  );

  testWidgets(
    'a connection that never becomes connected times out, stops and fails',
    (tester) async {
      await (await SharedPreferences.getInstance()).setBool(
        'connection.reconnect',
        false,
      );
      await controller.connect();
      expect(container.read(vpnProvider), VpnState.connecting);
      await tester.pump(const Duration(seconds: 44));
      expect(container.read(vpnProvider), VpnState.connecting);
      await tester.pump(const Duration(seconds: 2));
      for (var i = 0; i < 20; i++) {
        await tester.pump();
      }
      expect(platform.stops, 1);
      expect(container.read(vpnProvider), VpnState.error);
      expect(
        container.read(vpnErrorProvider),
        'Connection timed out. Please try another location.',
      );
      expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
      controller.dismissError();
    },
  );
}
