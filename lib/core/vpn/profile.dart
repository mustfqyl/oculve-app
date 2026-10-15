import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'server_address_resolver.dart';

class VpnProfile {
  const VpnProfile({
    required this.id,
    required this.name,
    required this.flag,
    required this.config,
    this.serverAddressResolution,
  });
  final String id;
  final String name;
  final String? flag;
  final String config;
  final ServerAddressResolutionSettings? serverAddressResolution;
  Map<String, dynamic>? get proxyOutbound {
    try {
      final decoded = jsonDecode(config);
      if (decoded is! Map || decoded['outbounds'] is! List) return null;
      final outbounds = (decoded['outbounds'] as List).whereType<Map>();
      return Map<String, dynamic>.from(
        outbounds.firstWhere(
          (item) => item['tag'] == 'proxy',
          orElse: () => outbounds.firstWhere(
            (item) => supportedProxyProtocols.contains(item['protocol']),
          ),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  String? get transportNetwork =>
      (proxyOutbound?['streamSettings'] as Map?)?['network']?.toString();
  String? get transportSecurity =>
      (proxyOutbound?['streamSettings'] as Map?)?['security']?.toString();
  bool get supportsTlsFingerprint =>
      const {'tls', 'reality'}.contains(transportSecurity?.toLowerCase());
  bool get supportsTlsHelloFragmentation =>
      proxyOutbound?['protocol'] == 'vless' &&
      transportNetwork?.toLowerCase() == 'tcp' &&
      transportSecurity?.toLowerCase() == 'reality';

  String? get proxyProtocol {
    try {
      final decoded = jsonDecode(config);
      if (decoded is! Map || decoded['outbounds'] is! List) return null;
      final outbounds = (decoded['outbounds'] as List).whereType<Map>().map(
        (item) => Map<String, dynamic>.from(item),
      );
      return outbounds
          .firstWhere(
            (item) => supportedProxyProtocols.contains(item['protocol']),
          )['protocol']
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Xray outbounds that can represent a remote proxy/server in this client.
  /// Direct, block, DNS, and loopback outbounds remain routing primitives and
  /// must not be presented as selectable server locations.
  static const supportedProxyProtocols = {
    'vless',
    'vmess',
    'trojan',
    'shadowsocks',
    'socks',
    'http',
    'hysteria',
    'wireguard',
  };

  static final _coreVersionPattern = RegExp(r'^\d+\.\d+\.\d+$');

  static List<VpnProfile> parseSubscription(
    String body, {
    Map<String, String> responseHeaders = const {},
  }) {
    final serverAddressResolution =
        ServerAddressResolutionSettings.fromSubscription(
          body: body,
          headers: responseHeaders,
        );
    final profiles = <VpnProfile>[];
    final profileIds = <String>{};
    void addConfig(Map<String, dynamic> json, {String? name}) {
      final rawOutbounds = json['outbounds'];
      if (rawOutbounds is! List) return;
      final versionGuard = _parseVersionGuard(json['version']);
      final outbounds = rawOutbounds
          .whereType<Map>()
          .map((outbound) => Map<String, dynamic>.from(outbound))
          .toList();
      final candidates = outbounds.where(
        (outbound) => supportedProxyProtocols.contains(outbound['protocol']),
      );
      if (candidates.isEmpty) return;
      final outbound = candidates.first;
      // Keep only the selected node. Subscription routing/listeners never own
      // local ports, bypass rules, management APIs, or DNS policy.
      final config = jsonEncode({
        'log': {'loglevel': 'warning'},
        'version': ?versionGuard,
        'inbounds': [
          {
            'tag': 'socks',
            'listen': '127.0.0.1',
            'port': 10808,
            'protocol': 'socks',
            'settings': {'auth': 'noauth', 'udp': true},
            'sniffing': {
              'enabled': true,
              'destOverride': ['http', 'tls', 'quic'],
              'routeOnly': true,
            },
          },
        ],
        'outbounds': [
          {...outbound, 'tag': 'proxy'},
        ],
      });
      final id = sha256.convert(utf8.encode(config)).toString();
      if (!profileIds.add(id)) return;
      profiles.add(
        VpnProfile(
          id: id,
          name: _locationName(name),
          flag: _locationFlag(name),
          config: config,
          serverAddressResolution: serverAddressResolution,
        ),
      );
    }

    // Oculve's Happ rule returns an Xray JSON document or an array of
    // documents, while generic VLESS subscriptions return URI lines.
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {}
    if (decoded != null) {
      final documents = decoded is List ? decoded : [decoded];
      for (final document in documents) {
        if (document is! Map) continue;
        final json = Map<String, dynamic>.from(document);
        addConfig(json, name: json['remarks']?.toString());
      }
    } else {
      for (final item in FlutterVless.parseMany(body)) {
        final json =
            jsonDecode(item.getFullConfiguration()) as Map<String, dynamic>;
        addConfig(json, name: item.remark);
      }
    }
    if (profiles.isEmpty) {
      throw const FormatException('No compatible servers are available.');
    }
    return profiles;
  }

  static Map<String, String>? _parseVersionGuard(Object? input) {
    if (input == null) return null;
    if (input is! Map) {
      throw const FormatException('Xray version guard must be an object.');
    }
    final guard = Map<String, dynamic>.from(input);
    if (guard.keys.any((key) => key != 'min' && key != 'max')) {
      throw const FormatException(
        'Xray version guard supports only min and max.',
      );
    }
    final normalized = <String, String>{};
    for (final key in const ['min', 'max']) {
      final value = guard[key];
      if (value == null) continue;
      if (value is! String) {
        throw FormatException('Xray version $key must use x.y.z syntax.');
      }
      final version = value.trim();
      if (version.isEmpty) continue;
      if (!_coreVersionPattern.hasMatch(version)) {
        throw FormatException('Xray version $key must use x.y.z syntax.');
      }
      normalized[key] = version;
    }
    final minimum = normalized['min'];
    final maximum = normalized['max'];
    if (minimum != null &&
        maximum != null &&
        _compareCoreVersions(minimum, maximum) > 0) {
      throw const FormatException(
        'Xray version minimum cannot exceed its maximum.',
      );
    }
    return normalized.isEmpty ? null : normalized;
  }

  static int _compareCoreVersions(String first, String second) {
    final firstParts = first.split('.').map(int.parse).toList();
    final secondParts = second.split('.').map(int.parse).toList();
    for (var index = 0; index < 3; index++) {
      final order = firstParts[index].compareTo(secondParts[index]);
      if (order != 0) return order;
    }
    return 0;
  }

  static final _flagPrefix = RegExp(
    r'^[\u{1F1E6}-\u{1F1FF}]{2}\s*',
    unicode: true,
  );

  static String? _locationFlag(String? value) {
    if (value == null) return null;
    return _flagPrefix.firstMatch(value)?.group(0)?.trim();
  }

  static String _locationName(String? value) {
    final withoutFlag = (value ?? '').replaceFirst(_flagPrefix, '').trim();
    return withoutFlag.isEmpty ? 'VPN server' : withoutFlag;
  }
}
