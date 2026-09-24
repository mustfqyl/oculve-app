import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/core/vpn/server_address_resolver.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';

final serverLatencyProbeProvider = Provider<ServerLatencyProbe>(
  (ref) => ServerLatencyProbe(
    onDiagnostic: (diagnostic) {
      final diagnostics = ref.read(serverLatencyDiagnosticsProvider.notifier);
      diagnostics.state = [diagnostic, ...diagnostics.state].take(40).toList();
    },
  ),
);

/// Recent TCP probe details stay on-device and contain no subscription URL or
/// authentication material. They make DNS/endpoint mismatches diagnosable.
final serverLatencyDiagnosticsProvider = StateProvider<List<String>>(
  (ref) => const [],
);

/// Remembers the last settled ping order so a refresh never sends rows back to
/// the subscription order while new measurements are still arriving.
final serverLatencyDisplayOrderProvider = StateProvider<List<String>>(
  (ref) => const [],
);

/// Keeps the last successful direct RTT available while a probe is refreshing
/// or temporarily cannot use the physical network (for example, during a
/// tunnel shutdown after a connection error).
final serverLatencyLastKnownProvider = StateProvider<Map<String, int>>(
  (ref) => const {},
);

final serverLatencyProvider = FutureProvider.autoDispose.family<int?, String>((
  ref,
  id,
) async {
  final lastKnown = ref.read(serverLatencyLastKnownProvider)[id];
  // A direct TCP probe must leave over the device's normal network path. If the
  // VPN is up, an ordinary app socket may be routed back into the tunnel.
  final state = ref.watch(vpnProvider);
  if (ref.watch(vpnTunnelMayBeActiveProvider) ||
      state == VpnState.connected ||
      state == VpnState.connecting ||
      state == VpnState.disconnecting) {
    return lastKnown;
  }
  final profiles =
      ref.watch(sessionProvider).valueOrNull?.profiles ?? const <VpnProfile>[];
  for (final profile in profiles) {
    if (profile.id == id) {
      final measured = await ref
          .read(serverLatencyProbeProvider)
          .measure(profile);
      if (measured != null && measured > 0) {
        final cache = ref.read(serverLatencyLastKnownProvider.notifier);
        cache.state = {...cache.state, id: measured};
        return measured;
      }
      return lastKnown;
    }
  }
  return lastKnown;
});

List<VpnProfile> sortProfilesByLatency(
  List<VpnProfile> profiles,
  Map<String, int?> latencies,
) {
  final indexed = profiles.asMap().entries.toList();
  indexed.sort((a, b) {
    final first = latencies[a.value.id];
    final second = latencies[b.value.id];
    if (first == null && second == null) return a.key.compareTo(b.key);
    if (first == null) return 1;
    if (second == null) return -1;
    final order = first.compareTo(second);
    return order == 0 ? a.key.compareTo(b.key) : order;
  });
  return indexed.map((entry) => entry.value).toList();
}

List<VpnProfile> sortProfilesAlphabetically(List<VpnProfile> profiles) {
  final sorted = profiles.toList();
  sorted.sort((a, b) {
    final order = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return sorted;
}

/// Measures the node's TCP connection time. Reality/HTTPS checks are available
/// separately for connection diagnostics; they must not add traffic or gate the
/// node latency shown in the location list.
class ServerLatencyProbe {
  ServerLatencyProbe({
    this.xrayExecutable,
    this.realityVerifier,
    this.tcpRttSampler,
    this.tcpHostRttSampler,
    this.androidNativeRttSampler,
    this.androidNativeProbeSampler,
    this.appleNativeProbeSampler,
    this.hostResolver,
    this.dohServerAddressResolver,
    this.onDiagnostic,
    bool? useAndroidNativePing,
    bool? useAppleNativePing,
  }) : useAndroidNativePing = useAndroidNativePing ?? Platform.isAndroid,
       useAppleNativePing =
           useAppleNativePing ?? (Platform.isIOS || Platform.isMacOS);

  /// An explicit runtime is useful for integration tests and packaged builds.
  final String? xrayExecutable;
  final Future<bool> Function(String config)? realityVerifier;
  final Future<int?> Function(InternetAddress address, int port)? tcpRttSampler;
  final Future<int?> Function(String host, int port)? tcpHostRttSampler;
  final Future<int?> Function(String host, int port)? androidNativeRttSampler;
  final Future<TcpPingSample?> Function(String host, int port)?
  androidNativeProbeSampler;
  final Future<TcpPingSample?> Function(String host, int port)?
  appleNativeProbeSampler;
  final bool useAndroidNativePing;
  final bool useAppleNativePing;
  final Future<List<InternetAddress>> Function(String host)? hostResolver;
  final DohServerAddressResolver? dohServerAddressResolver;
  final void Function(String diagnostic)? onDiagnostic;
  static const probeUrl = 'https://www.cloudflare.com/cdn-cgi/trace';
  static const _tcpSampleCount = 5;
  static const _maxConcurrent = 3;
  final Queue<Completer<void>> _waiting = Queue();
  int _active = 0;

  Future<int?> measure(VpnProfile profile) async {
    if (_active >= _maxConcurrent) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    } else {
      _active++;
    }
    try {
      return await measureTcpRtt(profile);
    } catch (_) {
      return null;
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _active--;
      }
    }
  }

  /// Performs a separate real Reality-to-HTTPS check for diagnostics and
  /// integration tests. It is intentionally not part of [measure], so a remote
  /// website's DNS/TLS/response time cannot load or affect the ping display.
  Future<bool> verifyReality(VpnProfile profile) async {
    try {
      final fingerprint = await XrayPreferences.fingerprint();
      final dnsSettings = await XrayPreferences.userDnsSettings();
      final finalMaskSettings = profile.supportsTlsHelloFragmentation
          ? await XrayPreferences.userFinalMaskSettings()
          : const XrayFinalMaskSettings();
      final bypassDomains = await XrayPreferences.bypassDomains();
      final logLevel = await XrayPreferences.logLevel();
      final config = XrayPreferences.configure(
        profile.config,
        profile.supportsTlsFingerprint
            ? fingerprint
            : RealityFingerprint.serverDefault,
        dnsSettings: dnsSettings,
        bypassDomains: bypassDomains,
        logLevel: logLevel,
        finalMaskSettings: finalMaskSettings,
      );
      return await _verifyReality(config);
    } catch (_) {
      return false;
    }
  }

  /// Measures TCP connection establishment to the proxy node, excluding DNS
  /// resolution and any HTTPS/Reality destination latency.
  Future<int?> measureTcpRtt(VpnProfile profile) async {
    try {
      final config = jsonDecode(profile.config) as Map<String, dynamic>;
      final outbounds = config['outbounds'];
      if (outbounds is! List) return null;
      final outbound = outbounds
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(
            (item) =>
                VpnProfile.supportedProxyProtocols.contains(item['protocol']),
          )
          .firstOrNull;
      if (outbound == null) return null;

      final protocol = outbound['protocol'];
      // Hysteria and WireGuard carry the server connection over UDP. A TCP
      // connect to the same port would measure an unrelated service (or the
      // firewall timeout), so leave their TCP ping unavailable.
      if (protocol == 'hysteria' || protocol == 'wireguard') return null;
      final settings = outbound['settings'];
      final servers = settings is Map
          ? switch (protocol) {
              'vless' || 'vmess' => settings['vnext'],
              _ => settings['servers'],
            }
          : null;
      if (servers is! List || servers.isEmpty || servers.first is! Map) {
        return null;
      }
      final server = servers.first as Map;
      final host = server['address'];
      final rawPort = server['port'];
      final port = rawPort is int ? rawPort : int.tryParse('$rawPort');
      final stream = outbound['streamSettings'];
      final rawNetwork = stream is Map ? stream['network'] : null;
      final network = rawNetwork is String ? rawNetwork.toLowerCase() : 'tcp';
      if (host is! String ||
          host.isEmpty ||
          port == null ||
          port < 1 ||
          port > 65535 ||
          const {'kcp', 'mkcp', 'quic', 'hysteria'}.contains(network)) {
        return null;
      }

      // On Android, resolve on the physical network first, then time one direct
      // TCP connect through that network's socket factory. This matches native
      // proxy clients such as NekoBox and keeps DNS time out of the result. The
      // multi-resolver scan below remains for desktop platforms.
      if (useAndroidNativePing && tcpRttSampler == null) {
        final nativeSample = androidNativeProbeSampler;
        final TcpPingSample? sample;
        if (nativeSample != null) {
          sample = await nativeSample(host, port);
        } else {
          final sampler = androidNativeRttSampler;
          if (sampler == null) {
            sample = await _measureAndroidTcpConnect(host, port);
          } else {
            final latency = await sampler(host, port);
            sample = latency == null ? null : TcpPingSample(latencyMs: latency);
          }
        }
        final latency = sample?.latencyMs;
        final resolvedAddress = sample?.resolvedAddress;
        if (latency != null && latency > 0) {
          onDiagnostic?.call(
            '${DateTime.now().toIso8601String()} TCP ping $host:$port'
            ' | Android active network'
            '${resolvedAddress == null ? '' : ' | resolved: $resolvedAddress'}'
            ' | shown: ${latency}ms',
          );
          return latency;
        }
        return null;
      }

      final directAddress = InternetAddress.tryParse(host);
      final resolution = profile.serverAddressResolution;
      final resolverNames = <String>[];
      final addresses = <InternetAddress>[];
      if (directAddress != null) {
        resolverNames.add('literal address');
        addresses.add(directAddress);
      } else {
        // Happ's TCP test resolves the node through the device and connects
        // straight to the resulting endpoint. The subscription can also
        // supply its own DoH resolver for connection setup. CDN answers can
        // differ by resolver/region, so probe both answer sets and display the
        // fastest reachable edge instead of accidentally reporting a distant
        // DoH edge when the device's normal resolver reaches a nearby one.
        final lookups = <Future<_DnsLookupResult>>[
          _lookupSafely(
            'system DNS',
            () => hostResolver?.call(host) ?? InternetAddress.lookup(host),
          ),
        ];
        if (resolution != null) {
          lookups.add(
            _lookupSafely(
              'subscription DoH',
              () => (dohServerAddressResolver ?? DohServerAddressResolver())
                  .lookup(host, resolution),
            ),
          );
        }
        final results = await Future.wait(lookups);
        for (final result in results) {
          if (result.addresses.isEmpty) continue;
          resolverNames.add(result.resolver);
          addresses.addAll(result.addresses);
        }
      }
      // Run the timed socket handshakes outside Flutter's UI isolate. Frame
      // work can otherwise delay delivery of Socket.connect's completion and
      // inflate a local TCP RTT even though DNS was excluded from the timer.
      // Match the open-source NekoBox TCP test as well: dial the original
      // hostname with the platform's native resolver, then compare it with
      // every explicitly resolved address. This catches resolver/CDN edge
      // differences without allowing a slower answer to dominate the result.
      final uniqueAddresses = addresses.toSet().toList(growable: false);
      final addressStrings = uniqueAddresses
          .map((address) => address.address)
          .toList(growable: false);

      // Resolve first, then time only a TCP handshake to each numeric answer.
      // Passing a hostname to NWConnection includes its DNS lookup in the
      // elapsed time, unlike Happ/NekoBox's TCP ping. Pin each socket to the
      // physical interface so an already-running VPN cannot route it through
      // its utun tunnel.
      if (useAppleNativePing && tcpRttSampler == null) {
        final sampler = appleNativeProbeSampler ?? _measureAppleTcpConnect;
        var bestLatency = 0;
        String? bestAddress;
        String? bestRoute;
        for (final address in uniqueAddresses) {
          for (var index = 0; index < _tcpSampleCount; index++) {
            final sample = await sampler(address.address, port);
            final latency = sample?.latencyMs;
            if (latency != null &&
                latency > 0 &&
                (bestLatency == 0 || latency < bestLatency)) {
              bestLatency = latency;
              bestAddress = address.address;
              bestRoute = sample?.networkPath;
            }
          }
        }
        if (bestLatency == 0) return null;
        onDiagnostic?.call(
          '${DateTime.now().toIso8601String()} TCP ping $host:$port'
          ' | DNS: ${resolverNames.join(' + ')}'
          ' | resolved: ${bestAddress ?? addressStrings.first}'
          ' | Apple physical interface'
          '${bestRoute == null ? '' : ' | route: $bestRoute'}'
          ' | shown: ${bestLatency}ms',
        );
        return bestLatency;
      }

      late final List<List<int?>> sampleSets;
      late final List<int?> hostSamples;
      if (tcpRttSampler == null) {
        (sampleSets, hostSamples) = await Isolate.run(
          () => _measureTcpProbeBatch(
            host,
            directAddress == null,
            addressStrings,
            port,
            _tcpSampleCount,
          ),
        );
      } else {
        sampleSets = await Future.wait(
          uniqueAddresses.map((address) async {
            final samples = <int?>[];
            for (var i = 0; i < _tcpSampleCount; i++) {
              samples.add(await tcpRttSampler!(address, port));
            }
            return samples;
          }),
        );
        final hostSampler = tcpHostRttSampler;
        hostSamples = directAddress != null || hostSampler == null
            ? const []
            : await Future.wait(
                List.generate(_tcpSampleCount, (_) => hostSampler(host, port)),
              );
      }
      final results = [
        for (var index = 0; index < uniqueAddresses.length; index++)
          _AddressProbeResult(
            address: uniqueAddresses[index],
            samples: sampleSets[index],
            fastestMs: (sampleSets[index].whereType<int>().toList()..sort())
                .firstOrNull,
          ),
      ];
      final successful = results
          .map((result) => result.fastestMs)
          .whereType<int>()
          .toList();
      final fastestHostSample =
          (hostSamples.whereType<int>().toList()..sort()).firstOrNull;
      if (fastestHostSample != null) successful.add(fastestHostSample);
      if (successful.isEmpty) return null;
      successful.sort();
      final best = successful.first;
      _recordDiagnostic(
        host: host,
        port: port,
        resolver: resolverNames.join(' + '),
        results: results,
        hostSamples: hostSamples,
        displayedMs: best,
      );
      return best;
    } catch (_) {
      return null;
    }
  }

  Future<_DnsLookupResult> _lookupSafely(
    String resolver,
    Future<List<InternetAddress>> Function() lookup,
  ) async {
    try {
      return _DnsLookupResult(
        resolver,
        await lookup().timeout(const Duration(seconds: 5)),
      );
    } catch (_) {
      return _DnsLookupResult(resolver, const []);
    }
  }

  void _recordDiagnostic({
    required String host,
    required int port,
    required String resolver,
    required List<_AddressProbeResult> results,
    required List<int?> hostSamples,
    required int displayedMs,
  }) {
    final addresses = results
        .map((result) {
          final samples = result.samples
              .map((sample) => sample == null ? 'timeout' : '${sample}ms')
              .join(', ');
          final fastest = result.fastestMs;
          return '${result.address.address}: [$samples]'
              '${fastest == null ? '' : ' → ${fastest}ms'}';
        })
        .join(' | ');
    final hostSampleLog = hostSamples.isEmpty
        ? ''
        : ' | native host dial: [${hostSamples.map((sample) => sample == null ? 'timeout' : '${sample}ms').join(', ')}]';
    onDiagnostic?.call(
      '${DateTime.now().toIso8601String()} TCP ping $host:$port'
      ' | DNS: $resolver | resolved: $addresses'
      '$hostSampleLog'
      ' | shown: ${displayedMs}ms',
    );
  }

  Future<bool> _verifyReality(String config) async {
    try {
      final verifier = realityVerifier;
      if (verifier != null) return await verifier(config);
      if (xrayExecutable != null || Platform.isWindows || Platform.isLinux) {
        return await _verifyWithXrayProcess(config);
      }
      final delay = await VlessPlatform.instance.getServerDelay(
        config: config,
        url: probeUrl,
      );
      return delay > 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _verifyWithXrayProcess(String config) async {
    final executable =
        xrayExecutable ??
        (Platform.isWindows
            ? '${File(Platform.resolvedExecutable).parent.path}\\xray\\xray.exe'
            : '/usr/lib/oculve/xray');
    if (!await File(executable).exists()) return false;
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();
    final credentials = _randomCredentials();
    final document = jsonDecode(config) as Map<String, dynamic>;
    document['inbounds'] = [
      {
        'tag': 'socks',
        'listen': '127.0.0.1',
        'port': port,
        'protocol': 'http',
        'settings': {
          'accounts': [
            {'user': credentials.$1, 'pass': credentials.$2},
          ],
        },
      },
    ];
    final process = await Process.start(executable, [
      'run',
      '-config',
      'stdin:',
    ]);
    final stdout = process.stdout.drain<void>();
    final stderr = process.stderr.drain<void>();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..findProxy = (_) => 'PROXY 127.0.0.1:$port';
    client.authenticateProxy = (host, proxyPort, scheme, realm) async {
      client.addProxyCredentials(
        host,
        proxyPort,
        realm ?? '',
        HttpClientBasicCredentials(credentials.$1, credentials.$2),
      );
      return true;
    };
    try {
      process.stdin.write(jsonEncode(document));
      await process.stdin.close();
      for (var attempt = 0; attempt < 20; attempt++) {
        if (await _listening(port)) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final request = await client
          .getUrl(Uri.parse(probeUrl))
          .timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
      process.kill();
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      await stdout;
      await stderr;
    }
  }

  Future<bool> _listening(int port) async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 100),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  (String, String) _randomCredentials() {
    final random = Random.secure();
    String value() => List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return (value(), value());
  }
}

const _androidLatencyChannel = MethodChannel('com.oculve/server_latency');
const _appleLatencyChannel = MethodChannel('com.oculve/server_latency');

class TcpPingSample {
  const TcpPingSample({
    required this.latencyMs,
    this.resolvedAddress,
    this.networkPath,
  });

  final int latencyMs;
  final String? resolvedAddress;
  final String? networkPath;
}

Future<TcpPingSample?> _measureAndroidTcpConnect(String host, int port) async {
  final response = await _androidLatencyChannel.invokeMethod<Object?>(
    'tcpConnectLatency',
    {'host': host, 'port': port, 'timeoutMs': 3000},
  );
  // Accept the earlier integer response during an app upgrade where Flutter
  // and the native Android activity can briefly be on different versions.
  if (response is int) return TcpPingSample(latencyMs: response);
  if (response is! Map) return null;
  final latency = response['latencyMs'];
  if (latency is! int || latency <= 0) return null;
  final rawAddress = response['resolvedAddress'];
  final address = rawAddress is String && rawAddress.isNotEmpty
      ? rawAddress
      : null;
  return TcpPingSample(latencyMs: latency, resolvedAddress: address);
}

Future<TcpPingSample?> _measureAppleTcpConnect(String host, int port) async {
  final response = await _appleLatencyChannel.invokeMethod<Object?>(
    'tcpConnectLatency',
    {'host': host, 'port': port, 'timeoutMs': 3000},
  );
  if (response is! Map) return null;
  final latency = response['latencyMs'];
  if (latency is! int || latency <= 0) return null;
  final route = response['networkPath'];
  return TcpPingSample(
    latencyMs: latency,
    networkPath: route is String && route.isNotEmpty ? route : null,
  );
}

Future<(List<List<int?>>, List<int?>)> _measureTcpProbeBatch(
  String host,
  bool includeNativeHostDial,
  List<String> addresses,
  int port,
  int sampleCount,
) async {
  final results = await Future.wait<Object>([
    _measureTcpAddressBatch(addresses, port, sampleCount),
    if (includeNativeHostDial)
      _measureTcpHostBatch(host, port, sampleCount)
    else
      Future<List<int?>>.value(const []),
  ]);
  return (results[0] as List<List<int?>>, results[1] as List<int?>);
}

Future<List<List<int?>>> _measureTcpAddressBatch(
  List<String> addresses,
  int port,
  int sampleCount,
) async {
  return Future.wait(
    addresses.map((rawAddress) async {
      final address = InternetAddress.tryParse(rawAddress);
      if (address == null) return List<int?>.filled(sampleCount, null);
      final samples = <int?>[];
      for (var index = 0; index < sampleCount; index++) {
        samples.add(await _measureTcpSocket(address, port));
      }
      return samples;
    }),
  );
}

Future<List<int?>> _measureTcpHostBatch(
  String host,
  int port,
  int sampleCount,
) async {
  return _sampleTcpHost(host, port, sampleCount);
}

Future<List<int?>> _sampleTcpHost(
  String host,
  int port,
  int sampleCount,
) async {
  final samples = <int?>[];
  for (var index = 0; index < sampleCount; index++) {
    samples.add(await _measureTcpSocket(host, port));
  }
  return samples;
}

Future<int?> _measureTcpSocket(Object address, int port) async {
  final stopwatch = Stopwatch()..start();
  try {
    final socket = await Socket.connect(
      address,
      port,
      timeout: const Duration(seconds: 2),
    );
    stopwatch.stop();
    socket.destroy();
    return max(1, stopwatch.elapsedMilliseconds);
  } catch (_) {
    return null;
  }
}

class _AddressProbeResult {
  const _AddressProbeResult({
    required this.address,
    required this.samples,
    required this.fastestMs,
  });

  final InternetAddress address;
  final List<int?> samples;
  final int? fastestMs;
}

class _DnsLookupResult {
  const _DnsLookupResult(this.resolver, this.addresses);

  final String resolver;
  final List<InternetAddress> addresses;
}
