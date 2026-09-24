import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/home/presentation/home_screen.dart';
import 'package:oculve/features/home/presentation/server_selection_screen.dart';
import 'package:oculve/features/home/presentation/widgets/country_icon.dart';
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
  Future<int?> measure(VpnProfile profile) async =>
      profile.id == 'fast' ? 25 : 180;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  test('Apple keeps physical-interface TCP probes enabled by default', () {
    expect(
      ServerLatencyProbe().useAppleNativePing,
      Platform.isIOS || Platform.isMacOS,
    );
  });

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
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ServerSelectionScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('25ms'), findsOneWidget);
    expect(find.byTooltip('180ms'), findsOneWidget);
    expect(find.text('25 ms'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Zurich')).dy,
      lessThan(tester.getTopLeft(find.text('Amsterdam')).dy),
    );
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Sort servers'), findsOneWidget);
    await tester.tap(find.byTooltip('Sort servers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Alphabetical'), findsOneWidget);
    final menu = tester.widget<PopupMenuButton<ServerSort>>(
      find.byType(PopupMenuButton<ServerSort>),
    );
    menu.onSelected!(ServerSort.alphabetical);
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Amsterdam')).dy,
      lessThan(tester.getTopLeft(find.text('Zurich')).dy),
    );
  });

  testWidgets(
    'opening locations uses the startup subscription without refresh',
    (tester) async {
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
      expect(session.refreshes, 0);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Open locations'));
      await tester.pump();
      expect(session.refreshes, 0);
    },
  );

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
    expect(tester.getSize(card).width, lessThanOrEqualTo(212));
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
    container.read(vpnErrorProvider.notifier).state = 'Could not connect';
    await tester.pump();
    expect(tester.getTopLeft(find.byType(ServerCard)), before);
    expect(find.text('Could not connect'), findsOneWidget);
  });
}
