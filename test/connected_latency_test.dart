import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/vpn/connected_latency.dart';

class _FakeVpn extends VpnNotifier {
  _FakeVpn(super.ref);
  void emit(VpnState next) => state = next;
}

class _ScriptedProbe implements ConnectedLatencyProbe {
  final results = <Future<int?> Function()>[];
  int calls = 0;

  @override
  Future<int?> measure() {
    calls++;
    return results.isEmpty ? Future.value(null) : results.removeAt(0)();
  }
}

void main() {
  group('HttpConnectedLatencyProbe', () {
    late HttpServer server;
    late int requests;

    setUp(() async {
      requests = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    });
    tearDown(() => server.close(force: true));

    test(
      'times round trips on one kept-alive connection, after a warm-up',
      () async {
        final connections = <int>{};
        server.listen((request) async {
          requests++;
          connections.add(request.connectionInfo!.remotePort);
          await Future<void>.delayed(const Duration(milliseconds: 40));
          request.response.statusCode = 204;
          await request.response.close();
        });
        final probe = HttpConnectedLatencyProbe(
          url: 'http://127.0.0.1:${server.port}/generate_204',
          samples: 3,
        );

        final ms = await probe.measure();

        expect(ms, isNotNull);
        expect(ms!, inInclusiveRange(30, 400));
        expect(requests, 4, reason: 'one warm-up plus three timed samples');
        expect(connections.length, 1, reason: 'all on the same connection');
      },
    );

    test('a path that does not answer yields no number', () async {
      server.listen((request) async {
        request.response.statusCode = 500;
        await request.response.close();
      });
      final probe = HttpConnectedLatencyProbe(
        url: 'http://127.0.0.1:${server.port}/',
        timeout: const Duration(milliseconds: 300),
      );
      expect(await probe.measure(), isNull);
    });

    test('a dead endpoint is reported as no number, not an error', () async {
      final port = server.port;
      await server.close(force: true);
      final probe = HttpConnectedLatencyProbe(
        url: 'http://127.0.0.1:$port/',
        timeout: const Duration(milliseconds: 300),
      );
      expect(await probe.measure(), isNull);
      // Re-bind so tearDown has something to close.
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    });
  });

  group('ConnectedLatencyNotifier', () {
    late _FakeVpn vpn;
    late ProviderContainer container;
    late _ScriptedProbe probe;

    setUp(() {
      probe = _ScriptedProbe();
      container = ProviderContainer(
        overrides: [
          vpnProvider.overrideWith((ref) => vpn = _FakeVpn(ref)),
          connectedLatencyProbeProvider.overrideWithValue(probe),
        ],
      );
      addTearDown(container.dispose);
    });

    ConnectedLatencyNotifier notifier() => ConnectedLatencyNotifier(
      container.read(Provider((ref) => ref)),
      probe,
      firstDelay: const Duration(milliseconds: 20),
      interval: const Duration(milliseconds: 60),
    );

    Future<void> wait([int ms = 40]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    test('stays empty and never probes while not connected', () async {
      final live = notifier();
      addTearDown(live.dispose);
      vpn.emit(VpnState.disconnected);
      vpn.emit(VpnState.connecting);
      await wait(120);
      expect(live.state, isNull);
      expect(probe.calls, 0);
    });

    test('measures shortly after connecting and keeps refreshing', () async {
      probe.results
        ..add(() async => 42)
        ..add(() async => 55);
      final live = notifier();
      addTearDown(live.dispose);

      vpn.emit(VpnState.connected);
      await wait(50);
      expect(live.state, 42);
      await wait(100);
      expect(live.state, 55);
      expect(probe.calls, greaterThanOrEqualTo(2));
    });

    test('forgets the value and stops when the connection ends', () async {
      probe.results.add(() async => 42);
      final live = notifier();
      addTearDown(live.dispose);
      vpn.emit(VpnState.connected);
      await wait(50);
      expect(live.state, 42);

      vpn.emit(VpnState.disconnecting);
      expect(live.state, isNull);
      final callsAtStop = probe.calls;
      await wait(150);
      expect(probe.calls, callsAtStop, reason: 'no probing after disconnect');
    });

    test(
      'a slow result from an earlier connection is never published',
      () async {
        final slow = Completer<int?>();
        probe.results.add(() => slow.future);
        final live = notifier();
        addTearDown(live.dispose);

        vpn.emit(VpnState.connected);
        await wait(40); // the first probe is now waiting on `slow`
        vpn.emit(VpnState.disconnected);
        slow.complete(999);
        await wait(40);

        expect(live.state, isNull);
      },
    );

    test('a failed measurement keeps the last good value', () async {
      probe.results
        ..add(() async => 42)
        ..add(() async => null);
      final live = notifier();
      addTearDown(live.dispose);
      vpn.emit(VpnState.connected);
      await wait(100);
      expect(live.state, 42);
    });
  });
}
