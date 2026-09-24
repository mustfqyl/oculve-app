import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';

import 'profile_test.dart' show testLink;

void main() {
  final binary = Platform.environment['XRAY_TEST_BINARY'];

  test(
    'the real Xray core accepts every imported proxy protocol profile',
    () async {
      final zeroKey = base64Encode(List<int>.filled(32, 0));
      final profiles = VpnProfile.parseSubscription(
        jsonEncode([
          {
            'remarks': 'VLESS',
            'outbounds': [
              {
                'protocol': 'vless',
                'settings': {
                  'vnext': [
                    {
                      'address': 'vless.example',
                      'port': 443,
                      'users': [
                        {
                          'id': '11111111-1111-4111-8111-111111111111',
                          'encryption': 'none',
                        },
                      ],
                    },
                  ],
                },
                'streamSettings': {
                  'network': 'raw',
                  'security': 'tls',
                  'tlsSettings': {'serverName': 'vless.example'},
                },
              },
            ],
          },
          {
            'remarks': 'VMess',
            'outbounds': [
              {
                'protocol': 'vmess',
                'settings': {
                  'vnext': [
                    {
                      'address': 'vmess.example',
                      'port': 443,
                      'users': [
                        {
                          'id': '11111111-1111-4111-8111-111111111111',
                          'alterId': 0,
                          'security': 'auto',
                        },
                      ],
                    },
                  ],
                },
                'streamSettings': {'network': 'raw', 'security': 'tls'},
              },
            ],
          },
          {
            'remarks': 'Trojan',
            'outbounds': [
              {
                'protocol': 'trojan',
                'settings': {
                  'servers': [
                    {
                      'address': 'trojan.example',
                      'port': 443,
                      'password': 'test-secret',
                    },
                  ],
                },
                'streamSettings': {'network': 'raw', 'security': 'tls'},
              },
            ],
          },
          {
            'remarks': 'Shadowsocks',
            'outbounds': [
              {
                'protocol': 'shadowsocks',
                'settings': {
                  'servers': [
                    {
                      'address': 'ss.example',
                      'port': 8388,
                      'method': 'chacha20-poly1305',
                      'password': 'test-secret',
                    },
                  ],
                },
              },
            ],
          },
          {
            'remarks': 'SOCKS',
            'outbounds': [
              {
                'protocol': 'socks',
                'settings': {
                  'servers': [
                    {
                      'address': 'socks.example',
                      'port': 1080,
                      'users': [
                        {'user': 'test', 'pass': 'test-secret'},
                      ],
                    },
                  ],
                },
              },
            ],
          },
          {
            'remarks': 'HTTP proxy',
            'outbounds': [
              {
                'protocol': 'http',
                'settings': {
                  'servers': [
                    {
                      'address': 'http.example',
                      'port': 8080,
                      'users': [
                        {'user': 'test', 'pass': 'test-secret'},
                      ],
                    },
                  ],
                },
              },
            ],
          },
          {
            'remarks': 'Hysteria2',
            'outbounds': [
              {
                'protocol': 'hysteria',
                'settings': {
                  'version': 2,
                  'address': 'hysteria.example',
                  'port': 443,
                },
                'streamSettings': {
                  'network': 'hysteria',
                  'security': 'tls',
                  'tlsSettings': {'serverName': 'hysteria.example'},
                  'hysteriaSettings': {'version': 2, 'auth': 'test-secret'},
                },
              },
            ],
          },
          {
            'remarks': 'WireGuard',
            'outbounds': [
              {
                'protocol': 'wireguard',
                'settings': {
                  'secretKey': zeroKey,
                  'address': ['10.0.0.2/32'],
                  'peers': [
                    {
                      'endpoint': 'wg.example:51820',
                      'publicKey': zeroKey,
                      'allowedIPs': ['0.0.0.0/0'],
                    },
                  ],
                  'noKernelTun': true,
                },
              },
            ],
          },
        ]),
      );

      expect(profiles, hasLength(8));
      for (final profile in profiles) {
        final config = XrayPreferences.configure(
          profile.config,
          RealityFingerprint.serverDefault,
        );
        final process = await Process.start(binary!, [
          'run',
          '-test',
          '-config',
          'stdin:',
        ]);
        final stdout = process.stdout.transform(utf8.decoder).join();
        final stderr = process.stderr.transform(utf8.decoder).join();
        process.stdin.write(config);
        await process.stdin.close();
        final exitCode = await process.exitCode.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
        final output = await stdout;
        final errors = await stderr;
        expect(exitCode, 0, reason: '${profile.name}: $errors\n$output');
      }
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'the real Xray core accepts hybrid VLESS Encryption options',
    () async {
      final generated = await Process.run(binary!, ['mlkem768']);
      expect(generated.exitCode, 0, reason: generated.stderr.toString());
      final clientParameter = generated.stdout
          .toString()
          .split('\n')
          .firstWhere((line) => line.startsWith('Client: '))
          .substring('Client: '.length)
          .trim();
      final profile = VpnProfile.parseSubscription(testLink).single;

      for (final appearance in XrayVlessTrafficAppearance.values) {
        for (final resumption in XrayVlessResumption.values) {
          final config = XrayPreferences.configure(
            profile.config,
            RealityFingerprint.serverDefault,
            vlessEncryptionSettings: XrayVlessEncryptionSettings(
              serverAuthentication: clientParameter,
              trafficAppearance: appearance,
              resumption: resumption,
              padding: '100-111-1111.75-0-111.50-0-3333',
            ),
          );
          final process = await Process.start(binary, [
            'run',
            '-test',
            '-config',
            'stdin:',
          ]);
          final stdout = process.stdout.transform(utf8.decoder).join();
          final stderr = process.stderr.transform(utf8.decoder).join();
          process.stdin.write(config);
          await process.stdin.close();
          final exitCode = await process.exitCode.timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              process.kill(ProcessSignal.sigkill);
              return -1;
            },
          );
          final output = await stdout;
          final errors = await stderr;
          expect(
            exitCode,
            0,
            reason: '${appearance.name}/${resumption.value}: $errors\n$output',
          );
        }
      }
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'the real Xray core accepts advanced DNS and FakeDNS settings',
    () async {
      final profile = VpnProfile.parseSubscription(
        jsonEncode([
          {
            'remarks': 'VLESS TLS',
            'outbounds': [
              {
                'protocol': 'vless',
                'settings': {
                  'vnext': [
                    {
                      'address': 'vless.example',
                      'port': 443,
                      'users': [
                        {
                          'id': '11111111-1111-4111-8111-111111111111',
                          'encryption': 'none',
                        },
                      ],
                    },
                  ],
                },
                'streamSettings': {'network': 'raw', 'security': 'tls'},
              },
            ],
          },
        ]),
      ).single;
      final settings = const XrayDnsSettings(
        servers: [
          'https://1.1.1.1/dns-query',
          '{"address":"9.9.9.9","domains":["domain:example.test"],"expectedIPs":["192.0.2.0/24"],"skipFallback":true}',
        ],
        queryStrategy: DnsQueryStrategy.useSystem,
        serveStale: true,
        serveExpiredTtl: 300,
        disableFallback: false,
        disableFallbackIfMatch: true,
        enableParallelQuery: true,
        useSystemHosts: true,
        fakeDns: true,
        clientIp: '192.0.2.10',
        hosts: {'example.test': '192.0.2.20'},
      );
      settings.validate();
      final config = XrayPreferences.configure(
        profile.config,
        RealityFingerprint.serverDefault,
        dnsSettings: settings,
      );
      final process = await Process.start(binary!, [
        'run',
        '-test',
        '-config',
        'stdin:',
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(config);
      await process.stdin.close();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final output = await stdout;
      final errors = await stderr;
      expect(exitCode, 0, reason: '$errors\n$output');
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'the real Xray core accepts advanced TLS and native uTLS settings',
    () async {
      final profile = VpnProfile.parseSubscription(
        jsonEncode([
          {
            'remarks': 'VLESS TLS advanced',
            'outbounds': [
              {
                'protocol': 'vless',
                'settings': {
                  'vnext': [
                    {
                      'address': 'vless.example',
                      'port': 443,
                      'users': [
                        {
                          'id': '11111111-1111-4111-8111-111111111111',
                          'encryption': 'none',
                        },
                      ],
                    },
                  ],
                },
                'streamSettings': {
                  'network': 'raw',
                  'security': 'tls',
                  'tlsSettings': {'serverName': 'vless.example'},
                },
              },
            ],
          },
        ]),
      ).single;
      final config = XrayPreferences.configure(
        profile.config,
        RealityFingerprint.serverDefault,
        tlsSettings: const XrayTlsSettings(
          clientHelloFingerprint: 'HelloRandomizedNoALPN',
          serverName: 'front.example',
          verifyPeerCertByName: 'front.example,backup.example',
          alpn: 'h2,http/1.1',
          minVersion: '1.2',
          maxVersion: '1.3',
          enableSessionResumption: true,
          pinnedPeerCertSha256:
              '0000000000000000000000000000000000000000000000000000000000000000',
          curvePreferences: 'X25519,X25519MLKEM768',
          echConfigList:
              'AF7+DQBaAAAgACA51i3Ssu4wUMV4FNCc8iRX5J+YC4Bhigz9sacl2lCfSQAkAAEAAQABAAIAAQADAAIAAQACAAIAAgADAAMAAQADAAIAAwADAAtleGFtcGxlLmNvbQAA',
        ),
      );
      final process = await Process.start(binary!, [
        'run',
        '-test',
        '-config',
        'stdin:',
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(config);
      await process.stdin.close();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final output = await stdout;
      final errors = await stderr;
      expect(exitCode, 0, reason: '$errors\n$output');
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'the real Xray core accepts configurable sniffing protocols and exclusions',
    () async {
      final profile = VpnProfile.parseSubscription(testLink).single;
      final config = XrayPreferences.configure(
        profile.config,
        RealityFingerprint.serverDefault,
        sniffingSettings: const XraySniffingSettings(
          enabled: true,
          destOverride: ['http', 'tls', 'quic'],
          routeOnly: true,
          metadataOnly: false,
          domainsExcluded: [
            'full:api.example.com',
            'domain:push.example.com',
            r'regexp:^test[0-9]+\.internal$',
          ],
          ipsExcluded: ['192.168.1.1', '2001:db8::/32'],
        ),
      );
      final process = await Process.start(binary!, [
        'run',
        '-test',
        '-config',
        'stdin:',
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(config);
      await process.stdin.close();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final output = await stdout;
      final errors = await stderr;
      expect(exitCode, 0, reason: '$errors\n$output');
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'the real Xray core accepts XHTTP modes, XMUX and split download settings',
    () async {
      final profile = VpnProfile.parseSubscription(
        jsonEncode([
          {
            'remarks': 'VLESS XHTTP TLS',
            'outbounds': [
              {
                'protocol': 'vless',
                'settings': {
                  'vnext': [
                    {
                      'address': 'upload.example',
                      'port': 443,
                      'users': [
                        {
                          'id': '11111111-1111-4111-8111-111111111111',
                          'encryption': 'none',
                        },
                      ],
                    },
                  ],
                },
                'streamSettings': {
                  'network': 'xhttp',
                  'security': 'tls',
                  'tlsSettings': {'serverName': 'upload.example'},
                  'xhttpSettings': {'path': '/original'},
                },
              },
            ],
          },
        ]),
      ).single;
      final config = XrayPreferences.configure(
        profile.config,
        RealityFingerprint.serverDefault,
        xhttpSettings: const XrayXhttpSettings(
          mode: XrayXhttpMode.streamUp,
          host: 'edge.example',
          path: '/tunnel',
          headersJson: '{"X-Client":"Oculve"}',
          paddingBytes: '100-200',
          noGrpcHeader: XrayBooleanOverride.enabled,
          maxEachPostBytes: '1000000',
          minimumPostIntervalMs: '30-60',
          xmux: XrayXmuxSettings(
            maxConcurrency: '16-32',
            connectionReuseLimit: '0',
            maxRequestCount: '600-900',
            maxReusableSeconds: '1800-3000',
            keepAliveSeconds: '45',
          ),
          downloadSettingsJson:
              '{"address":"download.example","port":443,"network":"xhttp","security":"tls","tlsSettings":{"serverName":"download.example"},"xhttpSettings":{"path":"/download"}}',
          extraJson: '{"clientOption":true}',
        ),
      );
      final process = await Process.start(binary!, [
        'run',
        '-test',
        '-config',
        'stdin:',
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(config);
      await process.stdin.close();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final output = await stdout;
      final errors = await stderr;
      expect(exitCode, 0, reason: '$errors\n$output');
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'the real Xray core enforces imported minimum and maximum version guards',
    () async {
      for (final (guard, accepted) in [
        ({'min': '26.9.9', 'max': '26.9.9'}, true),
        ({'min': '26.9.10'}, false),
        ({'max': '26.9.8'}, false),
      ]) {
        final config =
            jsonDecode(
                  VpnProfile.parseSubscription(
                    jsonEncode([
                      {
                        'remarks': 'Version guarded VLESS TLS',
                        'version': guard,
                        'outbounds': [
                          {
                            'protocol': 'vless',
                            'settings': {
                              'vnext': [
                                {
                                  'address': 'vless.example',
                                  'port': 443,
                                  'users': [
                                    {
                                      'id':
                                          '11111111-1111-4111-8111-111111111111',
                                      'encryption': 'none',
                                    },
                                  ],
                                },
                              ],
                            },
                            'streamSettings': {
                              'network': 'raw',
                              'security': 'tls',
                              'tlsSettings': {'serverName': 'vless.example'},
                            },
                          },
                        ],
                      },
                    ]),
                  ).single.config,
                )
                as Map<String, dynamic>;
        final process = await Process.start(binary!, [
          'run',
          '-test',
          '-config',
          'stdin:',
        ]);
        final stdout = process.stdout.transform(utf8.decoder).join();
        final stderr = process.stderr.transform(utf8.decoder).join();
        process.stdin.write(jsonEncode(config));
        await process.stdin.close();
        final exitCode = await process.exitCode.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
        final output = await stdout;
        final errors = await stderr;
        expect(
          exitCode == 0,
          accepted,
          reason: 'guard=$guard\n$errors\n$output',
        );
      }
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'the real Xray core accepts connection policy and user/system statistics',
    () async {
      final profile = VpnProfile.parseSubscription(
        jsonEncode([
          {
            'remarks': 'Policy VLESS TLS',
            'outbounds': [
              {
                'protocol': 'vless',
                'settings': {
                  'vnext': [
                    {
                      'address': 'vless.example',
                      'port': 443,
                      'users': [
                        {
                          'id': '11111111-1111-4111-8111-111111111111',
                          'encryption': 'none',
                        },
                      ],
                    },
                  ],
                },
                'streamSettings': {
                  'network': 'raw',
                  'security': 'tls',
                  'tlsSettings': {'serverName': 'vless.example'},
                },
              },
            ],
          },
        ]),
      ).single;
      final config = XrayPreferences.configure(
        profile.config,
        RealityFingerprint.serverDefault,
        policySettings: const XrayPolicySettings(
          handshakeSeconds: 45,
          connectionIdleSeconds: 180,
          uplinkOnlySeconds: 2,
          downlinkOnlySeconds: 3,
          bufferSizeKb: 128,
          statsUserUplink: true,
          statsUserDownlink: true,
          statsUserOnline: true,
          statsInboundUplink: true,
          statsInboundDownlink: true,
          statsOutboundUplink: true,
          statsOutboundDownlink: true,
        ),
      );
      final process = await Process.start(binary!, [
        'run',
        '-test',
        '-config',
        'stdin:',
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(config);
      await process.stdin.close();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final output = await stdout;
      final errors = await stderr;
      expect(exitCode, 0, reason: '$errors\n$output');
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'the real Xray core accepts Happy Eyeballs and advanced TCP sockopts',
    () async {
      final profile = VpnProfile.parseSubscription(testLink).single;
      final config = XrayPreferences.configure(
        profile.config,
        RealityFingerprint.serverDefault,
        tcpSettings: const XrayTcpSettings(
          maxSegmentBytes: 1400,
          userTimeoutMs: 10000,
          congestionControl: XrayTcpCongestionControl.bbr,
          windowClampBytes: 262144,
          interfaceName: 'lo0',
          sendThroughAddress: '127.0.0.1',
          domainStrategy: XrayOutboundDomainStrategy.useIp,
          addressPortStrategy: XrayAddressPortStrategy.srvPortAndAddress,
          happyEyeballs: true,
          happyEyeballsDelayMs: 250,
          prioritizeIPv6: false,
          addressInterleave: 1,
          maxConcurrentAddressAttempts: 4,
        ),
      );
      final process = await Process.start(binary!, [
        'run',
        '-test',
        '-config',
        'stdin:',
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(config);
      await process.stdin.close();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final output = await stdout;
      final errors = await stderr;
      expect(exitCode, 0, reason: '$errors\n$output');
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'the real Xray core accepts advanced matchers and route actions',
    () async {
      final profile = VpnProfile.parseSubscription(testLink).single;
      final config = XrayPreferences.configure(
        profile.config,
        RealityFingerprint.serverDefault,
        routingRules: const [
          XrayRoutingRule(
            action: XrayRoutingAction.proxy,
            domains: ['full:example.com'],
            ports: ['443'],
            networks: ['tcp'],
            sourcePorts: ['50000-60000'],
            localPorts: ['1080'],
            sourceIps: ['192.0.2.0/24'],
            localIps: ['127.0.0.1'],
            inboundTags: ['tun-in'],
            users: ['client@example.com'],
            protocols: ['http', 'tls'],
            attributes: {':method': 'GET', ':path': '/api.*'},
            processes: ['browser'],
            ruleTag: 'local-api',
            webhook: XrayRoutingWebhook(
              url: 'https://hooks.example.com/route',
              deduplicationSeconds: 15,
              headers: {'X-API-Key': 'integration-test'},
            ),
          ),
          XrayRoutingRule(
            action: XrayRoutingAction.direct,
            ips: ['192.168.0.0/16'],
            networks: ['tcp', 'udp'],
          ),
          XrayRoutingRule(
            action: XrayRoutingAction.block,
            domains: ['domain:ads.example.com'],
            ports: ['53'],
            networks: ['udp'],
          ),
        ],
      );
      final process = await Process.start(binary!, [
        'run',
        '-test',
        '-config',
        'stdin:',
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(config);
      await process.stdin.close();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final output = await stdout;
      final errors = await stderr;
      expect(exitCode, 0, reason: '$errors\n$output');
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'the real Xray core accepts the custom JSON runtime overlay',
    () async {
      final profile = VpnProfile.parseSubscription(
        jsonEncode([
          {
            'remarks': 'Custom JSON VLESS TLS',
            'outbounds': [
              {
                'protocol': 'vless',
                'settings': {
                  'vnext': [
                    {
                      'address': 'vless.example',
                      'port': 443,
                      'users': [
                        {
                          'id': '11111111-1111-4111-8111-111111111111',
                          'encryption': 'none',
                        },
                      ],
                    },
                  ],
                },
                'streamSettings': {
                  'network': 'raw',
                  'security': 'tls',
                  'tlsSettings': {'serverName': 'vless.example'},
                },
              },
            ],
          },
        ]),
      ).single;
      final config = XrayPreferences.configure(
        profile.config,
        RealityFingerprint.serverDefault,
        customConfigOverrides: XrayPreferences.parseCustomConfigOverrides(
          '{"log":{"loglevel":"error"},"routing":{"domainStrategy":"IPIfNonMatch"},"stats":{}}',
        ),
      );
      final process = await Process.start(binary!, [
        'run',
        '-test',
        '-config',
        'stdin:',
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(config);
      await process.stdin.close();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final output = await stdout;
      final errors = await stderr;
      expect(exitCode, 0, reason: '$errors\n$output');
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'the real Xray core enforces configured minimum and maximum versions',
    () async {
      final profile = VpnProfile.parseSubscription(testLink).single;

      Future<(int, String)> check(String config) async {
        final process = await Process.start(binary!, [
          'run',
          '-test',
          '-config',
          'stdin:',
        ]);
        final stdout = process.stdout.transform(utf8.decoder).join();
        final stderr = process.stderr.transform(utf8.decoder).join();
        process.stdin.write(config);
        await process.stdin.close();
        final exitCode = await process.exitCode.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
        return (exitCode, '${await stderr}\n${await stdout}');
      }

      final accepted = XrayPreferences.configure(
        profile.config,
        RealityFingerprint.serverDefault,
        versionRequirement: const XrayVersionRequirement(
          minimum: '25.8.3',
          maximum: '26.9.9',
        ),
      );
      final (acceptedExitCode, acceptedOutput) = await check(accepted);
      expect(acceptedExitCode, 0, reason: acceptedOutput);

      final rejected = XrayPreferences.configure(
        profile.config,
        RealityFingerprint.serverDefault,
        versionRequirement: const XrayVersionRequirement(minimum: '99.0.0'),
      );
      final (rejectedExitCode, rejectedOutput) = await check(rejected);
      expect(rejectedExitCode, isNot(0), reason: rejectedOutput);
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'the real Xray core accepts the configured FinalMask transport layer',
    () async {
      final profile = VpnProfile.parseSubscription(testLink).single;
      final finalMask = XrayFinalMaskSettings.fromJsonText(
        '{"tcp":[{"type":"fragment","settings":{"packets":"tlshello","lengths":["100-200"],"delays":["10-20"]}}]}',
      );
      final config = XrayPreferences.configure(
        profile.config,
        RealityFingerprint.serverDefault,
        finalMaskSettings: finalMask,
      );
      final process = await Process.start(binary!, [
        'run',
        '-test',
        '-config',
        'stdin:',
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(config);
      await process.stdin.close();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      expect(exitCode, 0, reason: '${await stderr}\n${await stdout}');
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to the packaged Xray core executable.'
        : false,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
