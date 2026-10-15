import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/home/presentation/home_screen.dart';
import 'package:oculve/features/home/presentation/server_selection_screen.dart';
import 'package:oculve/features/home/presentation/widgets/country_icon.dart';
import 'package:oculve/features/home/presentation/widgets/dpi_bypass_logo.dart';
import 'package:oculve/features/home/presentation/widgets/server_card.dart';

import 'profile_test.dart' show testLink;

VpnProfile _profile(String id) =>
    VpnProfile(id: id, name: id, flag: null, config: '{}');

class _SessionWithServers extends SessionController {
  int refreshes = 0;
  _SessionWithServers() : super(OculveApi()) {
    state = AsyncValue.data(
      Account({}, [
        VpnProfile(id: 'slow', name: 'Amsterdam', flag: '🇳🇱', config: '{}'),
        VpnProfile(id: 'fast', name: 'Zurich', flag: '🇨🇭', config: '{}'),
      ]),
    );
  }
  @override
  Future<void> refresh() async {
    refreshes++;
  }
}

class _FixedProbe extends ServerLatencyProbe {
  @override
  Future<int?> measure(
    VpnProfile profile, {
    bool Function()? shouldContinue,
    Future<void>? cancellation,
  }) async => profile.id == 'fast' ? 25 : 180;
}

class _GatedProbe extends ServerLatencyProbe {
  final gates = {'fast': Completer<int?>(), 'slow': Completer<int?>()};

  @override
  Future<int?> measure(
    VpnProfile profile, {
    bool Function()? shouldContinue,
    Future<void>? cancellation,
  }) => gates[profile.id]!.future;
}

class _ConnectedVpnNotifier extends VpnNotifier {
  _ConnectedVpnNotifier(super.ref) {
    state = VpnState.connected;
  }
}

class _ErrorVpnNotifier extends VpnNotifier {
  _ErrorVpnNotifier(super.ref) {
    state = VpnState.error;
  }
}

void main() {
  test('cancelled queued ping skips network and releases its slot', () async {
    final profile = VpnProfile.parseSubscription(testLink).single;
    final gates = List.generate(3, (_) => Completer<int?>());
    var calls = 0;
    var active = true;
    final probe = ServerLatencyProbe(
      useAndroidNativePing: true,
      androidNativeRttSampler: (_, _) {
        final index = calls++;
        return index < gates.length ? gates[index].future : Future.value(12);
      },
    );
    final running = List.generate(3, (_) => probe.measure(profile));
    final obsolete = probe.measure(profile, shouldContinue: () => active);
    final next = probe.measure(profile);
    expect(calls, 3);
    active = false;
    gates.first.complete(20);
    expect(await obsolete, isNull);
    expect(await next, 12);
    expect(calls, 4);
    for (final gate in gates.skip(1)) {
      gate.complete(20);
    }
    await Future.wait(running);
    expect(await probe.measure(profile), 12);
  });

  test(
    'large DNS answer sets keep at most three address probes active',
    () async {
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', 'server.example:443'),
      ).single;
      final gates = List.generate(3, (_) => Completer<int?>());
      var calls = 0, active = 0, peak = 0;
      final probe = ServerLatencyProbe(
        hostResolver: (_) async => List.generate(
          12,
          (index) => InternetAddress('192.0.2.${index + 1}'),
        ),
        tcpRttSampler: (_, _) async {
          final index = calls++;
          active++;
          if (active > peak) peak = active;
          try {
            return index < gates.length ? await gates[index].future : 20;
          } finally {
            active--;
          }
        },
      );
      final measurement = probe.measure(profile);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 3);
      for (final gate in gates) {
        gate.complete(20);
      }
      expect(await measurement, 20);
      expect(calls, 60);
      expect(peak, lessThanOrEqualTo(3));
    },
  );

  test(
    'desktop cancellation stops the isolate and remaining socket handshakes',
    () async {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      final cancellation = Completer<void>();
      var accepted = 0;
      final listener = server.listen((socket) {
        if (socket.remoteAddress.isLoopback) {
          accepted++;
          if (!cancellation.isCompleted) cancellation.complete();
        }
        socket.destroy();
      });
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', 'localhost:${server.port}'),
      ).single;
      final probe = ServerLatencyProbe(
        useAppleNativePing: false,
        hostResolver: (_) async => List.generate(
          512,
          (index) =>
              InternetAddress('127.0.${index ~/ 250}.${index % 250 + 1}'),
        ),
      );
      try {
        expect(
          await probe
              .measure(
                profile,
                cancellation: cancellation.future,
                shouldContinue: () => !cancellation.isCompleted,
              )
              .timeout(const Duration(seconds: 3)),
          isNull,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(accepted, greaterThan(0));
        expect(accepted, lessThan(200));
      } finally {
        await listener.cancel();
        await server.close();
      }
    },
  );

  test('cancelled Apple probe stops remaining TCP samples', () async {
    final profile = VpnProfile.parseSubscription(testLink).single;
    final gate = Completer<TcpPingSample?>();
    var active = true;
    var calls = 0;
    final probe = ServerLatencyProbe(
      useAppleNativePing: true,
      appleNativeProbeSampler: (_, _) {
        calls++;
        return gate.future;
      },
    );
    final result = probe.measure(profile, shouldContinue: () => active);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    active = false;
    gate.complete(TcpPingSample(latencyMs: 20));
    expect(await result, isNull);
    expect(calls, 1);
  });

  test(
    'leaving locations prevents a pending ping from updating the cache',
    () async {
      final probe = _GatedProbe();
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _SessionWithServers()),
          serverLatencyProbeProvider.overrideWithValue(probe),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        serverLatencyProvider('fast'),
        (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      subscription.close();
      await container.pump();
      probe.gates['fast']!.complete(180);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(serverLatencyLastKnownProvider), isEmpty);
    },
  );

  test('obsolete ping cannot overwrite the refreshed measurement', () async {
    final probe = _GatedProbe();
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) => _SessionWithServers()),
        serverLatencyProbeProvider.overrideWithValue(probe),
      ],
    );
    addTearDown(container.dispose);
    final provider = serverLatencyProvider('fast');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final oldGate = probe.gates['fast']!;
    container.read(provider);
    await Future<void>.delayed(Duration.zero);
    probe.gates['fast'] = Completer<int?>();
    container.invalidate(provider);
    final refreshed = container.read(provider.future);
    probe.gates['fast']!.complete(25);
    expect(await refreshed, 25);
    oldGate.complete(180);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(serverLatencyLastKnownProvider)['fast'], 25);
  });

  test('last successful ping stays visible while another probe is pending', () {
    expect(
      retainLastKnownLatency(const AsyncLoading<int?>(), 24).valueOrNull,
      24,
    );
    expect(
      retainLastKnownLatency(const AsyncData<int?>(48), 24).valueOrNull,
      48,
    );
    expect(
      retainLastKnownLatency(const AsyncData<int?>(null), null).valueOrNull,
      isNull,
    );
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  test('Apple keeps physical-interface TCP probes enabled by default', () {
    expect(
      ServerLatencyProbe().useAppleNativePing,
      Platform.isIOS || Platform.isMacOS,
    );
  });

  test(
    'last successful ping stays visible while an error tunnel stops',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _SessionWithServers()),
          vpnProvider.overrideWith((ref) => _ErrorVpnNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);
      container.read(serverLatencyLastKnownProvider.notifier).state = {
        'fast': 24,
      };
      container.read(vpnTunnelMayBeActiveProvider.notifier).state = true;

      expect(await container.read(serverLatencyProvider('fast').future), 24);
    },
  );

  test(
    'a stopped VPN error does not prevent fresh server ping checks',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _SessionWithServers()),
          vpnProvider.overrideWith((ref) => _ErrorVpnNotifier(ref)),
          serverLatencyProbeProvider.overrideWithValue(_FixedProbe()),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(serverLatencyProvider('fast').future), 25);
      expect(container.read(serverLatencyLastKnownProvider)['fast'], 25);
    },
  );

  test(
    'TCP reachability ping does not launch a Reality health request',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', '127.0.0.1:${server.port}'),
      ).single;
      final received = server.listen((socket) => socket.destroy());
      var healthCheckCalled = false;
      try {
        final ping = await ServerLatencyProbe(
          useAppleNativePing: false,
          realityVerifier: (_) async {
            healthCheckCalled = true;
            return false;
          },
        ).measure(profile);
        expect(ping, isNotNull);
        expect(healthCheckCalled, isFalse);
      } finally {
        await received.cancel();
        await server.close();
      }
    },
  );

  test('TCP latency measures the VPN node endpoint directly', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = server.listen((socket) => socket.destroy());
    final profile = VpnProfile.parseSubscription(
      testLink.replaceFirst('127.0.0.1:443', '127.0.0.1:${server.port}'),
    ).single;
    try {
      final latency = await ServerLatencyProbe(
        useAppleNativePing: false,
      ).measureTcpRtt(profile);
      expect(latency, isNotNull);
      expect(latency, greaterThanOrEqualTo(1));
    } finally {
      await received.cancel();
      await server.close();
    }
  });

  test(
    'Android TCP ping dials the configured domain and port directly',
    () async {
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', 'node.example:8443'),
      ).single;
      String? dialedTarget;
      String? diagnostic;
      final latency = await ServerLatencyProbe(
        useAndroidNativePing: true,
        androidNativeRttSampler: (host, port) async {
          dialedTarget = '$host:$port';
          return 24;
        },
        hostResolver: (_) async => throw StateError('DNS scan must be skipped'),
        onDiagnostic: (value) => diagnostic = value,
      ).measureTcpRtt(profile);

      expect(latency, 24);
      expect(dialedTarget, 'node.example:8443');
      expect(diagnostic, contains('Android active network'));
      expect(diagnostic, contains('shown: 24ms'));
    },
  );

  test(
    'Apple TCP ping bypasses the active VPN through the physical interface',
    () async {
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', 'node.example:443'),
      ).single;
      String? dialedTarget;
      String? diagnostic;
      final latency = await ServerLatencyProbe(
        useAppleNativePing: true,
        appleNativeProbeSampler: (host, port) async {
          dialedTarget = '$host:$port';
          return const TcpPingSample(latencyMs: 24, networkPath: 'Wi-Fi');
        },
        hostResolver: (_) async => [InternetAddress('203.0.113.8')],
        onDiagnostic: (value) => diagnostic = value,
      ).measureTcpRtt(profile);

      expect(latency, 24);
      expect(dialedTarget, '203.0.113.8:443');
      expect(diagnostic, contains('Apple physical interface'));
      expect(diagnostic, contains('resolved: 203.0.113.8'));
      expect(diagnostic, contains('route: Wi-Fi'));
    },
  );

  test(
    'Apple TCP ping excludes DNS and chooses the fastest resolved address',
    () async {
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', 'node.example:443'),
      ).single;
      final targets = <String>[];
      var dnsLookups = 0;
      final latency = await ServerLatencyProbe(
        useAppleNativePing: true,
        hostResolver: (host) async {
          expect(host, 'node.example');
          dnsLookups++;
          return [
            InternetAddress('203.0.113.8'),
            InternetAddress('203.0.113.7'),
          ];
        },
        appleNativeProbeSampler: (host, port) async {
          targets.add('$host:$port');
          final milliseconds = host.endsWith('.8') ? 240 : 24;
          return TcpPingSample(latencyMs: milliseconds, networkPath: 'Wi-Fi');
        },
      ).measureTcpRtt(profile);

      expect(dnsLookups, 1);
      expect(targets, hasLength(10));
      expect(
        targets,
        everyElement(anyOf('203.0.113.8:443', '203.0.113.7:443')),
      );
      expect(latency, 24);
    },
  );

  test('Apple native TCP ping channel returns route and latency', () async {
    const channel = MethodChannel('com.oculve/server_latency');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'tcpConnectLatency');
      expect(call.arguments, {
        'host': '203.0.113.8',
        'port': 443,
        'timeoutMs': 3000,
      });
      return {'latencyMs': 24, 'networkPath': 'Wi-Fi'};
    });
    final profile = VpnProfile.parseSubscription(
      testLink.replaceFirst('127.0.0.1:443', 'node.example:443'),
    ).single;
    String? diagnostic;
    try {
      final latency = await ServerLatencyProbe(
        useAppleNativePing: true,
        hostResolver: (_) async => [InternetAddress('203.0.113.8')],
        onDiagnostic: (value) => diagnostic = value,
      ).measureTcpRtt(profile);

      expect(latency, 24);
      expect(diagnostic, contains('route: Wi-Fi'));
      expect(diagnostic, contains('shown: 24ms'));
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  test(
    'Android TCP ping logs the resolved endpoint returned by native code',
    () async {
      const channel = MethodChannel('com.oculve/server_latency');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'tcpConnectLatency');
        expect(call.arguments, {
          'host': 'node.example',
          'port': 443,
          'timeoutMs': 3000,
        });
        return {'latencyMs': 24, 'resolvedAddress': '203.0.113.8'};
      });
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', 'node.example:443'),
      ).single;
      String? diagnostic;
      try {
        final latency = await ServerLatencyProbe(
          useAndroidNativePing: true,
          onDiagnostic: (value) => diagnostic = value,
        ).measureTcpRtt(profile);

        expect(latency, 24);
        expect(diagnostic, contains('resolved: 203.0.113.8'));
        expect(diagnostic, contains('shown: 24ms'));
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );

  test(
    'Android TCP ping does not show a fallback from a failed native dial',
    () async {
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', 'node.example:443'),
      ).single;
      var fallbackCalled = false;
      final latency = await ServerLatencyProbe(
        useAndroidNativePing: true,
        androidNativeRttSampler: (_, _) async => null,
        hostResolver: (_) async {
          fallbackCalled = true;
          return [InternetAddress.loopbackIPv4];
        },
      ).measureTcpRtt(profile);

      expect(latency, isNull);
      expect(fallbackCalled, isFalse);
    },
  );

  test('TCP latency timing is isolated from Flutter UI frame stalls', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = server.listen((socket) => socket.destroy());
    final profile = VpnProfile.parseSubscription(
      testLink.replaceFirst('127.0.0.1:443', '127.0.0.1:${server.port}'),
    ).single;
    try {
      final pending = ServerLatencyProbe(
        useAppleNativePing: false,
      ).measureTcpRtt(profile);
      final busy = Stopwatch()..start();
      while (busy.elapsedMilliseconds < 250) {
        // Simulate a frame stall on Flutter's main isolate while the TCP probe
        // runs in its own isolate.
      }
      final latency = await pending;
      expect(latency, isNotNull);
      expect(latency, lessThan(100));
    } finally {
      await received.cancel();
      await server.close();
    }
  });

  test(
    'TCP ping resolves supported TCP proxy outbound endpoint formats',
    () async {
      final profiles = [
        VpnProfile(
          id: 'trojan',
          name: 'Trojan',
          flag: null,
          config: jsonEncode({
            'outbounds': [
              {
                'tag': 'proxy',
                'protocol': 'trojan',
                'settings': {
                  'servers': [
                    {'address': 'trojan.example', 'port': 8443},
                  ],
                },
              },
            ],
          }),
        ),
        VpnProfile(
          id: 'http',
          name: 'HTTP',
          flag: null,
          config: jsonEncode({
            'outbounds': [
              {
                'tag': 'proxy',
                'protocol': 'http',
                'settings': {
                  'servers': [
                    {'address': 'proxy.example', 'port': 8080},
                  ],
                },
              },
            ],
          }),
        ),
      ];
      final observed = <String, int>{};
      var currentHost = '';
      final probe = ServerLatencyProbe(
        hostResolver: (host) async {
          currentHost = host;
          return [InternetAddress.loopbackIPv4];
        },
        tcpRttSampler: (address, port) async {
          observed[currentHost] = port;
          return 18;
        },
      );

      for (final profile in profiles) {
        expect(await probe.measureTcpRtt(profile), 18);
      }
      expect(observed.keys, ['trojan.example', 'proxy.example']);
      expect(observed.values, [8443, 8080]);
    },
  );

  test('TCP ping stays unavailable for UDP-only proxy protocols', () async {
    for (final protocol in ['hysteria', 'wireguard']) {
      final profile = VpnProfile(
        id: protocol,
        name: protocol,
        flag: null,
        config: jsonEncode({
          'outbounds': [
            {
              'tag': 'proxy',
              'protocol': protocol,
              'settings': {'address': 'node.example', 'port': 443},
            },
          ],
        }),
      );
      var samplerCalled = false;
      final latency = await ServerLatencyProbe(
        tcpRttSampler: (_, _) async {
          samplerCalled = true;
          return 20;
        },
      ).measureTcpRtt(profile);

      expect(latency, isNull, reason: protocol);
      expect(samplerCalled, isFalse, reason: protocol);
    }
  });

  test(
    'TCP latency uses the best successful sample for fastest-server sorting',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final received = server.listen((socket) => socket.destroy());
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', '127.0.0.1:${server.port}'),
      ).single;
      final samples = <int>[24, 190, 27, 28, 26];
      var sampleCount = 0;
      try {
        final latency = await ServerLatencyProbe(
          tcpRttSampler: (_, _) async => samples[sampleCount++],
        ).measureTcpRtt(profile);
        expect(sampleCount, 5);
        expect(latency, 24);
      } finally {
        await received.cancel();
        await server.close();
      }
    },
  );

  test(
    'one delayed TCP sample cannot dominate when another probe times out',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final received = server.listen((socket) => socket.destroy());
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', '127.0.0.1:${server.port}'),
      ).single;
      final samples = <int?>[24, 190, null, 27, 28];
      var sampleCount = 0;
      try {
        final latency = await ServerLatencyProbe(
          tcpRttSampler: (_, _) async => samples[sampleCount++],
        ).measureTcpRtt(profile);
        expect(sampleCount, 5);
        expect(latency, 24);
      } finally {
        await received.cancel();
        await server.close();
      }
    },
  );

  test('Reality diagnostics remain separate from node TCP ping', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = server.listen((socket) => socket.destroy());
    final profile = VpnProfile.parseSubscription(
      testLink.replaceFirst('127.0.0.1:443', '127.0.0.1:${server.port}'),
    ).single;
    var verifiedConfig = false;
    try {
      final probe = ServerLatencyProbe(
        useAppleNativePing: false,
        realityVerifier: (config) async {
          verifiedConfig = config.contains('reality');
          return verifiedConfig;
        },
      );
      final latency = await probe.measure(profile);
      expect(verifiedConfig, isFalse);
      expect(latency, isNotNull);
      expect(latency, greaterThanOrEqualTo(1));
      expect(await probe.verifyReality(profile), isTrue);
      expect(verifiedConfig, isTrue);
    } finally {
      await received.cancel();
      await server.close();
    }
  });

  test('failed Reality health does not inflate or hide TCP ping', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = server.listen((socket) => socket.destroy());
    final profile = VpnProfile.parseSubscription(
      testLink.replaceFirst('127.0.0.1:443', '127.0.0.1:${server.port}'),
    ).single;
    try {
      final probe = ServerLatencyProbe(
        useAppleNativePing: false,
        realityVerifier: (_) async => false,
      );
      final latency = await probe.measure(profile);
      expect(latency, isNotNull);
      expect(await probe.verifyReality(profile), isFalse);
    } finally {
      await received.cancel();
      await server.close();
    }
  });

  test('orders measured nodes first and keeps ties and failures stable', () {
    final profiles = [
      _profile('slow'),
      _profile('offline'),
      _profile('fast'),
      _profile('same'),
    ];
    final sorted = sortProfilesByLatency(profiles, {
      'slow': 180,
      'offline': null,
      'fast': 25,
      'same': 180,
    });
    expect(sorted.map((profile) => profile.id), [
      'fast',
      'slow',
      'same',
      'offline',
    ]);
  });

  testWidgets(
    'country icons use bundled vectors and unknown flags use a globe',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CountryIcon(flag: '🇹🇷')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CountryIcon(flag: null))),
      );
      expect(find.byIcon(Icons.public), findsOneWidget);
    },
  );

  testWidgets(
    'connected locations are selectable without the disconnect warning',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) => _SessionWithServers()),
            vpnProvider.overrideWith((ref) => _ConnectedVpnNotifier(ref)),
            vpnTunnelMayBeActiveProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ServerSelectionScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Disconnect before changing location.'), findsNothing);
      final location = tester.widget<ListTile>(
        find.ancestor(of: find.text('Zurich'), matching: find.byType(ListTile)),
      );
      expect(location.enabled, isTrue);
      expect(location.onTap, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('location list shows latency in fastest-first order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _SessionWithServers()),
          serverLatencyProbeProvider.overrideWithValue(_FixedProbe()),
          selectedServerProvider.overrideWith((ref) => 'fast'),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ServerSelectionScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.byTooltip('25ms'), findsOneWidget);
    expect(find.byTooltip('180ms'), findsOneWidget);
    expect(find.text('Optimal'), findsOneWidget);
    expect(find.text('DPI Bypass'), findsOneWidget);
    expect(find.byType(DpiBypassLogo), findsOneWidget);
    final optimalRect = tester.getRect(
      find.byKey(const ValueKey('optimal-server-card')),
    );
    final dpiRect = tester.getRect(
      find.byKey(const ValueKey('dpi-bypass-server-card')),
    );
    expect(optimalRect.top, closeTo(dpiRect.top, 1));
    expect(optimalRect.right, lessThan(dpiRect.left));
    expect(
      optimalRect.bottom,
      lessThan(tester.getRect(find.byType(Divider)).top),
    );
    expect(
      tester.getTopLeft(find.text('Optimal')).dy,
      lessThan(tester.getTopLeft(find.text('Zurich')).dy),
    );
    final selectedCard = tester.widget<FrostedCard>(
      find.byKey(const ValueKey('server-fast')),
    );
    expect(selectedCard.borderColor, isNotNull);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.text('25 ms'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Zurich')).dy,
      lessThan(tester.getTopLeft(find.text('Amsterdam')).dy),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byTooltip('Sorted by ping. Tap to sort alphabetically.'),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('server-sort-toggle')),
        matching: find.byIcon(Icons.bolt_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('server-sort-toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(PopupMenuButton<ServerSort>), findsNothing);
    expect(
      find.byTooltip('Sorted alphabetically. Tap to sort by ping.'),
      findsNothing,
    );
    expect(find.byIcon(Icons.sort_by_alpha_rounded), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Amsterdam')).dy,
      lessThan(tester.getTopLeft(find.text('Zurich')).dy),
    );
  });

  testWidgets('home shows the resolved optimal server and DPI Bypass mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget homeFor(String? selected) => ProviderScope(
      key: ValueKey(selected),
      overrides: [
        sessionProvider.overrideWith((ref) => _SessionWithServers()),
        serverLatencyProbeProvider.overrideWithValue(_FixedProbe()),
        selectedServerProvider.overrideWith((ref) => selected),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: ServerCard()),
      ),
    );

    await tester.pumpWidget(homeFor(optimalServerId));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Zurich'), findsOneWidget);
    expect(find.text('Optimal'), findsNothing);

    await tester.pumpWidget(homeFor(dpiBypassServerId));
    await tester.pump();
    expect(find.text('DPI Bypass'), findsOneWidget);
    expect(find.byType(DpiBypassLogo), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsNothing);
    expect(find.text('Zurich'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening locations refreshes the subscription every time', (
    tester,
  ) async {
    final session = _SessionWithServers();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => session),
          serverLatencyProbeProvider.overrideWithValue(_FixedProbe()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ServerSelectionScreen(),
                  ),
                ),
                child: const Text('Open locations'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open locations'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(session.refreshes, 1);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Open locations'));
    await tester.pump();
    expect(session.refreshes, 2);
  });

  testWidgets('home location control stays compact beside the connect button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _SessionWithServers()),
          serverLatencyProbeProvider.overrideWithValue(_FixedProbe()),
        ],
        child: MaterialApp(theme: AppTheme.darkTheme, home: const HomeScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final card = find.descendant(
      of: find.byType(ServerCard),
      matching: find.byType(FrostedCard),
    );
    expect(tester.getSize(card).width, lessThanOrEqualTo(232));
    expect(tester.getSize(card).height, lessThan(60));
    expect(find.text('CONNECT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection error never shifts home controls', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) => _SessionWithServers()),
        serverLatencyProbeProvider.overrideWithValue(_FixedProbe()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.darkTheme, home: const HomeScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final before = tester.getTopLeft(find.byType(ServerCard));
    container.read(vpnErrorProvider.notifier).state =
        'Could not establish the VPN. Please try again.';
    await tester.pump();
    expect(tester.getTopLeft(find.byType(ServerCard)), before);
    expect(
      find.text('Could not establish the VPN. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('ping refresh keeps rows in place until every probe settles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final probe = _GatedProbe();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _SessionWithServers()),
          serverLatencyProbeProvider.overrideWithValue(probe),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ServerSelectionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final amsterdam = find.text('Amsterdam');
    final zurich = find.text('Zurich');
    expect(
      tester.getTopLeft(amsterdam).dy,
      lessThan(tester.getTopLeft(zurich).dy),
    );

    probe.gates['fast']!.complete(25);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.getTopLeft(amsterdam).dy,
      lessThan(tester.getTopLeft(zurich).dy),
    );

    probe.gates['slow']!.complete(180);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(
      tester.getTopLeft(zurich).dy,
      lessThan(tester.getTopLeft(amsterdam).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
