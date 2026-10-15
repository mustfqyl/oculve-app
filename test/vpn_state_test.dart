import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'dart:convert';
import 'profile_test.dart' show testLink;

class TestApi extends OculveApi {
  bool active = true;
  int subscriptionCalls = 0;
  final requests = <String>[];
  Map<String, String> subscriptionHeaders = const {};
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async {
    requests.add(path);
    return {
      'status': active ? 'active' : 'expired',
      'subscriptionUrl': '/subscription',
    };
  }

  @override
  Future<SubscriptionResponse> subscriptionResponse(String url) async {
    subscriptionCalls++;
    return SubscriptionResponse(body: testLink, headers: subscriptionHeaders);
  }
}

class TestPlatform extends VlessPlatform {
  late void Function(VlessStatus) emit;
  bool permission = true;
  Completer<bool>? permissionGate;
  Completer<void>? startGate;
  Object? startFailure;
  int starts = 0;
  int stops = 0;
  int replacements = 0;
  bool rejectReplacement = false;
  Object? replacementFailure;
  String? lastConfig;
  String? lastRemark;
  bool lastDpiBypass = false;
  int lastDpiProfile = -1;
  String? lastAndroidDnsProxyOutboundTag;
  @override
  Future<void> initializeVless({
    required void Function(VlessStatus) onStatusChanged,
    required String notificationIconResourceType,
    required String notificationIconResourceName,
    required String providerBundleIdentifier,
    required String groupIdentifier,
    String? keychainAccessGroup,
  }) async {
    emit = onStatusChanged;
  }

  @override
  Future<bool> requestPermission() async =>
      permissionGate == null ? permission : await permissionGate!.future;
  @override
  Future<void> startVless({
    required String remark,
    required String config,
    required String notificationDisconnectButtonName,
    List<String>? blockedApps,
    List<String>? bypassSubnets,
    bool dpiBypass = false,
    int dpiProfile = 0,
    bool proxyOnly = false,
    String? geoAssetsDirectory,
    AndroidDnsPolicy androidDnsPolicy = AndroidDnsPolicy.config,
    String? androidDnsProxyOutboundTag,
  }) async {
    expectSync(proxyOnly, false);
    expectSync(
      androidDnsPolicy,
      Platform.isAndroid ? AndroidDnsPolicy.proxy : AndroidDnsPolicy.config,
    );
    starts++;
    lastRemark = remark;
    lastConfig = config;
    lastDpiBypass = dpiBypass;
    lastDpiProfile = dpiProfile;
    lastAndroidDnsProxyOutboundTag = androidDnsProxyOutboundTag;
    await startGate?.future;
    if (startFailure != null) throw startFailure!;
  }

  @override
  Future<void> replaceVless({
    required String remark,
    required String config,
    required String notificationDisconnectButtonName,
    List<String>? blockedApps,
    List<String>? bypassSubnets,
    bool dpiBypass = false,
    int dpiProfile = 0,
    bool proxyOnly = false,
    String? geoAssetsDirectory,
    AndroidDnsPolicy androidDnsPolicy = AndroidDnsPolicy.config,
    String? androidDnsProxyOutboundTag,
  }) async {
    replacements++;
    if (rejectReplacement) throw StateError('Replacement rejected');
    lastRemark = remark;
    lastConfig = config;
    lastDpiBypass = dpiBypass;
    await startGate?.future;
    if (replacementFailure != null) throw replacementFailure!;
  }

  @override
  Future<void> stopVless() async {
    stops++;
    emit(VlessStatus());
  }
}

class _FastestProbe extends ServerLatencyProbe {
  final checkedNames = <String>[];

  @override
  Future<int?> measure(
    VpnProfile profile, {
    bool Function()? shouldContinue,
    Future<void>? cancellation,
  }) async {
    checkedNames.add(profile.name);
    return profile.name == 'Fast route' ? 23 : 160;
  }
}

void main() {
  late TestPlatform platform;
  late TestApi api;
  late ProviderContainer container;
  late _FastestProbe probe;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    platform = TestPlatform();
    VlessPlatform.instance = platform;
    api = TestApi();
    probe = _FastestProbe();
    container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        serverLatencyProbeProvider.overrideWithValue(probe),
      ],
    );
    // Mimic the app's session restore, which is the initial subscription load.
    await container.read(sessionProvider.notifier).refresh();
  });
  tearDown(() => container.dispose());
  test(
    'connected selection uses replacement without releasing protection',
    () async {
      final controller = container.read(vpnProvider.notifier);
      await controller.connect();
      platform.emit(VlessStatus(state: 'CONNECTED'));
      await controller.selectServer(dpiBypassServerId);
      expect(platform.replacements, 1);
      expect(platform.stops, 0);
      expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
      expect(container.read(vpnProvider), VpnState.connecting);
      platform.emit(VlessStatus(state: 'CONNECTED'));
      expect(container.read(vpnProvider), VpnState.connected);
    },
  );

  testWidgets('rejected replacement and timeout never release the tunnel', (
    tester,
  ) async {
    final controller = container.read(vpnProvider.notifier);
    await controller.connect();
    platform.emit(VlessStatus(state: 'CONNECTED'));
    platform.rejectReplacement = true;
    await controller.selectServer(dpiBypassServerId);
    expect(platform.stops, 0);
    expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
    await tester.pump(const Duration(seconds: 12));
    expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
    platform.rejectReplacement = false;
    await controller.connect();
    expect(platform.replacements, 2);
    await tester.pump(const Duration(seconds: 91));
    expect(platform.stops, 0);
    expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
    await controller.disconnect();
    expect(platform.stops, 1);
    expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
    controller.dismissError();
  });

  test('same server selection and concurrent switches are ignored', () async {
    final controller = container.read(vpnProvider.notifier);
    await controller.selectServer(dpiBypassServerId);
    await controller.connect();
    platform.emit(VlessStatus(state: 'CONNECTED'));
    await controller.selectServer(dpiBypassServerId);
    expect(platform.replacements, 0);
    platform.startGate = Completer<void>();
    final pending = controller.selectServer(optimalServerId);
    while (platform.replacements == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    platform.emit(VlessStatus(state: 'CONNECTED')); // old session heartbeat
    expect(container.read(vpnProvider), VpnState.connecting);
    await controller.selectServer(dpiBypassServerId);
    expect(platform.replacements, 1);
    platform.startGate!.complete();
    await pending;
    expect(platform.stops, 0);
  });

  test(
    'optimal switch avoids direct probes and runtime failure retains protection',
    () async {
      final controller = container.read(vpnProvider.notifier);
      await controller.connect();
      platform.emit(VlessStatus(state: 'CONNECTED'));
      await controller.selectServer(optimalServerId);
      expect(probe.checkedNames, isEmpty);
      expect(platform.replacements, 1);
      platform.emit(VlessStatus(state: 'CONNECTED'));
      platform.emit(VlessStatus(state: 'ERROR'));
      await Future<void>.delayed(Duration.zero);
      expect(platform.stops, 0);
      expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
      await controller.disconnect();
    },
  );

  test('cancel while awaiting permission never starts a tunnel', () async {
    platform.permissionGate = Completer<bool>();
    final controller = container.read(vpnProvider.notifier);
    final pending = controller.connect();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await controller.disconnect();
    platform.permissionGate!.complete(true);
    await pending;
    expect(platform.starts, 0);
    expect(container.read(vpnProvider), VpnState.disconnected);
  });

  test('cancel during native start stops late-started tunnel', () async {
    platform.startGate = Completer<void>();
    final controller = container.read(vpnProvider.notifier);
    final pending = controller.connect();
    while (platform.starts == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await controller.disconnect();
    platform.startGate!.complete();
    await pending;
    expect(platform.stops, 2);
    expect(container.read(vpnProvider), VpnState.disconnected);
    expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
  });

  testWidgets(
    'automatic retry restarts interrupted session and manual stop cancels further retries',
    (tester) async {
      final controller = container.read(vpnProvider.notifier);
      await controller.connect();
      platform.emit(VlessStatus(state: 'CONNECTED'));
      platform.emit(VlessStatus(state: 'DISCONNECTED'));
      await tester.pump(const Duration(seconds: 3));
      for (var i = 0; i < 20; i++) {
        await tester.pump();
      }
      expect(
        platform.starts,
        2,
        reason:
            controller.events.toString() +
            container.read(vpnProvider).toString(),
      );
      await controller.disconnect();
      platform.emit(VlessStatus(state: 'ERROR'));
      await tester.pump(const Duration(seconds: 60));
      expect(platform.starts, 2);
      expect(container.read(vpnProvider), VpnState.disconnected);
    },
  );
  testWidgets('disabled retry never restarts an interrupted session', (
    tester,
  ) async {
    await (await SharedPreferences.getInstance()).setBool(
      'connection.reconnect',
      false,
    );
    final controller = container.read(vpnProvider.notifier);
    await controller.connect();
    platform.emit(VlessStatus(state: 'CONNECTED'));
    platform.emit(VlessStatus(state: 'DISCONNECTED'));
    await tester.pump(const Duration(seconds: 60));
    expect(platform.starts, 1);
  });
  test('session preserves provider DNS metadata for server pings', () async {
    api.subscriptionHeaders = const {
      'server-address-resolve-enable': '1',
      'server-address-resolve-dns-domain': 'https://resolver.example/dns-query',
    };

    await container.read(sessionProvider.notifier).refresh();

    final resolution = container
        .read(sessionProvider)
        .valueOrNull!
        .profiles
        .single
        .serverAddressResolution;
    expect(resolution?.dnsEndpoint.host, 'resolver.example');
  });

  test(
    'accepted start does not mean connected; native events own state',
    () async {
      final controller = container.read(vpnProvider.notifier);
      await controller.connect();
      expect(container.read(vpnProvider), VpnState.connecting);
      await controller.connect();
      expect(platform.starts, 1);
      expect(api.subscriptionCalls, 1);
      expect(api.requests, ['/api/user/me', '/api/user/me']);
      platform.emit(VlessStatus(state: 'CONNECTED'));
      expect(container.read(vpnProvider), VpnState.connected);
      platform.emit(VlessStatus(state: 'DISCONNECTED'));
      expect(container.read(vpnProvider), VpnState.error);
    },
  );
  testWidgets('repeated native errors do not pin the home error message', (
    tester,
  ) async {
    await (await SharedPreferences.getInstance()).setBool(
      'connection.reconnect',
      false,
    );
    final controller = container.read(vpnProvider.notifier);
    await controller.connect();

    platform.emit(VlessStatus(state: 'ERROR'));
    expect(container.read(vpnErrorProvider), isNotNull);
    await tester.pump(const Duration(seconds: 8));
    platform.emit(VlessStatus(state: 'ERROR'));
    await tester.pump(const Duration(seconds: 4));

    expect(container.read(vpnErrorProvider), isNull);
    expect(container.read(vpnProvider), VpnState.disconnected);
  });
  test(
    'Optimal measures every profile and starts the lowest-latency server',
    () async {
      final slow = VpnProfile.parseSubscription(
        testLink.replaceFirst('#Test%20location', '#Slow%20route'),
      ).single;
      final fast = VpnProfile.parseSubscription(
        testLink
            .replaceFirst('127.0.0.1:443', '127.0.0.1:444')
            .replaceFirst('#Test%20location', '#Fast%20route'),
      ).single;
      container.read(sessionProvider.notifier).state = AsyncValue.data(
        Account({'status': 'active'}, [slow, fast]),
      );
      container.read(selectedServerProvider.notifier).state = optimalServerId;

      await container.read(vpnProvider.notifier).connect();

      expect(probe.checkedNames, ['Slow route', 'Fast route']);
      expect(platform.lastRemark, 'Fast route');
      expect(container.read(optimalServerProfileProvider), fast.id);
      final config = jsonDecode(platform.lastConfig!) as Map<String, dynamic>;
      final outbound = (config['outbounds'] as List).single;
      expect(outbound['settings']['vnext'][0]['port'], 444);
    },
  );
  test(
    'cancelling Optimal skips queued probes and does not select a server',
    () async {
      container.dispose();
      final gates = List.generate(3, (_) => Completer<int?>());
      var samples = 0;
      final realProbe = ServerLatencyProbe(
        useAndroidNativePing: true,
        androidNativeRttSampler: (_, _) => gates[samples++].future,
      );
      container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(api),
          serverLatencyProbeProvider.overrideWithValue(realProbe),
        ],
      );
      final profiles = List.generate(
        4,
        (index) => VpnProfile.parseSubscription(
          testLink.replaceFirst('127.0.0.1:443', '127.0.0.1:${443 + index}'),
        ).single,
      );
      container.read(sessionProvider.notifier).state = AsyncValue.data(
        Account({'status': 'active'}, profiles),
      );
      container.read(selectedServerProvider.notifier).state = optimalServerId;
      final controller = container.read(vpnProvider.notifier);
      final connect = controller.connect();
      await Future<void>.delayed(Duration.zero);
      expect(samples, 3);
      await controller.disconnect();
      for (final gate in gates) {
        gate.complete(20);
      }
      await connect;
      expect(samples, 3);
      expect(platform.starts, 0);
      expect(container.read(optimalServerProfileProvider), isNull);
      expect(container.read(vpnProvider), VpnState.disconnected);
    },
  );

  test('unsolicited native errors do not create a UI failure', () async {
    final controller = container.read(vpnProvider.notifier);
    await controller.initialize();
    platform.emit(VlessStatus(state: 'ERROR'));
    expect(container.read(vpnErrorProvider), isNull);
    expect(container.read(vpnProvider), VpnState.disconnected);
    expect(platform.stops, 0);
  });

  test('late native errors after manual disconnect stay dismissed', () async {
    final controller = container.read(vpnProvider.notifier);
    await controller.connect();
    platform.emit(VlessStatus(state: 'CONNECTED'));
    await controller.disconnect();
    platform.emit(VlessStatus(state: 'ERROR'));
    expect(container.read(vpnErrorProvider), isNull);
    expect(container.read(vpnProvider), VpnState.disconnected);
  });

  test('permission denial never starts Xray', () async {
    platform.permission = false;
    await container.read(vpnProvider.notifier).connect();
    expect(platform.starts, 0);
    expect(container.read(vpnProvider), VpnState.error);
    expect(container.read(vpnErrorProvider), 'VPN permission was not granted.');
  });
  test('expired account cannot start a tunnel', () async {
    api.active = false;
    await container.read(vpnProvider.notifier).connect();
    expect(platform.starts, 0);
    expect(container.read(vpnProvider), VpnState.error);
  });
  test('selected Reality fingerprint reaches the native Xray config', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('xray.reality.fingerprint.v1', 'firefox');
    await container.read(vpnProvider.notifier).connect();
    final config = jsonDecode(platform.lastConfig!) as Map<String, dynamic>;
    final outbound =
        (config['outbounds'] as List).single as Map<String, dynamic>;
    final stream = outbound['streamSettings'] as Map<String, dynamic>;
    expect((stream['realitySettings'] as Map)['fingerprint'], 'firefox');
  });

  test('saved DNS preferences reach the tunnel config on connect', () async {
    await XrayPreferences.setDnsSettings(
      const XrayDnsSettings(
        servers: ['https://dns.google/dns-query'],
        queryStrategy: DnsQueryStrategy.useSystem,
        enableParallelQuery: true,
        clientIp: '192.0.2.45',
        hosts: {'private.example': '192.0.2.1'},
      ),
    );
    await container.read(vpnProvider.notifier).connect();
    final config = jsonDecode(platform.lastConfig!) as Map<String, dynamic>;
    expect(config['dns']['servers'], ['https://dns.google/dns-query']);
    expect(config['dns']['queryStrategy'], 'UseSystem');
    expect(config['dns']['enableParallelQuery'], isFalse);
    expect(config['dns'].containsKey('clientIp'), isFalse);
    expect(config['dns'].containsKey('hosts'), isFalse);
  });

  test('legacy core version guard does not alter the client profile', () async {
    await XrayPreferences.setVersionRequirement(
      const XrayVersionRequirement(minimum: '25.8.3', maximum: '26.9.9'),
    );
    await container.read(vpnProvider.notifier).connect();
    final config = jsonDecode(platform.lastConfig!) as Map<String, dynamic>;
    expect(config.containsKey('version'), isFalse);
  });

  test(
    'supported TLS hello fragmentation reaches the native Xray config',
    () async {
      await XrayPreferences.setTlsHelloFragmentation(true);
      await container.read(vpnProvider.notifier).connect();
      final config = jsonDecode(platform.lastConfig!) as Map<String, dynamic>;
      final outbound = (config['outbounds'] as List).single;
      expect(outbound['streamSettings']['finalmask'], {
        'tcp': [
          {
            'type': 'fragment',
            'settings': {
              'packets': 'tlshello',
              'lengths': ['100-200'],
              'delays': ['10-20'],
              'maxSplit': '3-6',
            },
          },
        ],
      });
    },
  );

  test(
    'domain bypass remains active while advanced split rules are ignored',
    () async {
      await XrayPreferences.setBypassDomains(['example.net']);
      await XrayPreferences.setRoutingRules(const [
        XrayRoutingRule(
          action: XrayRoutingAction.direct,
          domains: ['full:login.example.com'],
          ips: ['192.168.0.0/16'],
        ),
        XrayRoutingRule(
          action: XrayRoutingAction.block,
          ports: ['53'],
          networks: ['udp'],
        ),
      ]);

      await container.read(vpnProvider.notifier).connect();

      final config = jsonDecode(platform.lastConfig!) as Map<String, dynamic>;
      final rules = config['routing']['rules'] as List;
      expect(rules, hasLength(1));
      expect(rules.single['domain'], ['domain:example.net']);
      expect(rules.single['outboundTag'], 'direct');
      expect(
        (config['outbounds'] as List).any((item) => item['tag'] == 'block'),
        isFalse,
      );
    },
  );

  test(
    'DPI Bypass uses a built-in config and applies saved routing in Xray',
    () async {
      await XrayPreferences.setRoutingRules(const [
        XrayRoutingRule(
          action: XrayRoutingAction.proxy,
          domains: ['domain:example.org'],
        ),
        XrayRoutingRule(
          action: XrayRoutingAction.direct,
          domains: ['domain:gstatic.com', 'domain:direct.example'],
        ),
        XrayRoutingRule(
          action: XrayRoutingAction.block,
          domains: ['domain:blocked.example'],
        ),
      ]);
      final beforeRequests = List<String>.from(api.requests);
      container.read(selectedServerProvider.notifier).state = dpiBypassServerId;

      await container.read(vpnProvider.notifier).connect();

      expect(api.requests, beforeRequests);
      expect(platform.lastRemark, 'DPI Bypass');
      expect(platform.lastDpiBypass, isTrue);
      expect(platform.lastDpiProfile, 4);
      expect(
        platform.lastAndroidDnsProxyOutboundTag,
        Platform.isAndroid ? 'byedpi' : null,
      );
      final config = jsonDecode(platform.lastConfig!) as Map<String, dynamic>;
      final inbounds = config['inbounds'] as List;
      expect(inbounds, hasLength(1));
      expect(inbounds.single['listen'], '127.0.0.1');
      expect(inbounds.single['port'], 10808);
      final outbounds = config['outbounds'] as List;
      expect(outbounds.map((item) => item['tag']), [
        'byedpi',
        'direct',
        'block',
      ]);
      final byedpi = outbounds.first as Map<String, dynamic>;
      expect(byedpi['protocol'], 'socks');
      expect(byedpi['settings']['servers'], [
        {'address': '127.0.0.1', 'port': 65535},
      ]);
      expect(byedpi['targetStrategy'], 'UseIP');
      expect(outbounds[1]['protocol'], 'freedom');
      expect(outbounds[2]['protocol'], 'blackhole');
      expect(outbounds.any((item) => item['protocol'] == 'vless'), isFalse);
      expect(config['dns']['servers'], [
        'https://cloudflare-dns.com/dns-query',
      ]);
      final rules = config['routing']['rules'] as List;
      expect(rules[0]['domain'], ['full:www.gstatic.com']);
      expect(rules[0]['outboundTag'], 'byedpi');
      expect(rules[1]['domain'], ['full:cp.cloudflare.com']);
      expect(rules[1]['outboundTag'], 'byedpi');
      expect(rules[2]['domain'], ['domain:example.org']);
      expect(rules[2]['outboundTag'], 'byedpi');
      expect(rules[3]['domain'], [
        'domain:gstatic.com',
        'domain:direct.example',
      ]);
      expect(rules[3]['outboundTag'], 'direct');
      expect(rules[4]['domain'], ['domain:blocked.example']);
      expect(rules[4]['outboundTag'], 'block');
    },
  );

  test(
    'DPI manual profile is forwarded unchanged to the native runtime',
    () async {
      await (await SharedPreferences.getInstance()).setInt(
        'connection.dpi.strategy.v1',
        2,
      );
      container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
      await container.read(vpnProvider.notifier).connect();
      expect(platform.lastDpiProfile, 2);
      expect((jsonDecode(platform.lastConfig!) as Map)['oculveDpiProfile'], 2);
    },
  );

  test('DPI Bypass to VPN to DPI Bypass switches modes cleanly', () async {
    final profile = VpnProfile.parseSubscription(testLink).single;
    container.read(sessionProvider.notifier).state = AsyncValue.data(
      Account({'status': 'active'}, [profile]),
    );
    final controller = container.read(vpnProvider.notifier);

    container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
    await controller.connect();
    expect(platform.lastDpiBypass, isTrue);
    expect(
      (jsonDecode(platform.lastConfig!) as Map)['outbounds'].any(
        (item) => item['protocol'] == 'vless',
      ),
      isFalse,
    );
    platform.emit(VlessStatus(state: 'CONNECTED'));
    await controller.disconnect();

    container.read(selectedServerProvider.notifier).state = profile.id;
    await controller.connect();
    expect(platform.lastDpiBypass, isFalse);
    expect(
      (jsonDecode(platform.lastConfig!) as Map)['outbounds'].any(
        (item) => item['protocol'] == 'vless',
      ),
      isTrue,
    );
    platform.emit(VlessStatus(state: 'CONNECTED'));
    await controller.disconnect();

    final requestCount = api.requests.length;
    container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
    await controller.connect();
    expect(platform.lastDpiBypass, isTrue);
    expect(platform.starts, 3);
    expect(platform.stops, 2);
    expect(api.requests, hasLength(requestCount));
    expect(
      (jsonDecode(platform.lastConfig!) as Map)['outbounds'].any(
        (item) => item['protocol'] == 'vless',
      ),
      isFalse,
    );
  });

  test(
    'legacy sniffing overrides do not replace imported profile defaults',
    () async {
      await XrayPreferences.setSniffingSettings(
        const XraySniffingSettings(
          enabled: true,
          destOverride: ['http', 'tls'],
          routeOnly: true,
          metadataOnly: true,
          domainsExcluded: ['domain:push.example.com'],
          ipsExcluded: ['10.0.0.0/8'],
        ),
      );

      await container.read(vpnProvider.notifier).connect();

      final config = jsonDecode(platform.lastConfig!) as Map<String, dynamic>;
      final sniffing = (config['inbounds'] as List).single['sniffing'];
      expect(sniffing, {
        'enabled': true,
        'destOverride': ['http', 'tls', 'quic'],
        'routeOnly': true,
      });
    },
  );

  test(
    'low-level server policy controls do not enter the client config',
    () async {
      await XrayPreferences.setPolicySettings(
        const XrayPolicySettings(
          handshakeSeconds: 47,
          statsUserOnline: true,
          statsOutboundUplink: false,
        ),
      );
      await container.read(vpnProvider.notifier).connect();
      final config = jsonDecode(platform.lastConfig!) as Map<String, dynamic>;
      expect(config.containsKey('policy'), isFalse);
      expect(config.containsKey('stats'), isFalse);
    },
  );

  test('arbitrary saved Xray JSON cannot override the client config', () async {
    await XrayPreferences.setCustomConfigSource(
      '{"routing":{"domainStrategy":"IPIfNonMatch"}}',
    );
    await container.read(vpnProvider.notifier).connect();
    final config = jsonDecode(platform.lastConfig!) as Map<String, dynamic>;
    expect(config.containsKey('routing'), isFalse);
    expect(config['outbounds'], hasLength(1));
  });
}
