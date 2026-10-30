import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';

import 'profile_test.dart' show testLink;

void main() {
  test(
    'VLESS Encryption is stored per profile and reaches its outbound',
    () async {
      SharedPreferences.setMockInitialValues({});
      final profile = VpnProfile.parseSubscription(testLink).single;
      final settings = XrayVlessEncryptionSettings(
        serverAuthentication: 'test_client_parameter_123',
        trafficAppearance: XrayVlessTrafficAppearance.xorpub,
        resumption: XrayVlessResumption.oneRtt,
        padding: '100-111-1111.75-0-111.50-0-3333',
      );

      await XrayPreferences.setVlessEncryptionSettingsFor(profile.id, settings);
      expect(
        (await XrayPreferences.vlessEncryptionSettingsFor(
          profile.id,
        ))?.toJson(),
        settings.toJson(),
      );

      final configured =
          jsonDecode(
                XrayPreferences.configure(
                  profile.config,
                  RealityFingerprint.serverDefault,
                  vlessEncryptionSettings: settings,
                ),
              )
              as Map<String, dynamic>;
      final outbound = (configured['outbounds'] as List).single;
      final user = outbound['settings']['vnext'][0]['users'][0];
      expect(
        user['encryption'],
        'mlkem768x25519plus.xorpub.1rtt.100-111-1111.75-0-111.50-0-3333.test_client_parameter_123',
      );

      await XrayPreferences.clearVlessEncryptionSettingsFor(profile.id);
      expect(
        await XrayPreferences.vlessEncryptionSettingsFor(profile.id),
        isNull,
      );
    },
  );

  test('VLESS Encryption rejects malformed authentication and padding', () {
    expect(
      () => const XrayVlessEncryptionSettings(
        serverAuthentication: 'invalid.parameter',
      ).toXrayValue(),
      throwsFormatException,
    );
    expect(
      () => const XrayVlessEncryptionSettings(
        serverAuthentication: 'valid_parameter',
        padding: '50-0-111',
      ).toXrayValue(),
      throwsFormatException,
    );
  });

  test('Reality fingerprint changes only the ClientHello selection', () {
    final original = VpnProfile.parseSubscription(testLink).single.config;
    final configured = XrayPreferences.configure(
      original,
      RealityFingerprint.firefox,
    );
    final before = jsonDecode(original) as Map<String, dynamic>;
    final after = jsonDecode(configured) as Map<String, dynamic>;
    final originalOutbound =
        (before['outbounds'] as List).single as Map<String, dynamic>;
    final configuredOutbound =
        (after['outbounds'] as List).single as Map<String, dynamic>;
    final originalStream =
        originalOutbound['streamSettings'] as Map<String, dynamic>;
    final configuredStream =
        configuredOutbound['streamSettings'] as Map<String, dynamic>;
    final reality = configuredStream['realitySettings'] as Map<String, dynamic>;
    expect(reality['fingerprint'], 'firefox');
    expect(configuredOutbound['settings'], originalOutbound['settings']);
    expect(
      reality['publicKey'],
      (originalStream['realitySettings'] as Map)['publicKey'],
    );
    expect(after['inbounds'], before['inbounds']);
    final defaultConfig =
        jsonDecode(
              XrayPreferences.configure(
                original,
                RealityFingerprint.serverDefault,
              ),
            )
            as Map<String, dynamic>;
    expect(defaultConfig['dns']['servers'], ['tcp://1.1.1.1']);
  });

  test('all verified Reality fingerprints map to their Xray names', () {
    final original = VpnProfile.parseSubscription(testLink).single.config;
    const supported = {
      RealityFingerprint.chrome: 'chrome',
      RealityFingerprint.firefox: 'firefox',
      RealityFingerprint.safari: 'safari',
    };
    for (final entry in supported.entries) {
      final config =
          jsonDecode(XrayPreferences.configure(original, entry.key))
              as Map<String, dynamic>;
      final outbound = (config['outbounds'] as List).single;
      final fingerprint =
          outbound['streamSettings']['realitySettings']['fingerprint'];
      expect(fingerprint, entry.value, reason: entry.key.label);
    }
  });

  test('TLS browser and custom native uTLS profiles reach Xray', () {
    final profile = VpnProfile.parseSubscription(testLink).single;
    final source = jsonDecode(profile.config) as Map<String, dynamic>;
    final stream =
        ((source['outbounds'] as List).single as Map<String, dynamic>)
                .putIfAbsent('streamSettings', () => <String, dynamic>{})
            as Map<String, dynamic>;
    final tlsStream = Map<String, dynamic>.from(stream)
      ..remove('realitySettings')
      ..['security'] = 'tls'
      ..['tlsSettings'] = {'serverName': 'node.example'};
    stream
      ..clear()
      ..addAll(tlsStream);

    final configured =
        jsonDecode(
              XrayPreferences.configure(
                jsonEncode(source),
                RealityFingerprint.chrome,
                tlsSettings: const XrayTlsSettings(
                  clientHelloFingerprint: 'HelloRandomizedNoALPN',
                  serverName: 'tls.example',
                  verifyPeerCertByName: 'verify.example,backup.example',
                  alpn: 'h2,http/1.1',
                  minVersion: '1.2',
                  maxVersion: '1.3',
                  allowInsecure: true,
                  enableSessionResumption: true,
                  pinnedPeerCertSha256:
                      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
                  curvePreferences: 'X25519,X25519MLKEM768',
                  masterKeyLog: '/tmp/xray-tls-keys.log',
                  echConfigList: 'https://1.1.1.1/dns-query',
                ),
              ),
            )
            as Map<String, dynamic>;
    final outbound = (configured['outbounds'] as List).single;
    final tls = outbound['streamSettings']['tlsSettings'] as Map;
    expect(tls['fingerprint'], 'HelloRandomizedNoALPN');
    expect(tls['serverName'], 'tls.example');
    expect(tls['verifyPeerCertByName'], 'verify.example,backup.example');
    expect(tls['alpn'], ['h2', 'http/1.1']);
    expect(tls['minVersion'], '1.2');
    expect(tls['maxVersion'], '1.3');
    expect(tls['allowInsecure'], isTrue);
    expect(tls['enableSessionResumption'], isTrue);
    expect(tls['pinnedPeerCertSha256'], 'a' * 64);
    expect(tls['curvePreferences'], ['X25519', 'X25519MLKEM768']);
    expect(tls['masterKeyLog'], '/tmp/xray-tls-keys.log');
    expect(tls['echConfigList'], 'https://1.1.1.1/dns-query');

    final secureDefaults =
        jsonDecode(
              XrayPreferences.configure(
                jsonEncode(source),
                RealityFingerprint.serverDefault,
              ),
            )
            as Map<String, dynamic>;
    final secureTls =
        (secureDefaults['outbounds'] as List)
                .single['streamSettings']['tlsSettings']
            as Map;
    expect(secureTls['allowInsecure'], isFalse);
    expect(secureTls['disableSystemRoot'], isFalse);
    expect(secureTls['enableSessionResumption'], isFalse);
  });

  test(
    'TLS settings persist and custom fingerprints also apply to Reality',
    () async {
      SharedPreferences.setMockInitialValues({});
      const settings = XrayTlsSettings(
        clientHelloFingerprint: 'HelloChrome_120',
        serverName: 'front.example',
      );
      await XrayPreferences.setTlsSettings(settings);
      expect((await XrayPreferences.tlsSettings()).toJson(), settings.toJson());

      final profile = VpnProfile.parseSubscription(testLink).single;
      final configured =
          jsonDecode(
                XrayPreferences.configure(
                  profile.config,
                  RealityFingerprint.firefox,
                  tlsSettings: settings,
                ),
              )
              as Map<String, dynamic>;
      final reality =
          (configured['outbounds'] as List)
                  .single['streamSettings']['realitySettings']
              as Map;
      expect(reality['fingerprint'], 'HelloChrome_120');
      expect(reality['serverName'], 'front.example');
    },
  );

  test('TLS certificate and ECH settings reject malformed values', () {
    expect(
      () => const XrayTlsSettings(
        clientHelloFingerprint: 'Chrome,please',
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const XrayTlsSettings(echConfigList: 'https://').validate(),
      throwsFormatException,
    );
    expect(
      () => const XrayTlsSettings(echConfigList: 'YQ==').validate(),
      throwsFormatException,
    );
    expect(
      () => const XrayTlsSettings(
        certificatePem: 'not a PEM certificate',
      ).validate(),
      throwsFormatException,
    );
  });

  test('XHTTP settings persist and merge into the imported transport', () async {
    SharedPreferences.setMockInitialValues({});
    const settings = XrayXhttpSettings(
      mode: XrayXhttpMode.streamUp,
      host: 'edge.example',
      path: '/custom',
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
      extraJson: '{"customClientOption":true}',
    );
    await XrayPreferences.setXhttpSettings(settings);
    expect((await XrayPreferences.xhttpSettings()).toJson(), settings.toJson());

    final original =
        jsonDecode(VpnProfile.parseSubscription(testLink).single.config)
            as Map<String, dynamic>;
    final outbound = (original['outbounds'] as List).single;
    final stream = Map<String, dynamic>.from(outbound['streamSettings'] as Map)
      ..['network'] = 'xhttp'
      ..['xhttpSettings'] = {
        'path': '/server-path',
        'extra': {'serverOption': 'preserved'},
      };
    outbound['streamSettings'] = stream;
    final configured =
        jsonDecode(
              XrayPreferences.configure(
                jsonEncode(original),
                RealityFingerprint.serverDefault,
                xhttpSettings: await XrayPreferences.xhttpSettings(),
              ),
            )
            as Map<String, dynamic>;
    final applied =
        ((configured['outbounds'] as List).single['streamSettings']
                as Map)['xhttpSettings']
            as Map;
    expect(applied['mode'], 'stream-up');
    expect(applied['host'], 'edge.example');
    expect(applied['path'], '/custom');
    expect(applied['extra']['headers'], {'X-Client': 'Oculve'});
    expect(applied['extra']['xPaddingBytes'], '100-200');
    expect(applied['extra']['noGRPCHeader'], isTrue);
    expect(applied['extra']['scMaxEachPostBytes'], 1000000);
    expect(applied['extra']['scMinPostsIntervalMs'], '30-60');
    expect(applied['extra']['xmux']['maxConcurrency'], '16-32');
    expect(applied['extra']['xmux']['hKeepAlivePeriod'], 45);
    expect(applied['extra']['downloadSettings']['address'], 'download.example');
    expect(applied['extra']['customClientOption'], isTrue);
    expect(applied['extra']['serverOption'], 'preserved');
  });

  test('XHTTP controls do not modify profiles on other transports', () {
    final profile = VpnProfile.parseSubscription(testLink).single;
    final configured =
        jsonDecode(
              XrayPreferences.configure(
                profile.config,
                RealityFingerprint.serverDefault,
                xhttpSettings: const XrayXhttpSettings(
                  host: 'edge.example',
                  path: '/custom',
                ),
              ),
            )
            as Map<String, dynamic>;
    final stream = (configured['outbounds'] as List).single['streamSettings'];
    expect(stream.containsKey('xhttpSettings'), isFalse);
  });

  test(
    'Xray policy persists and merges into the managed core config',
    () async {
      SharedPreferences.setMockInitialValues({});
      const settings = XrayPolicySettings(
        handshakeSeconds: 45,
        connectionIdleSeconds: 180,
        uplinkOnlySeconds: 2,
        downlinkOnlySeconds: 3,
        bufferSizeKb: 128,
        statsUserUplink: true,
        statsUserDownlink: true,
        statsUserOnline: true,
        statsInboundDownlink: false,
        statsOutboundUplink: false,
      );
      await XrayPreferences.setPolicySettings(settings);
      expect(
        (await XrayPreferences.policySettings()).toJson(),
        settings.toJson(),
      );

      final original =
          jsonDecode(VpnProfile.parseSubscription(testLink).single.config)
              as Map<String, dynamic>;
      original['policy'] = {
        'levels': {
          '0': {'handshake': 90, 'customField': 'preserved'},
          '1': {'connIdle': 20},
        },
        'system': {'customSystemField': true},
      };
      original['stats'] = {'customStatsField': true};
      final configured =
          jsonDecode(
                XrayPreferences.configure(
                  jsonEncode(original),
                  RealityFingerprint.serverDefault,
                  policySettings: await XrayPreferences.policySettings(),
                ),
              )
              as Map<String, dynamic>;
      final policy = configured['policy'] as Map<String, dynamic>;
      final levels = policy['levels'] as Map<String, dynamic>;
      expect(levels['0'], {
        'handshake': 45,
        'customField': 'preserved',
        'connIdle': 180,
        'uplinkOnly': 2,
        'downlinkOnly': 3,
        'bufferSize': 128,
        'statsUserUplink': true,
        'statsUserDownlink': true,
        'statsUserOnline': true,
      });
      expect(levels['1'], {'connIdle': 20});
      expect(policy['system'], {
        'customSystemField': true,
        'statsInboundUplink': true,
        'statsInboundDownlink': false,
        'statsOutboundUplink': false,
        'statsOutboundDownlink': true,
      });
      expect(configured['stats'], {'customStatsField': true});
    },
  );

  test('Xray policy rejects negative timeout and buffer values', () {
    expect(
      () => const XrayPolicySettings(handshakeSeconds: -1).validate(),
      throwsFormatException,
    );
    expect(
      () => const XrayPolicySettings(bufferSizeKb: -1).validate(),
      throwsFormatException,
    );
  });

  test(
    'XHTTP validation catches unsafe headers, ranges and download profiles',
    () {
      expect(
        () => const XrayXhttpSettings(
          headersJson: '{"X-Bad\\r\\n":"value"}',
        ).validate(),
        throwsFormatException,
      );
      expect(
        () => const XrayXhttpSettings(paddingBytes: '500-100').validate(),
        throwsFormatException,
      );
      expect(
        () => const XrayXhttpSettings(
          xmux: XrayXmuxSettings(maxConcurrency: '16', maxConnections: '4'),
        ).validate(),
        throwsFormatException,
      );
      expect(
        () => const XrayXhttpSettings(
          downloadSettingsJson: '{"address":"download.example"}',
        ).validate(),
        throwsFormatException,
      );
    },
  );

  test('Xray log level persists and replaces the core config value', () async {
    SharedPreferences.setMockInitialValues({});
    await XrayPreferences.setLogLevel(XrayLogLevel.debug);
    expect(await XrayPreferences.logLevel(), XrayLogLevel.debug);

    final profile = VpnProfile.parseSubscription(testLink).single;
    final config =
        jsonDecode(
              XrayPreferences.configure(
                profile.config,
                RealityFingerprint.serverDefault,
                logLevel: await XrayPreferences.logLevel(),
              ),
            )
            as Map<String, dynamic>;
    expect(config['log']['loglevel'], 'debug');
    expect(
      jsonDecode(profile.config)['log']['loglevel'],
      'warning',
      reason: 'The cached subscription profile must remain unchanged.',
    );
  });

  test('custom Xray JSON persists and merges into runtime settings', () async {
    SharedPreferences.setMockInitialValues({});
    const source =
        '{"log":{"loglevel":"error"},"routing":{"domainStrategy":"IPIfNonMatch","rules":[{"type":"field","domain":["domain:example.com"],"outboundTag":"proxy"}]}}';
    await XrayPreferences.setCustomConfigSource(source);
    expect(await XrayPreferences.customConfigSource(), source);

    final profile = VpnProfile.parseSubscription(testLink).single;
    final before = jsonDecode(profile.config) as Map<String, dynamic>;
    final configured =
        jsonDecode(
              XrayPreferences.configure(
                profile.config,
                RealityFingerprint.serverDefault,
                customConfigOverrides:
                    await XrayPreferences.customConfigOverrides(),
              ),
            )
            as Map<String, dynamic>;
    expect(configured['log']['loglevel'], 'error');
    expect(configured['routing']['domainStrategy'], 'IPIfNonMatch');
    expect(configured['routing']['rules'], [
      {
        'type': 'field',
        'domain': ['domain:example.com'],
        'outboundTag': 'proxy',
      },
    ]);
    expect(configured['inbounds'], before['inbounds']);
    expect(
      configured['outbounds'].single['settings'],
      before['outbounds'].single['settings'],
    );
  });

  test('custom Xray JSON rejects non-objects, nulls and oversized input', () {
    expect(
      () => XrayPreferences.parseCustomConfigOverrides('[]'),
      throwsFormatException,
    );
    expect(
      () => XrayPreferences.parseCustomConfigOverrides(
        '{"dns":{"hosts":{"example.test":null}}}',
      ),
      throwsFormatException,
    );
    expect(
      () => XrayPreferences.parseCustomConfigOverrides(' ' * 65537),
      throwsFormatException,
    );
  });

  test('site bypass appends a direct Xray outbound and domain routing', () {
    final original = VpnProfile.parseSubscription(testLink).single.config;
    final configured =
        jsonDecode(
              XrayPreferences.configure(
                original,
                RealityFingerprint.serverDefault,
                bypassDomains: [
                  'Example.COM',
                  'sub.example.com',
                  'example.com',
                ],
              ),
            )
            as Map<String, dynamic>;
    expect((configured['outbounds'] as List).last['protocol'], 'freedom');
    expect((configured['routing']['rules'] as List).single['domain'], [
      'domain:example.com',
      'domain:sub.example.com',
    ]);
    expect(XrayPreferences.normalizeDomains(['example.com', 'EXAMPLE.COM']), [
      'example.com',
    ]);
    expect(
      () => XrayPreferences.normalizeDomains(['*.example.com']),
      throwsFormatException,
    );
    expect(
      () => XrayPreferences.normalizeDomains(['localhost']),
      throwsFormatException,
    );
  });

  test('VPN-only domains route through proxy and all other traffic direct', () {
    final original = VpnProfile.parseSubscription(testLink).single.config;
    final configured =
        jsonDecode(
              XrayPreferences.configure(
                original,
                RealityFingerprint.serverDefault,
                bypassDomains: ['secure.example.com'],
                vpnOnlyDomains: true,
              ),
            )
            as Map<String, dynamic>;
    final rules = configured['routing']['rules'] as List;
    expect(rules, hasLength(2));
    expect(rules[0]['domain'], ['domain:secure.example.com']);
    expect(rules[0]['outboundTag'], 'proxy');
    expect(rules[1], {'type': 'field', 'outboundTag': 'direct'});
    expect(
      (configured['outbounds'] as List).any(
        (outbound) =>
            outbound['tag'] == 'direct' && outbound['protocol'] == 'freedom',
      ),
      isTrue,
    );
  });

  test('empty VPN-only domain list keeps the default VPN route', () {
    final original = VpnProfile.parseSubscription(testLink).single.config;
    final configured =
        jsonDecode(
              XrayPreferences.configure(
                original,
                RealityFingerprint.serverDefault,
                vpnOnlyDomains: true,
                routingRules: const [
                  XrayRoutingRule(
                    action: XrayRoutingAction.direct,
                    domains: ['domain:previously-routed.example'],
                  ),
                ],
              ),
            )
            as Map<String, dynamic>;
    expect(configured['routing']['rules'], isEmpty);
    expect((configured['outbounds'] as List).single['tag'], 'proxy');
  });

  test('DPI Bypass honors VPN-only domains with a direct fallback', () {
    final config = XrayPreferences.configureDpiBypass(
      localProxyPort: 65535,
      dnsSettings: const XrayDnsSettings(
        servers: ['https://cloudflare-dns.com/dns-query'],
      ),
      bypassDomains: ['secure.example.com'],
      vpnOnlyDomains: true,
      routingRules: const [
        XrayRoutingRule(
          action: XrayRoutingAction.block,
          domains: ['domain:blocked.example'],
        ),
      ],
    );
    final rules =
        (jsonDecode(config) as Map<String, dynamic>)['routing']['rules']
            as List;
    // rules[0] is the UDP 443 block and rules[1..2] are the ByeDPI probes.
    expect(rules[3]['domain'], ['domain:secure.example.com']);
    expect(rules[3]['outboundTag'], 'byedpi');
    expect(rules[4], {'type': 'field', 'outboundTag': 'direct'});
    expect(
      rules.any((rule) => rule['domain'] == ['domain:blocked.example']),
      isFalse,
    );
  });

  test('DPI Bypass addresses known DoH servers by IP, never by hostname', () {
    // ByeDPI runs with --no-domain and rejects hostname targets, so a DoH
    // server given by name can never be resolved through the byedpi outbound.
    final config =
        jsonDecode(
              XrayPreferences.configureDpiBypass(
                localProxyPort: 65535,
                dnsSettings: const XrayDnsSettings(
                  servers: [
                    'https://cloudflare-dns.com/dns-query',
                    'https://dns.google/dns-query',
                    'https://dns.quad9.net:5053/dns-query',
                    'https://resolver.example/dns-query',
                    '{"address":"https://dns.google/dns-query","domains":["a.example"]}',
                  ],
                ),
              ),
            )
            as Map<String, dynamic>;
    // Unknown hostnames are dropped: ByeDPI cannot dial them and they have no IP.
    expect(config['dns']['servers'], [
      'https://1.1.1.1/dns-query',
      'https://8.8.8.8/dns-query',
      'https://9.9.9.9:5053/dns-query',
      {
        'address': 'https://8.8.8.8/dns-query',
        'domains': ['a.example'],
      },
    ]);
  });

  test('DPI Bypass drops unresolvable DNS hostnames and keeps IP entries', () {
    final servers = XrayPreferences.dpiDnsServers([
      'https://resolver.example/dns-query',
      'localhost',
      'tcp://dns.google:53',
      'tcp://1.0.0.1',
      'https://1.0.0.1/dns-query',
      '2001:4860:4860::8888',
      '[2001:4860:4860::8888]:5353',
      'h2c://[2001:4860:4860::6464]/dns-query',
      {'address': 'quic+local://dns.example', 'port': 853},
      {'address': 'https://dns.quad9.net/dns-query', 'skipFallback': true},
    ]);
    expect(servers, [
      'tcp://8.8.8.8:53',
      'tcp://1.0.0.1',
      'https://1.0.0.1/dns-query',
      '2001:4860:4860::8888',
      '[2001:4860:4860::8888]:5353',
      'h2c://[2001:4860:4860::6464]/dns-query',
      {'address': 'https://9.9.9.9/dns-query', 'skipFallback': true},
    ]);
  });

  test('DPI Bypass falls back to IP DoH servers when all are dropped', () {
    final servers = XrayPreferences.dpiDnsServers([
      'https://resolver.example/dns-query',
      'localhost',
    ]);
    expect(servers, [
      'https://1.1.1.1/dns-query',
      'https://8.8.8.8/dns-query',
      'https://9.9.9.9/dns-query',
    ]);
  });

  test('DPI Bypass config never names a DNS server by hostname', () {
    final config =
        jsonDecode(
              XrayPreferences.configureDpiBypass(
                localProxyPort: 65535,
                dnsSettings: const XrayDnsSettings(
                  servers: [
                    'https://cloudflare-dns.com/dns-query',
                    'tcp://dns.google',
                    'https://resolver.example/dns-query',
                    'localhost',
                    '9.9.9.9',
                    '{"address":"https://dns.quad9.net/dns-query"}',
                  ],
                ),
              ),
            )
            as Map<String, dynamic>;
    final servers = config['dns']['servers'] as List;
    expect(servers, isNotEmpty);
    for (final server in servers) {
      final address = server is Map ? server['address'] as String : server;
      final host = Uri.parse(
        address.contains('://') ? address : 'tcp://$address',
      ).host;
      expect(InternetAddress.tryParse(host), isNotNull, reason: address);
    }
  });

  test('DPI Bypass blocks QUIC (UDP 443) before any domain rule', () {
    final config =
        jsonDecode(
              XrayPreferences.configureDpiBypass(
                localProxyPort: 65535,
                dnsSettings: const XrayDnsSettings(
                  servers: ['https://cloudflare-dns.com/dns-query'],
                ),
                routingRules: const [
                  XrayRoutingRule(
                    action: XrayRoutingAction.direct,
                    domains: ['domain:quic.example'],
                    networks: ['udp'],
                  ),
                ],
              ),
            )
            as Map<String, dynamic>;
    final rules = config['routing']['rules'] as List;
    expect(rules.first, {
      'type': 'field',
      'network': 'udp',
      'port': '443',
      'outboundTag': 'block',
    });
    // Other UDP, including DNS on port 53, is not blocked.
    expect(rules.where((rule) => rule['outboundTag'] == 'block'), hasLength(1));
  });

  test('DPI Bypass accepts profiles 0-6 and rejects anything else', () {
    String build(int profile) => XrayPreferences.configureDpiBypass(
      localProxyPort: 65535,
      dpiProfile: profile,
      dnsSettings: const XrayDnsSettings(
        servers: ['https://cloudflare-dns.com/dns-query'],
      ),
    );
    for (final profile in [0, 4, 5, 6]) {
      expect(() => build(profile), returnsNormally, reason: '$profile');
      expect(
        (jsonDecode(build(profile)) as Map)['oculveDpiProfile'],
        profile,
        reason: '$profile',
      );
    }
    for (final profile in [-1, 7]) {
      expect(
        () => build(profile),
        throwsA(isA<FormatException>()),
        reason: '$profile',
      );
    }
  });

  test('structured routing creates Xray proxy, direct and block rules', () {
    final original = VpnProfile.parseSubscription(testLink).single.config;
    final configured =
        jsonDecode(
              XrayPreferences.configure(
                original,
                RealityFingerprint.serverDefault,
                bypassDomains: ['example.com'],
                routingRules: const [
                  XrayRoutingRule(
                    action: XrayRoutingAction.proxy,
                    domains: ['full:login.example.com'],
                    ports: ['443', '8000-8100'],
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
                      deduplicationSeconds: 30,
                      headers: {'X-API-Key': 'test-key'},
                    ),
                  ),
                  XrayRoutingRule(
                    action: XrayRoutingAction.direct,
                    ips: ['192.168.0.0/16', 'geoip:private'],
                    networks: ['tcp', 'udp'],
                  ),
                  XrayRoutingRule(
                    action: XrayRoutingAction.block,
                    domains: ['geosite:category-ads-all'],
                    ports: ['53'],
                    networks: ['udp'],
                  ),
                ],
              ),
            )
            as Map<String, dynamic>;

    final routing = configured['routing'] as Map<String, dynamic>;
    final rules = routing['rules'] as List;
    expect(routing['domainStrategy'], 'IPIfNonMatch');
    expect(rules[0], {
      'type': 'field',
      'domain': ['full:login.example.com'],
      'port': '443,8000-8100',
      'sourcePort': '50000-60000',
      'localPort': '1080',
      'network': 'tcp',
      'sourceIP': ['192.0.2.0/24'],
      'localIP': ['127.0.0.1'],
      'inboundTag': ['tun-in'],
      'user': ['client@example.com'],
      'protocol': ['http', 'tls'],
      'attrs': {':method': 'GET', ':path': '/api.*'},
      'process': ['browser'],
      'ruleTag': 'local-api',
      'webhook': {
        'url': 'https://hooks.example.com/route',
        'deduplication': 30,
        'headers': {'X-API-Key': 'test-key'},
      },
      'outboundTag': 'proxy',
    });
    expect(rules[1]['outboundTag'], 'direct');
    expect(rules[2]['outboundTag'], 'block');
    expect(rules[3]['outboundTag'], 'direct');
    final outbounds = configured['outbounds'] as List;
    expect(
      outbounds.singleWhere((item) => item['tag'] == 'direct')['protocol'],
      'freedom',
    );
    expect(
      outbounds.singleWhere((item) => item['tag'] == 'block')['protocol'],
      'blackhole',
    );
  });

  test('routing rules validate core matchers and parse HTTP attributes', () {
    expect(
      XrayRoutingRule.parseDomains('Example.com\nfull:login.example.com'),
      ['domain:example.com', 'full:login.example.com'],
    );
    expect(
      () => const XrayRoutingRule(
        action: XrayRoutingAction.direct,
        ips: ['192.168.1.0/33'],
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const XrayRoutingRule(
        action: XrayRoutingAction.direct,
        ports: ['8100-8000'],
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const XrayRoutingRule(
        action: XrayRoutingAction.direct,
        networks: ['icmp'],
      ).validate(),
      throwsFormatException,
    );
    expect(XrayRoutingRule.parseAttributes(':method=GET\n:path=/api.*'), {
      ':method': 'GET',
      ':path': '/api.*',
    });
    expect(
      () => XrayRoutingRule.parseAttributes('missing-separator'),
      throwsFormatException,
    );
    expect(
      () => const XrayRoutingRule(
        action: XrayRoutingAction.proxy,
        protocols: ['smtp'],
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const XrayRoutingWebhook(
        url: 'https://user:password@hooks.example.com/route',
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => XrayRoutingWebhook.fromEditor(
        url: 'https://hooks.example.com/route',
        deduplicationSeconds: '30',
        headersJson: '{"X-API-Key": 123}',
      ),
      throwsFormatException,
    );
  });

  test(
    'routing rules persist and reload without changing match semantics',
    () async {
      SharedPreferences.setMockInitialValues({});
      const rules = [
        XrayRoutingRule(
          action: XrayRoutingAction.block,
          domains: ['domain:ads.example'],
          ips: ['203.0.113.0/24'],
          ports: ['53'],
          networks: ['udp'],
          sourcePorts: ['40000-50000'],
          localPorts: ['1080'],
          sourceIps: ['198.51.100.0/24'],
          localIps: ['127.0.0.1'],
          inboundTags: ['local-socks'],
          users: ['test@example.com'],
          protocols: ['http', 'tls'],
          attributes: {':method': 'GET', 'accept': 'text/html'},
          processes: ['browser'],
          ruleTag: 'test-route',
          webhook: XrayRoutingWebhook(
            url: 'https://hooks.example.com/route',
            deduplicationSeconds: 15,
            headers: {'Authorization': 'Bearer test'},
          ),
        ),
      ];
      await XrayPreferences.setRoutingRules(rules);
      final loaded = await XrayPreferences.routingRules();
      expect(loaded.single.toJson(), rules.single.toJson());
    },
  );

  test('sniffing controls persist and reach the Xray inbound config', () async {
    SharedPreferences.setMockInitialValues({});
    const settings = XraySniffingSettings(
      enabled: false,
      destOverride: ['tls', 'quic'],
      routeOnly: false,
      metadataOnly: true,
      domainsExcluded: ['api.example.com', 'full:push.example.com'],
      ipsExcluded: ['192.0.2.1', '2001:db8::/32'],
    );
    await XrayPreferences.setSniffingSettings(settings);
    final loaded = await XrayPreferences.sniffingSettings();
    expect(loaded.toJson(), {
      'enabled': false,
      'destOverride': ['tls', 'quic'],
      'routeOnly': false,
      'metadataOnly': true,
      'domainsExcluded': ['domain:api.example.com', 'full:push.example.com'],
      'ipsExcluded': ['192.0.2.1', '2001:db8::/32'],
    });

    final profile = VpnProfile.parseSubscription(testLink).single;
    final config =
        jsonDecode(
              XrayPreferences.configure(
                profile.config,
                RealityFingerprint.serverDefault,
                sniffingSettings: loaded,
              ),
            )
            as Map<String, dynamic>;
    expect(
      (config['inbounds'] as List).single['sniffing'],
      loaded.toXrayJson(),
    );
  });

  test('FakeDNS keeps the sniffing recovery path enabled', () {
    final profile = VpnProfile.parseSubscription(testLink).single;
    final config =
        jsonDecode(
              XrayPreferences.configure(
                profile.config,
                RealityFingerprint.serverDefault,
                dnsSettings: const XrayDnsSettings(
                  servers: ['https://dns.google/dns-query'],
                  fakeDns: true,
                ),
                sniffingSettings: const XraySniffingSettings(
                  enabled: false,
                  destOverride: ['tls'],
                  metadataOnly: true,
                ),
              ),
            )
            as Map<String, dynamic>;
    final sniffing = (config['inbounds'] as List).single['sniffing'];
    expect(sniffing['enabled'], true);
    expect(sniffing['destOverride'], ['tls', 'fakedns']);
    expect(sniffing['metadataOnly'], true);
  });

  test('sniffing rejects unsupported sniffers and malformed exclusions', () {
    expect(
      () => const XraySniffingSettings(destOverride: ['ssh']).validate(),
      throwsFormatException,
    );
    expect(
      () =>
          const XraySniffingSettings(domainsExcluded: ['regexp:[']).validate(),
      throwsFormatException,
    );
    expect(
      () => const XraySniffingSettings(ipsExcluded: ['300.1.1.1']).validate(),
      throwsFormatException,
    );
  });

  test(
    'core version bounds persist and enter the guarded Xray config',
    () async {
      SharedPreferences.setMockInitialValues({});
      const requirement = XrayVersionRequirement(
        minimum: '26.9.9',
        maximum: '26.10.2',
      );
      await XrayPreferences.setVersionRequirement(requirement);
      final loaded = await XrayPreferences.versionRequirement();
      expect(loaded?.minimum, '26.9.9');
      expect(loaded?.maximum, '26.10.2');

      final profile = VpnProfile.parseSubscription(testLink).single;
      final config =
          jsonDecode(
                XrayPreferences.configure(
                  profile.config,
                  RealityFingerprint.serverDefault,
                  versionRequirement: loaded,
                ),
              )
              as Map<String, dynamic>;
      expect(config['version'], {'min': '26.9.9', 'max': '26.10.2'});

      await XrayPreferences.setVersionRequirement(
        const XrayVersionRequirement(),
      );
      expect(await XrayPreferences.versionRequirement(), isNull);
    },
  );

  test('core version bounds reject malformed or reversed ranges', () {
    expect(
      () => const XrayVersionRequirement(minimum: 'v26.9.9').validate(),
      throwsFormatException,
    );
    expect(
      () => const XrayVersionRequirement(
        minimum: '26.10.0',
        maximum: '26.9.99',
      ).validate(),
      throwsFormatException,
    );
  });

  test(
    'FinalMask settings persist and merge into the selected Xray stream',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = XrayFinalMaskSettings.fromJsonText(
        '{"tcp":[{"type":"fragment","settings":{"packets":"tlshello","lengths":["100-200"]}}]}',
      );
      await XrayPreferences.setFinalMaskSettings(settings);

      final loaded = await XrayPreferences.finalMaskSettings();
      expect(loaded.toXrayJson(), settings.toXrayJson());
      final profile = VpnProfile.parseSubscription(testLink).single;
      final configured =
          jsonDecode(
                XrayPreferences.configure(
                  profile.config,
                  RealityFingerprint.serverDefault,
                  finalMaskSettings: loaded,
                ),
              )
              as Map<String, dynamic>;
      final outbound = (configured['outbounds'] as List).single;
      final stream = outbound['streamSettings'] as Map<String, dynamic>;
      expect(stream['finalmask'], settings.toXrayJson());

      await XrayPreferences.setFinalMaskSettings(const XrayFinalMaskSettings());
      expect(
        await XrayPreferences.finalMaskSettings(),
        const XrayFinalMaskSettings(),
      );
    },
  );

  test('FinalMask input rejects unknown fields and malformed mask entries', () {
    expect(
      () => XrayFinalMaskSettings.fromJsonText('{"tcp":{},"x":true}'),
      throwsFormatException,
    );
    expect(
      () => XrayFinalMaskSettings.fromJsonText('{"tcp":[{"type":"fragment"}]}'),
      throwsFormatException,
    );
  });

  test(
    'site bypass preserves existing routes and resolves direct tag clashes',
    () {
      final profile = VpnProfile.parseSubscription(testLink).single;
      final source = jsonDecode(profile.config) as Map<String, dynamic>;
      final rules = [
        {
          'type': 'field',
          'ip': ['geoip:private'],
          'outboundTag': 'block',
        },
      ];
      source['routing'] = {
        'domainStrategy': 'IPIfNonMatch',
        'rules': rules,
        'balancers': [
          {
            'tag': 'region-pool',
            'selector': ['eu-'],
          },
        ],
      };
      (source['outbounds'] as List).add({
        'tag': 'direct',
        'protocol': 'blackhole',
      });

      final configured =
          jsonDecode(
                XrayPreferences.configure(
                  jsonEncode(source),
                  RealityFingerprint.serverDefault,
                  bypassDomains: ['example.com'],
                ),
              )
              as Map<String, dynamic>;
      final routing = configured['routing'] as Map<String, dynamic>;
      final configuredRules = routing['rules'] as List;
      final bypass = configuredRules.first as Map<String, dynamic>;

      expect(routing['domainStrategy'], 'IPIfNonMatch');
      expect(routing['balancers'], source['routing']['balancers']);
      expect(configuredRules.skip(1).single, rules.single);
      expect(bypass['outboundTag'], 'direct-2');
      expect(
        (configured['outbounds'] as List)
            .where((outbound) => outbound['tag'] == 'direct')
            .single['protocol'],
        'blackhole',
      );
      expect(
        (configured['outbounds'] as List)
            .where((outbound) => outbound['tag'] == 'direct-2')
            .single['protocol'],
        'freedom',
      );
    },
  );

  test('site bypass reuses an existing freedom outbound named direct', () {
    final profile = VpnProfile.parseSubscription(testLink).single;
    final source = jsonDecode(profile.config) as Map<String, dynamic>;
    (source['outbounds'] as List).add({
      'tag': 'direct',
      'protocol': 'freedom',
      'settings': {'domainStrategy': 'UseIPv4'},
    });

    final configured =
        jsonDecode(
              XrayPreferences.configure(
                jsonEncode(source),
                RealityFingerprint.serverDefault,
                bypassDomains: ['example.com'],
              ),
            )
            as Map<String, dynamic>;
    final outbounds = configured['outbounds'] as List;
    expect(outbounds.where((item) => item['tag'] == 'direct'), hasLength(1));
    expect(outbounds.last['settings'], {'domainStrategy': 'UseIPv4'});
    expect(
      (configured['routing']['rules'] as List).first['outboundTag'],
      'direct',
    );
  });

  test('selected DNS is an IPv4 TCP resolver with fallback disabled', () {
    final original = VpnProfile.parseSubscription(testLink).single.config;
    final config =
        jsonDecode(
              XrayPreferences.configure(
                original,
                RealityFingerprint.serverDefault,
                dnsResolver: DnsResolver.quad9,
              ),
            )
            as Map<String, dynamic>;
    expect(config['dns']['servers'], ['tcp://9.9.9.9']);
    expect(config['dns']['queryStrategy'], 'UseIPv4');
    expect(config['dns']['disableFallback'], isTrue);
  });

  test(
    'custom DNS is validated, persisted and written to the Xray config',
    () async {
      SharedPreferences.setMockInitialValues({});
      await XrayPreferences.setCustomDnsAddress(' 149.112.112.112 ');
      await XrayPreferences.setDnsResolver(DnsResolver.custom);
      final address = await XrayPreferences.dnsServerAddress();
      expect(address, '149.112.112.112');

      final profile = VpnProfile.parseSubscription(testLink).single;
      final config =
          jsonDecode(
                XrayPreferences.configure(
                  profile.config,
                  RealityFingerprint.serverDefault,
                  dnsResolver: DnsResolver.custom,
                  dnsServer: address,
                ),
              )
              as Map<String, dynamic>;
      expect(config['dns']['servers'], ['tcp://149.112.112.112']);
      expect(config['dns']['queryStrategy'], 'UseIPv4');
      expect(config['dns']['disableFallback'], isTrue);
      await expectLater(
        XrayPreferences.setCustomDnsAddress('resolver.example'),
        throwsFormatException,
      );
      await expectLater(
        XrayPreferences.setCustomDnsAddress('2001:4860:4860::8888'),
        throwsFormatException,
      );
    },
  );

  test('advanced DNS settings persist and are applied to Xray', () async {
    SharedPreferences.setMockInitialValues({});
    const settings = XrayDnsSettings(
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
    await XrayPreferences.setDnsSettings(settings);
    final saved = await XrayPreferences.dnsSettings();
    expect(saved.toJson(), settings.toJson());

    final profile = VpnProfile.parseSubscription(testLink).single;
    final config =
        jsonDecode(
              XrayPreferences.configure(
                profile.config,
                RealityFingerprint.serverDefault,
                dnsSettings: saved,
              ),
            )
            as Map<String, dynamic>;
    final dns = config['dns'] as Map<String, dynamic>;
    expect(dns['servers'], [
      'fakedns',
      'https://1.1.1.1/dns-query',
      {
        'address': '9.9.9.9',
        'domains': ['domain:example.test'],
        'expectedIPs': ['192.0.2.0/24'],
        'skipFallback': true,
      },
    ]);
    expect(dns['queryStrategy'], 'UseSystem');
    expect(dns['serveStale'], true);
    expect(dns['serveExpiredTTL'], 300);
    expect(dns['disableFallbackIfMatch'], true);
    expect(dns['enableParallelQuery'], true);
    expect(dns['useSystemHosts'], true);
    expect(dns['clientIp'], '192.0.2.10');
    expect(dns['hosts'], {'example.test': '192.0.2.20'});
    final inbound = (config['inbounds'] as List).single;
    expect(inbound['sniffing']['destOverride'], contains('fakedns'));
    expect(inbound['sniffing']['metadataOnly'], false);
  });

  test(
    'existing custom IPv4 DNS preference migrates to the new settings',
    () async {
      SharedPreferences.setMockInitialValues({
        'xray.dns.resolver.v1': 'custom',
        'xray.dns.custom_address.v1': '149.112.112.112',
      });
      final migrated = await XrayPreferences.dnsSettings();
      expect(migrated.servers, ['tcp://149.112.112.112']);
      expect(migrated.queryStrategy, DnsQueryStrategy.useIPv4);
    },
  );

  test('DNS settings reject invalid endpoints and EDNS addresses', () {
    expect(
      () => const XrayDnsSettings(servers: ['https://dns.google']).validate(),
      throwsFormatException,
    );
    expect(
      () => const XrayDnsSettings(clientIp: 'not-an-ip').validate(),
      throwsFormatException,
    );
    expect(
      () => const XrayDnsSettings(
        servers: ['{"address":"1.1.1.1","port":70000}'],
      ).validate(),
      throwsFormatException,
    );
    expect(
      XrayDnsSettings.validateDnsServer('2001:4860:4860::8888'),
      '2001:4860:4860::8888',
    );
    expect(
      XrayDnsSettings.validateDnsServer('[2001:4860:4860::8888]:5353'),
      '[2001:4860:4860::8888]:5353',
    );
    expect(
      () => const XrayDnsSettings(
        hosts: {'example.test': 'not an address'},
      ).validate(),
      throwsFormatException,
    );
  });

  test(
    'TCP socket preferences persist and become real Xray outbound options',
    () async {
      SharedPreferences.setMockInitialValues({});
      const settings = XrayTcpSettings(
        fastOpenMode: TcpFastOpenMode.enabled,
        keepAliveIdle: 60,
        keepAliveInterval: 15,
        maxSegmentBytes: 1400,
        userTimeoutMs: 10000,
        congestionControl: XrayTcpCongestionControl.bbr,
        windowClampBytes: 262144,
        interfaceName: 'en0',
        sendThroughAddress: '192.0.2.10',
        domainStrategy: XrayOutboundDomainStrategy.useIp,
        addressPortStrategy: XrayAddressPortStrategy.srvPortAndAddress,
        happyEyeballs: true,
        happyEyeballsDelayMs: 350,
        prioritizeIPv6: true,
        addressInterleave: 2,
        maxConcurrentAddressAttempts: 6,
      );
      await XrayPreferences.setTcpSettings(settings);
      final saved = await XrayPreferences.tcpSettings();
      expect(saved.toJson(), settings.toJson());
      expect(saved.sendThroughAddress, '192.0.2.10');

      final profile = VpnProfile.parseSubscription(testLink).single;
      final config =
          jsonDecode(
                XrayPreferences.configure(
                  profile.config,
                  RealityFingerprint.serverDefault,
                  tcpSettings: saved,
                ),
              )
              as Map<String, dynamic>;
      expect(
        config['outbounds'][0]['streamSettings']['sockopt'],
        containsPair('tcpFastOpen', true),
      );
      expect(
        config['outbounds'][0]['streamSettings']['sockopt'],
        containsPair('tcpKeepAliveIdle', 60),
      );
      expect(
        config['outbounds'][0]['streamSettings']['sockopt'],
        containsPair('tcpKeepAliveInterval', 15),
      );
      final socketOptions =
          config['outbounds'][0]['streamSettings']['sockopt'] as Map;
      expect(socketOptions['tcpMaxSeg'], 1400);
      expect(socketOptions['tcpUserTimeout'], 10000);
      expect(socketOptions['tcpcongestion'], 'bbr');
      expect(socketOptions['tcpWindowClamp'], 262144);
      expect(socketOptions['interface'], 'en0');
      expect(socketOptions['addressPortStrategy'], 'SrvPortAndAddress');
      expect(socketOptions['domainStrategy'], 'UseIP');
      expect(socketOptions['happyEyeballs'], {
        'tryDelayMs': 350,
        'prioritizeIPv6': true,
        'interleave': 2,
        'maxConcurrentTry': 6,
      });
      expect(config['outbounds'][0]['sendThrough'], '192.0.2.10');
      expect(
        () => const XrayTcpSettings(keepAliveIdle: 86401).validate(),
        throwsFormatException,
      );
      expect(
        () => const XrayTcpSettings(happyEyeballs: true).validate(),
        throwsFormatException,
      );
      expect(
        const XrayTcpSettings().toJson().containsKey('tcpFastOpen'),
        isFalse,
      );
      expect(
        () => settings.copyWith(maxSegmentBytes: 65536).validate(),
        throwsFormatException,
      );
      expect(
        () => settings.copyWith(sendThroughAddress: 'example.test').validate(),
        throwsFormatException,
      );
    },
  );

  test('TCP socket tuning is not injected into UDP proxy protocols', () {
    final source = jsonEncode({
      'outbounds': [
        {
          'tag': 'proxy',
          'protocol': 'wireguard',
          'settings': {'secretKey': 'secret', 'peers': []},
        },
      ],
    });
    final configured =
        jsonDecode(
              XrayPreferences.configure(
                source,
                RealityFingerprint.serverDefault,
                tcpSettings: const XrayTcpSettings(
                  fastOpenMode: TcpFastOpenMode.enabled,
                  keepAliveIdle: 30,
                  keepAliveInterval: 10,
                ),
              ),
            )
            as Map<String, dynamic>;

    expect(configured['outbounds'][0].containsKey('streamSettings'), isFalse);
  });

  test(
    'Mux and XUDP preferences are persisted and enter the core config',
    () async {
      SharedPreferences.setMockInitialValues({});
      const settings = XrayMuxSettings(
        enabled: true,
        concurrency: 32,
        xudpConcurrency: 64,
        udp443Behavior: Udp443Behavior.skip,
      );
      await XrayPreferences.setMuxSettings(settings);
      expect((await XrayPreferences.muxSettings()).toJson(), settings.toJson());

      final profile = VpnProfile.parseSubscription(
        testLink.replaceAll('&flow=xtls-rprx-vision', ''),
      ).single;
      final configured =
          jsonDecode(
                XrayPreferences.configure(
                  profile.config,
                  RealityFingerprint.serverDefault,
                  muxSettings: await XrayPreferences.muxSettings(),
                ),
              )
              as Map<String, dynamic>;
      expect(
        (configured['outbounds'] as List).single['mux'],
        settings.toJson(),
      );
    },
  );

  test(
    'VLESS Vision rejects Mux because the real Xray core cannot combine them',
    () {
      final profile = VpnProfile.parseSubscription(testLink).single;
      expect(
        XrayPreferences.muxIncompatibility(profile.config),
        contains('VLESS Vision'),
      );
      expect(
        () => XrayPreferences.configure(
          profile.config,
          RealityFingerprint.serverDefault,
          muxSettings: const XrayMuxSettings(enabled: true),
        ),
        throwsFormatException,
      );
    },
  );

  test('disabled Mux also disables XUDP in the actual runtime config', () {
    final profile = VpnProfile.parseSubscription(testLink).single;
    final configured =
        jsonDecode(
              XrayPreferences.configure(
                profile.config,
                RealityFingerprint.serverDefault,
              ),
            )
            as Map<String, dynamic>;
    expect((configured['outbounds'] as List).single['mux'], {
      'enabled': false,
      'concurrency': 8,
      'xudpConcurrency': -1,
      'xudpProxyUDP443': 'skip',
    });
  });

  test('Mux limits match Xray core bounds', () {
    expect(
      () => const XrayMuxSettings(concurrency: 129).validate(),
      throwsFormatException,
    );
    expect(
      () => const XrayMuxSettings(xudpConcurrency: 1025).validate(),
      throwsFormatException,
    );
  });
}
