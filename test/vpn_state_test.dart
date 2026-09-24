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
  int starts = 0;
  String? lastConfig;
  String? lastRemark;
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
  Future<bool> requestPermission() async => permission;
  @override
  Future<void> startVless({
    required String remark,
    required String config,
    required String notificationDisconnectButtonName,
    List<String>? blockedApps,
    List<String>? bypassSubnets,
    bool proxyOnly = false,
    String? geoAssetsDirectory,
    AndroidDnsPolicy androidDnsPolicy = AndroidDnsPolicy.config,
    String? androidDnsProxyOutboundTag,
  }) async {
    expect(proxyOnly, false);
    expect(androidDnsPolicy, AndroidDnsPolicy.proxy);
    starts++;
    lastRemark = remark;
    lastConfig = config;
  }

  @override
  Future<void> stopVless() async {
    emit(VlessStatus());
  }
}

class _FastestProbe extends ServerLatencyProbe {
  final checkedNames = <String>[];

  @override
  Future<int?> measure(VpnProfile profile) async {
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
    final controller = container.read(vpnProvider.notifier);
    await controller.initialize();

    platform.emit(VlessStatus(state: 'ERROR'));
    expect(container.read(vpnErrorProvider), isNotNull);
    await tester.pump(const Duration(seconds: 8));
    platform.emit(VlessStatus(state: 'ERROR'));
    await tester.pump(const Duration(seconds: 4));

    expect(container.read(vpnErrorProvider), isNull);
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
      final config = jsonDecode(platform.lastConfig!) as Map<String, dynamic>;
      final outbound = (config['outbounds'] as List).single;
      expect(outbound['settings']['vnext'][0]['port'], 444);
    },
  );
  test('permission denial never starts Xray', () async {
    platform.permission = false;
    await container.read(vpnProvider.notifier).connect();
    expect(platform.starts, 0);
    expect(container.read(vpnProvider), VpnState.error);
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
