import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'profile_test.dart' show testLink;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final binary = Platform.environment['XRAY_TEST_BINARY'];
  test(
    'real Xray Reality TCP + Vision handshake forwards HTTPS traffic',
    () async {
      final dir = await Directory.systemTemp.createTemp('oculve-reality-');
      Process? server;
      Process? client;
      Future<int> port() async {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final value = socket.port;
        await socket.close();
        return value;
      }

      Future<File> write(String name, Map<String, dynamic> data) async {
        final file = File('${dir.path}/$name');
        await file.writeAsString(jsonEncode(data));
        await Process.run('chmod', ['600', file.path]);
        return file;
      }

      try {
        final keys = await Process.run(binary!, ['x25519']);
        expect(keys.exitCode, 0);
        final values = <String, String>{};
        for (final line in keys.stdout.toString().split('\n')) {
          final index = line.indexOf(':');
          if (index > 0) {
            values[line.substring(0, index).trim()] = line
                .substring(index + 1)
                .trim();
          }
        }
        final privateKey = values['PrivateKey'] ?? values['Private key'];
        final publicKey =
            values['Password (PublicKey)'] ??
            values['Password'] ??
            values['Public key'] ??
            values['PublicKey'];
        expect(privateKey, isNotNull);
        expect(publicKey, isNotNull);
        final serverPort = await port();
        final socksPort = await port();
        const id = '11111111-1111-4111-8111-111111111111';
        final serverConfig = await write('server.json', {
          'log': {'loglevel': 'none'},
          'inbounds': [
            {
              'listen': '127.0.0.1',
              'port': serverPort,
              'protocol': 'vless',
              'settings': {
                'clients': [
                  {'id': id, 'flow': 'xtls-rprx-vision'},
                ],
                'decryption': 'none',
              },
              'streamSettings': {
                'network': 'tcp',
                'security': 'reality',
                'realitySettings': {
                  'target': 'www.cloudflare.com:443',
                  'serverNames': ['www.cloudflare.com'],
                  'privateKey': privateKey,
                  'shortIds': ['0123456789abcdef'],
                },
              },
            },
          ],
          'outbounds': [
            {'protocol': 'freedom'},
          ],
        });
        final profile = VpnProfile.parseSubscription(
          'vless://$id@127.0.0.1:$serverPort?security=reality&sni=www.cloudflare.com&fp=chrome&pbk=$publicKey&sid=0123456789abcdef&type=tcp&flow=xtls-rprx-vision#Local%20test',
        ).single;
        // Exercise the setting that the app applies immediately before start.
        final serverCheck = await Process.run(binary, [
          'run',
          '-test',
          '-config',
          serverConfig.path,
        ]);
        expect(
          serverCheck.exitCode,
          0,
          reason: 'Xray must accept the Reality fixture configuration',
        );
        for (final level in XrayLogLevel.values) {
          final configured =
              jsonDecode(
                    XrayPreferences.configure(
                      profile.config,
                      RealityFingerprint.serverDefault,
                      logLevel: level,
                    ),
                  )
                  as Map<String, dynamic>;
          configured['inbounds'][0]['port'] = socksPort;
          final logConfig = await write('log-${level.name}.json', configured);
          final check = await Process.run(binary, [
            'run',
            '-test',
            '-config',
            logConfig.path,
          ]);
          expect(
            check.exitCode,
            0,
            reason: 'Xray must accept the ${level.name} log level',
          );
        }
        server = await Process.start(binary, [
          'run',
          '-config',
          serverConfig.path,
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 700));
        final previousOverrides = HttpOverrides.current;
        HttpOverrides.global = null;
        int? measured;
        var realityHealthy = false;
        try {
          final probe = ServerLatencyProbe(
            xrayExecutable: binary,
            useAppleNativePing: false,
          );
          measured = await probe.measure(profile);
          for (var attempt = 0; attempt < 3 && !realityHealthy; attempt++) {
            realityHealthy = await probe.verifyReality(profile);
          }
        } finally {
          HttpOverrides.global = previousOverrides;
        }
        expect(
          realityHealthy,
          isTrue,
          reason: 'Reality must carry an HTTPS health request',
        );
        expect(measured, isNotNull);
        expect(measured, greaterThan(0));
        server.stdout.drain<void>();
        server.stderr.drain<void>();
        const fingerprints = [
          RealityFingerprint.chrome,
          RealityFingerprint.firefox,
          RealityFingerprint.safari,
        ];
        final incompatibleFingerprints = <String>[];
        for (final fingerprint in fingerprints) {
          final config =
              jsonDecode(
                    XrayPreferences.configure(
                      profile.config,
                      fingerprint,
                      dnsServer: fingerprint == RealityFingerprint.chrome
                          ? '9.9.9.9'
                          : null,
                      muxSettings: const XrayMuxSettings(),
                    ),
                  )
                  as Map<String, dynamic>;
          config['inbounds'][0]['port'] = socksPort;
          final clientConfig = await write(
            'client-${fingerprint.name}.json',
            config,
          );
          final check = await Process.run(binary, [
            'run',
            '-test',
            '-config',
            clientConfig.path,
          ]);
          expect(
            check.exitCode,
            0,
            reason: 'Xray must accept ${fingerprint.label} configuration',
          );
          final currentClient = await Process.start(binary, [
            'run',
            '-config',
            clientConfig.path,
          ]);
          client = currentClient;
          currentClient.stdout.drain<void>();
          currentClient.stderr.drain<void>();
          ProcessResult? result;
          try {
            await Future<void>.delayed(const Duration(milliseconds: 450));
            result = await Process.run('curl', [
              '--silent',
              '--show-error',
              '--fail',
              '--max-time',
              '8',
              '--socks5-hostname',
              '127.0.0.1:$socksPort',
              'https://example.com',
            ]);
          } finally {
            currentClient.kill();
            await currentClient.exitCode.timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                currentClient.kill(ProcessSignal.sigkill);
                return -1;
              },
            );
            client = null;
          }
          if (result.exitCode != 0 ||
              !result.stdout.toString().contains('Example Domain')) {
            incompatibleFingerprints.add(fingerprint.label);
          }
        }
        expect(
          incompatibleFingerprints,
          isEmpty,
          reason:
              'Only Reality fingerprints that carry live HTTPS may be offered; failed: ${incompatibleFingerprints.join(', ')}',
        );
      } finally {
        for (final process in [client, server]) {
          if (process != null) {
            process.kill();
            await process.exitCode.timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                process.kill(ProcessSignal.sigkill);
                return -1;
              },
            );
          }
        }
        await dir.delete(recursive: true);
      }
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to a real Xray executable.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'real Xray enforces advanced inbound, address, port and HTTP matchers',
    () async {
      final directServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final blockedServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final webhookServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final webhookEvents = <Map<String, dynamic>>[];
      var directRequests = 0;
      var blockedRequests = 0;
      final directSubscription = directServer.listen((request) {
        directRequests++;
        request.response
          ..statusCode = HttpStatus.ok
          ..write('direct-route-ok');
        request.response.close();
      });
      final blockedSubscription = blockedServer.listen((request) {
        blockedRequests++;
        request.response
          ..statusCode = HttpStatus.ok
          ..write('blocked-route-leaked');
        request.response.close();
      });
      final webhookSubscription = webhookServer.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          webhookEvents.add(Map<String, dynamic>.from(decoded));
        }
        request.response
          ..statusCode = HttpStatus.noContent
          ..close();
      });
      final profile = VpnProfile.parseSubscription(testLink).single;
      final source = jsonDecode(profile.config) as Map<String, dynamic>;
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final socksPort = reservation.port;
      await reservation.close();
      final sourcePortReservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final sourcePort = sourcePortReservation.port;
      await sourcePortReservation.close();
      final unmatchedSourcePort = sourcePort == 65535
          ? sourcePort - 1
          : sourcePort + 1;
      final config =
          jsonDecode(
                XrayPreferences.configure(
                  jsonEncode(source),
                  RealityFingerprint.serverDefault,
                  routingRules: [
                    XrayRoutingRule(
                      action: XrayRoutingAction.block,
                      ports: ['${blockedServer.port}'],
                    ),
                    XrayRoutingRule(
                      action: XrayRoutingAction.direct,
                      ips: const ['127.0.0.1'],
                      ports: ['${directServer.port}'],
                      sourcePorts: ['$sourcePort'],
                      localPorts: ['$socksPort'],
                      sourceIps: const ['127.0.0.1'],
                      localIps: const ['127.0.0.1'],
                      inboundTags: const ['socks'],
                      networks: const ['tcp'],
                      protocols: const ['http'],
                      attributes: const {':method': 'GET', ':path': '/'},
                      ruleTag: 'direct-http-get',
                      webhook: XrayRoutingWebhook(
                        url:
                            'http://127.0.0.1:${webhookServer.port}/route-event',
                        deduplicationSeconds: 30,
                        headers: const {'X-Route-Token': 'integration-test'},
                      ),
                    ),
                  ],
                ),
              )
              as Map<String, dynamic>;
      config['inbounds'][0]['port'] = socksPort;
      config['outbounds'][0] = {'tag': 'proxy', 'protocol': 'blackhole'};
      final dir = await Directory.systemTemp.createTemp(
        'oculve-structured-routing-',
      );
      Process? core;
      try {
        final file = File('${dir.path}/client.json');
        await file.writeAsString(jsonEncode(config));
        final check = await Process.run(binary!, [
          'run',
          '-test',
          '-config',
          file.path,
        ]);
        expect(check.exitCode, 0, reason: '${check.stderr}\n${check.stdout}');
        core = await Process.start(binary, ['run', '-config', file.path]);
        core.stdout.drain<void>();
        core.stderr.drain<void>();
        await Future<void>.delayed(const Duration(milliseconds: 350));
        final direct = await Process.run('curl', [
          '--silent',
          '--show-error',
          '--max-time',
          '3',
          '--local-port',
          '$sourcePort',
          '--socks5-hostname',
          '127.0.0.1:$socksPort',
          'http://127.0.0.1:${directServer.port}/',
        ]);
        expect(direct.exitCode, 0, reason: direct.stderr.toString());
        expect(direct.stdout.toString(), 'direct-route-ok');
        for (
          var attempt = 0;
          attempt < 10 && webhookEvents.isEmpty;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(webhookEvents, hasLength(1));
        expect(webhookEvents.single['outboundTag'], 'direct');
        final unmatched = await Process.run('curl', [
          '--silent',
          '--show-error',
          '--max-time',
          '3',
          '--local-port',
          '$unmatchedSourcePort',
          '--socks5-hostname',
          '127.0.0.1:$socksPort',
          'http://127.0.0.1:${directServer.port}/',
        ]);
        expect(unmatched.exitCode, isNot(0));
        expect(webhookEvents, hasLength(1));
        final blocked = await Process.run('curl', [
          '--silent',
          '--show-error',
          '--max-time',
          '3',
          '--socks5-hostname',
          '127.0.0.1:$socksPort',
          'http://127.0.0.1:${blockedServer.port}/',
        ]);
        expect(blocked.exitCode, isNot(0));
        expect(directRequests, 1);
        expect(blockedRequests, 0);
      } finally {
        if (core != null) {
          core.kill();
          await core.exitCode.timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              core!.kill(ProcessSignal.sigkill);
              return -1;
            },
          );
        }
        await directSubscription.cancel();
        await blockedSubscription.cancel();
        await webhookSubscription.cancel();
        await directServer.close();
        await blockedServer.close();
        await webhookServer.close();
        await dir.delete(recursive: true);
      }
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to a real Xray executable.'
        : false,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'real Xray routes chosen site directly and keeps other sites on proxy',
    () async {
      final profile = VpnProfile.parseSubscription(testLink).single;
      final source = jsonDecode(profile.config) as Map<String, dynamic>;
      source['routing'] = {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [
          {
            'type': 'field',
            'domain': ['domain:cloudflare.com'],
            'outboundTag': 'proxy',
          },
        ],
      };
      (source['outbounds'] as List).add({
        'tag': 'direct',
        'protocol': 'blackhole',
      });
      final config =
          jsonDecode(
                XrayPreferences.configure(
                  jsonEncode(source),
                  RealityFingerprint.serverDefault,
                  bypassDomains: ['example.com'],
                ),
              )
              as Map<String, dynamic>;
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      config['inbounds'][0]['port'] = port;
      expect(config['routing']['domainStrategy'], 'IPIfNonMatch');
      expect(config['routing']['rules'], hasLength(2));
      expect(config['routing']['rules'][0]['outboundTag'], 'direct-2');
      expect(config['routing']['rules'][1]['outboundTag'], 'proxy');
      // A blackhole stands in for the server, so only the bypass can connect.
      config['outbounds'][0] = {'tag': 'proxy', 'protocol': 'blackhole'};
      final dir = await Directory.systemTemp.createTemp('oculve-routing-');
      Process? core;
      try {
        final file = File('${dir.path}/client.json');
        await file.writeAsString(jsonEncode(config));
        final check = await Process.run(binary!, [
          'run',
          '-test',
          '-config',
          file.path,
        ]);
        expect(check.exitCode, 0);
        core = await Process.start(binary, ['run', '-config', file.path]);
        core.stdout.drain<void>();
        core.stderr.drain<void>();
        ProcessResult? direct;
        for (var attempt = 0; attempt < 5; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          direct = await Process.run('curl', [
            '--silent',
            '--show-error',
            '--max-time',
            '12',
            '--socks5-hostname',
            '127.0.0.1:$port',
            'https://example.com',
          ]);
          if (direct.exitCode == 0) break;
        }
        expect(direct!.exitCode, 0);
        expect(direct.stdout.toString(), contains('Example Domain'));
        final proxy = await Process.run('curl', [
          '--silent',
          '--max-time',
          '5',
          '--socks5-hostname',
          '127.0.0.1:$port',
          'https://www.cloudflare.com',
        ]);
        expect(proxy.exitCode, isNot(0));
      } finally {
        if (core != null) {
          core.kill();
          await core.exitCode.timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              core!.kill(ProcessSignal.sigkill);
              return -1;
            },
          );
        }
        await dir.delete(recursive: true);
      }
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to a real Xray executable.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'real Xray carries concurrent VLESS TCP requests with Mux enabled',
    () async {
      Future<int> unusedPort() async {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final value = socket.port;
        await socket.close();
        return value;
      }

      final serverPort = await unusedPort();
      final socksPort = await unusedPort();
      final serverOutput = StringBuffer();
      final clientOutput = StringBuffer();
      final destination = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final destinationRequests = destination.listen((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('xray-mux-ok');
        await request.response.close();
      });
      const id = '11111111-1111-4111-8111-111111111111';
      final source = jsonEncode({
        'log': {'loglevel': 'debug'},
        'inbounds': [
          {
            'tag': 'socks',
            'listen': '127.0.0.1',
            'port': socksPort,
            'protocol': 'socks',
            'settings': {'auth': 'noauth', 'udp': true},
          },
        ],
        'outbounds': [
          {
            'tag': 'proxy',
            'protocol': 'vless',
            'settings': {
              'vnext': [
                {
                  'address': '127.0.0.1',
                  'port': serverPort,
                  'users': [
                    {'id': id, 'encryption': 'none'},
                  ],
                },
              ],
            },
            'streamSettings': {'network': 'raw', 'security': 'none'},
          },
        ],
      });
      final clientConfig = XrayPreferences.configure(
        source,
        RealityFingerprint.serverDefault,
        tcpSettings: const XrayTcpSettings(
          fastOpenMode: TcpFastOpenMode.enabled,
          keepAliveIdle: 60,
          keepAliveInterval: 15,
        ),
        muxSettings: const XrayMuxSettings(
          enabled: true,
          concurrency: 8,
          xudpConcurrency: 16,
        ),
      );
      final serverConfig = jsonEncode({
        'log': {'loglevel': 'debug'},
        'inbounds': [
          {
            'listen': '127.0.0.1',
            'port': serverPort,
            'protocol': 'vless',
            'settings': {
              'clients': [
                {'id': id},
              ],
              'decryption': 'none',
            },
            'streamSettings': {'network': 'raw', 'security': 'none'},
          },
        ],
        'outbounds': [
          {
            'tag': 'direct',
            'protocol': 'freedom',
            'settings': {
              'finalRules': [
                {
                  'action': 'allow',
                  'ip': ['127.0.0.0/8'],
                },
              ],
            },
          },
        ],
      });
      final directory = await Directory.systemTemp.createTemp(
        'oculve-xray-mux-',
      );

      Future<void> waitForPort(int port, String name) async {
        for (var attempt = 0; attempt < 40; attempt++) {
          try {
            final socket = await Socket.connect(
              InternetAddress.loopbackIPv4,
              port,
              timeout: const Duration(milliseconds: 100),
            );
            socket.destroy();
            return;
          } catch (_) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        }
        throw StateError('$name did not start listening.');
      }

      Process? server;
      Process? client;
      try {
        final serverFile = File('${directory.path}/server.json');
        final clientFile = File('${directory.path}/client.json');
        await serverFile.writeAsString(serverConfig);
        await clientFile.writeAsString(clientConfig);
        for (final file in [serverFile, clientFile]) {
          final check = await Process.run(binary!, [
            'run',
            '-test',
            '-config',
            file.path,
          ]);
          expect(check.exitCode, 0, reason: check.stderr.toString());
        }
        server = await Process.start(binary!, [
          'run',
          '-config',
          serverFile.path,
        ]);
        server.stdout.transform(utf8.decoder).listen(serverOutput.write);
        server.stderr.transform(utf8.decoder).listen(serverOutput.write);
        await waitForPort(serverPort, 'Xray test server');
        client = await Process.start(binary, [
          'run',
          '-config',
          clientFile.path,
        ]);
        client.stdout.transform(utf8.decoder).listen(clientOutput.write);
        client.stderr.transform(utf8.decoder).listen(clientOutput.write);
        await waitForPort(socksPort, 'Xray test client SOCKS');

        final results = await Future.wait(
          List.generate(
            4,
            (_) => Process.run('curl', [
              '--silent',
              '--show-error',
              '--fail',
              '--max-time',
              '10',
              '--socks5-hostname',
              '127.0.0.1:$socksPort',
              'http://127.0.0.1:${destination.port}/',
            ]),
          ),
        );
        for (final result in results) {
          expect(
            result.exitCode,
            0,
            reason:
                '${result.stderr}\nClient: ${clientOutput.toString()}\nServer: ${serverOutput.toString()}',
          );
          expect(result.stdout, 'xray-mux-ok');
        }
      } finally {
        for (final process in [client, server]) {
          if (process != null) {
            process.kill();
            await process.exitCode.timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                process.kill(ProcessSignal.sigkill);
                return -1;
              },
            );
          }
        }
        await destinationRequests.cancel();
        await destination.close(force: true);
        await directory.delete(recursive: true);
      }
    },
    skip: binary == null || !File(binary).existsSync()
        ? 'Set XRAY_TEST_BINARY to a real Xray executable.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
