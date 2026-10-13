import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_vless/flutter_vless.dart';

/// Linux uses Xray's native TUN inbound, supervised by a root-owned helper.
/// The UI remains unprivileged; polkit requests authorization for the helper.
class LinuxXrayPlatform extends VlessPlatform {
  Process? _process;
  void Function(VlessStatus)? _status;
  final Queue<String> _events = Queue<String>();

  void _record(String state) {
    _events.add('${DateTime.now().toUtc().toIso8601String()} $state');
    if (_events.length > 100) _events.removeFirst();
  }

  @override
  Future<void> initializeVless({
    required void Function(VlessStatus) onStatusChanged,
    required String notificationIconResourceType,
    required String notificationIconResourceName,
    required String providerBundleIdentifier,
    required String groupIdentifier,
    String? keychainAccessGroup,
  }) async {
    _status = onStatusChanged;
  }

  @override
  Future<bool> requestPermission() async =>
      File('/usr/lib/oculve/oculve-tunnel').existsSync();

  @override
  Future<String> getCoreVersion() async {
    const binary = '/usr/lib/oculve/xray';
    if (!await File(binary).exists()) return 'Unavailable';
    try {
      final result = await Process.run(binary, [
        'version',
      ]).timeout(const Duration(seconds: 3));
      if (result.exitCode != 0) return 'Unavailable';
      return RegExp(
            r'Xray\s+([0-9]+\.[0-9]+\.[0-9]+)',
          ).firstMatch(result.stdout.toString())?.group(1) ??
          'Unknown';
    } catch (_) {
      return 'Unavailable';
    }
  }

  @override
  Future<String> getProviderDebugSnapshot() async => _events.join('\n');
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
    if (_process != null) throw StateError('A tunnel is already running.');
    final request = _request(config, dpiBypass, dpiProfile, proxyOnly);
    final process = await Process.start('/usr/bin/pkexec', [
      '--action-id',
      'com.oculve.client.tunnel',
      '/usr/lib/oculve/oculve-tunnel',
    ]);
    _process = process;
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          try {
            final state = jsonDecode(line)['state'] as String;
            _record(state);
            _status?.call(VlessStatus(state: state));
          } catch (_) {}
        });
    process.stderr.drain<void>();
    process.stdin.writeln(jsonEncode(request));
    await process.stdin.flush();
    unawaited(
      process.exitCode.then((code) {
        if (_process == process) {
          _process = null;
          _record(code == 0 ? 'DISCONNECTED' : 'ERROR');
          _status?.call(
            VlessStatus(state: code == 0 ? 'DISCONNECTED' : 'ERROR'),
          );
        }
      }),
    );
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
    final process = _process;
    if (process == null) throw StateError('A protected tunnel is required.');
    final request = _request(config, dpiBypass, dpiProfile, proxyOnly);
    process.stdin.writeln(jsonEncode(request));
    await process.stdin.flush();
  }

  Map<String, Object?> _request(
    String config,
    bool dpiBypass,
    int dpiProfile,
    bool proxyOnly,
  ) {
    if (proxyOnly) throw UnsupportedError('Linux supports tunnel mode only.');
    final parsed = jsonDecode(config) as Map<String, dynamic>;
    final outbounds = (parsed['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final node = dpiBypass
        ? null
        : outbounds.firstWhere((n) => n['tag'] == 'proxy');
    if (dpiBypass &&
        !outbounds.any((outbound) => outbound['tag'] == 'byedpi')) {
      throw const FormatException('The built-in DPI config is invalid.');
    }
    final logSettings = parsed['log'] as Map<String, dynamic>?;
    final logLevel = logSettings?['loglevel'];
    if (logLevel is! String ||
        !const {
          'debug',
          'info',
          'warning',
          'error',
          'none',
        }.contains(logLevel)) {
      throw const FormatException('A supported Xray log level is required.');
    }
    final routing = parsed['routing'] as Map<String, dynamic>?;
    final routingRules = (routing?['rules'] as List? ?? const [])
        .whereType<Map>()
        .map((rule) => Map<String, dynamic>.from(rule))
        .toList();
    final dns = parsed['dns'] as Map<String, dynamic>?;
    final dnsServers = dns?['servers'] as List?;
    if (dnsServers == null ||
        dnsServers.length != 1 ||
        dnsServers.first is! String ||
        !((dnsServers.first as String).startsWith('tcp://') ||
            (dnsServers.first as String).startsWith('https://'))) {
      throw const FormatException('A supported VPN DNS resolver is required.');
    }
    final dnsServer = dnsServers.first as String;
    return {
      if (!dpiBypass) 'outbound': node!,
      'dpiBypass': dpiBypass,
      if (dpiBypass) 'dpiProfile': dpiProfile,
      'routingRules': routingRules,
      'bypassDomains': const <String>[],
      'dnsServer': dnsServer,
      'logLevel': logLevel,
      'version': parsed['version'],
    };
  }

  @override
  Future<void> stopVless() async {
    final process = _process;
    if (process == null) {
      if (File('/usr/lib/oculve/oculve-tunnel').existsSync()) {
        final result = await Process.run('/usr/bin/pkexec', [
          '--action-id',
          'com.oculve.client.tunnel',
          '/usr/lib/oculve/oculve-tunnel',
          '--disarm',
        ]);
        if (result.exitCode != 0) {
          throw StateError('Could not release Linux protection.');
        }
      }
      return;
    }
    process.stdin.writeln('stop');
    await process.stdin.close();
    final code = await process.exitCode.timeout(const Duration(seconds: 20));
    if (code != 0) throw StateError('Could not release Linux protection.');
    _process = null;
  }
}
