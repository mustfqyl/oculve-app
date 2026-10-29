part of 'xray_preferences.dart';

/// Empty [bufferSizeKb] preserves the platform-specific Xray default.
class XrayPolicySettings {
  const XrayPolicySettings({
    this.handshakeSeconds = 60,
    this.connectionIdleSeconds = 300,
    this.uplinkOnlySeconds = 1,
    this.downlinkOnlySeconds = 1,
    this.bufferSizeKb,
    this.statsUserUplink = false,
    this.statsUserDownlink = false,
    this.statsUserOnline = false,
    this.statsInboundUplink = true,
    this.statsInboundDownlink = true,
    this.statsOutboundUplink = true,
    this.statsOutboundDownlink = true,
  });

  final int handshakeSeconds;
  final int connectionIdleSeconds;
  final int uplinkOnlySeconds;
  final int downlinkOnlySeconds;
  final int? bufferSizeKb;
  final bool statsUserUplink;
  final bool statsUserDownlink;
  final bool statsUserOnline;
  final bool statsInboundUplink;
  final bool statsInboundDownlink;
  final bool statsOutboundUplink;
  final bool statsOutboundDownlink;

  XrayPolicySettings copyWith({
    int? handshakeSeconds,
    int? connectionIdleSeconds,
    int? uplinkOnlySeconds,
    int? downlinkOnlySeconds,
    int? bufferSizeKb,
    bool? statsUserUplink,
    bool? statsUserDownlink,
    bool? statsUserOnline,
    bool? statsInboundUplink,
    bool? statsInboundDownlink,
    bool? statsOutboundUplink,
    bool? statsOutboundDownlink,
    bool clearBufferSize = false,
  }) => XrayPolicySettings(
    handshakeSeconds: handshakeSeconds ?? this.handshakeSeconds,
    connectionIdleSeconds: connectionIdleSeconds ?? this.connectionIdleSeconds,
    uplinkOnlySeconds: uplinkOnlySeconds ?? this.uplinkOnlySeconds,
    downlinkOnlySeconds: downlinkOnlySeconds ?? this.downlinkOnlySeconds,
    bufferSizeKb: clearBufferSize ? null : bufferSizeKb ?? this.bufferSizeKb,
    statsUserUplink: statsUserUplink ?? this.statsUserUplink,
    statsUserDownlink: statsUserDownlink ?? this.statsUserDownlink,
    statsUserOnline: statsUserOnline ?? this.statsUserOnline,
    statsInboundUplink: statsInboundUplink ?? this.statsInboundUplink,
    statsInboundDownlink: statsInboundDownlink ?? this.statsInboundDownlink,
    statsOutboundUplink: statsOutboundUplink ?? this.statsOutboundUplink,
    statsOutboundDownlink: statsOutboundDownlink ?? this.statsOutboundDownlink,
  );

  Map<String, dynamic> toJson() => {
    'handshakeSeconds': handshakeSeconds,
    'connectionIdleSeconds': connectionIdleSeconds,
    'uplinkOnlySeconds': uplinkOnlySeconds,
    'downlinkOnlySeconds': downlinkOnlySeconds,
    if (bufferSizeKb != null) 'bufferSizeKb': bufferSizeKb,
    'statsUserUplink': statsUserUplink,
    'statsUserDownlink': statsUserDownlink,
    'statsUserOnline': statsUserOnline,
    'statsInboundUplink': statsInboundUplink,
    'statsInboundDownlink': statsInboundDownlink,
    'statsOutboundUplink': statsOutboundUplink,
    'statsOutboundDownlink': statsOutboundDownlink,
  };

  factory XrayPolicySettings.fromJson(Map<String, dynamic> json) =>
      XrayPolicySettings(
        handshakeSeconds: json['handshakeSeconds'] is int
            ? json['handshakeSeconds'] as int
            : 60,
        connectionIdleSeconds: json['connectionIdleSeconds'] is int
            ? json['connectionIdleSeconds'] as int
            : 300,
        uplinkOnlySeconds: json['uplinkOnlySeconds'] is int
            ? json['uplinkOnlySeconds'] as int
            : 1,
        downlinkOnlySeconds: json['downlinkOnlySeconds'] is int
            ? json['downlinkOnlySeconds'] as int
            : 1,
        bufferSizeKb: json['bufferSizeKb'] is int
            ? json['bufferSizeKb'] as int
            : null,
        statsUserUplink: json['statsUserUplink'] is bool
            ? json['statsUserUplink'] as bool
            : false,
        statsUserDownlink: json['statsUserDownlink'] is bool
            ? json['statsUserDownlink'] as bool
            : false,
        statsUserOnline: json['statsUserOnline'] is bool
            ? json['statsUserOnline'] as bool
            : false,
        statsInboundUplink: json['statsInboundUplink'] is bool
            ? json['statsInboundUplink'] as bool
            : true,
        statsInboundDownlink: json['statsInboundDownlink'] is bool
            ? json['statsInboundDownlink'] as bool
            : true,
        statsOutboundUplink: json['statsOutboundUplink'] is bool
            ? json['statsOutboundUplink'] as bool
            : true,
        statsOutboundDownlink: json['statsOutboundDownlink'] is bool
            ? json['statsOutboundDownlink'] as bool
            : true,
      );

  Map<String, dynamic> toXrayJson() => {
    'handshake': handshakeSeconds,
    'connIdle': connectionIdleSeconds,
    'uplinkOnly': uplinkOnlySeconds,
    'downlinkOnly': downlinkOnlySeconds,
    if (bufferSizeKb != null) 'bufferSize': bufferSizeKb,
    'statsUserUplink': statsUserUplink,
    'statsUserDownlink': statsUserDownlink,
    'statsUserOnline': statsUserOnline,
  };

  Map<String, dynamic> toSystemXrayJson() => {
    'statsInboundUplink': statsInboundUplink,
    'statsInboundDownlink': statsInboundDownlink,
    'statsOutboundUplink': statsOutboundUplink,
    'statsOutboundDownlink': statsOutboundDownlink,
  };

  void validate() {
    final values = [
      handshakeSeconds,
      connectionIdleSeconds,
      uplinkOnlySeconds,
      downlinkOnlySeconds,
      ?bufferSizeKb,
    ];
    if (values.any((value) => value < 0)) {
      throw const FormatException(
        'Xray policy values must be non-negative whole numbers.',
      );
    }
  }
}

enum XrayRoutingAction { proxy, direct, block }

class XrayRoutingWebhook {
  const XrayRoutingWebhook({
    required this.url,
    this.deduplicationSeconds = 300,
    this.headers = const {},
  });

  final String url;
  final int deduplicationSeconds;
  final Map<String, String> headers;

  Map<String, dynamic> toJson() => {
    'url': url,
    'deduplicationSeconds': deduplicationSeconds,
    'headers': headers,
  };

  Map<String, dynamic> toXrayJson() => {
    'url': url.trim(),
    'deduplication': deduplicationSeconds,
    if (headers.isNotEmpty) 'headers': headers,
  };

  factory XrayRoutingWebhook.fromJson(Map<String, dynamic> json) =>
      XrayRoutingWebhook(
        url: json['url']?.toString() ?? '',
        deduplicationSeconds: json['deduplicationSeconds'] is int
            ? json['deduplicationSeconds'] as int
            : int.tryParse('${json['deduplicationSeconds']}') ?? 300,
        headers: json['headers'] is Map
            ? (json['headers'] as Map).map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              )
            : const {},
      );

  static XrayRoutingWebhook fromEditor({
    required String url,
    required String deduplicationSeconds,
    required String headersJson,
  }) {
    final decodedHeaders = jsonDecode(headersJson);
    if (decodedHeaders is! Map ||
        decodedHeaders.keys.any((key) => key is! String) ||
        decodedHeaders.values.any((value) => value is! String)) {
      throw const FormatException(
        'Webhook headers must be a JSON object of string values.',
      );
    }
    final deduplication = int.tryParse(deduplicationSeconds.trim());
    if (deduplication == null) {
      throw const FormatException(
        'Enter webhook duplicate suppression in whole seconds.',
      );
    }
    final webhook = XrayRoutingWebhook(
      url: url.trim(),
      deduplicationSeconds: deduplication,
      headers: Map<String, String>.from(decodedHeaders),
    );
    webhook.validate();
    return webhook;
  }

  void validate() {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException(
        'Webhook must use an HTTP or HTTPS URL without embedded credentials.',
      );
    }
    if (deduplicationSeconds < 0 || deduplicationSeconds > 86400) {
      throw const FormatException(
        'Webhook duplicate suppression must be between 0 and 86400 seconds.',
      );
    }
    if (headers.length > 16) {
      throw const FormatException('A webhook supports at most 16 headers.');
    }
    final headerName = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]{1,128}$");
    for (final entry in headers.entries) {
      if (!headerName.hasMatch(entry.key) ||
          entry.value.length > 2048 ||
          entry.value.contains(RegExp(r'[\r\n\x00]'))) {
        throw const FormatException(
          'Webhook headers need valid names and single-line values.',
        );
      }
    }
  }
}

/// One real Xray field-routing rule. Empty match groups are omitted; Xray
/// combines the populated groups with AND semantics.
class XrayRoutingRule {
  const XrayRoutingRule({
    required this.action,
    this.domains = const [],
    this.ips = const [],
    this.ports = const [],
    this.sourcePorts = const [],
    this.localPorts = const [],
    this.networks = const [],
    this.sourceIps = const [],
    this.localIps = const [],
    this.inboundTags = const [],
    this.users = const [],
    this.protocols = const [],
    this.attributes = const {},
    this.processes = const [],
    this.ruleTag = '',
    this.webhook,
  });

  final XrayRoutingAction action;
  final List<String> domains;
  final List<String> ips;
  final List<String> ports;
  final List<String> sourcePorts;
  final List<String> localPorts;
  final List<String> networks;
  final List<String> sourceIps;
  final List<String> localIps;
  final List<String> inboundTags;
  final List<String> users;
  final List<String> protocols;
  final Map<String, String> attributes;
  final List<String> processes;
  final String ruleTag;
  final XrayRoutingWebhook? webhook;

  factory XrayRoutingRule.fromJson(Map<String, dynamic> json) {
    List<String> values(String key) => json[key] is List
        ? (json[key] as List).whereType<String>().toList()
        : const [];
    return XrayRoutingRule(
      action: XrayRoutingAction.values.firstWhere(
        (item) => item.name == json['action'],
        orElse: () => XrayRoutingAction.direct,
      ),
      domains: values('domains'),
      ips: values('ips'),
      ports: values('ports'),
      sourcePorts: values('sourcePorts'),
      localPorts: values('localPorts'),
      networks: values('networks'),
      sourceIps: values('sourceIps'),
      localIps: values('localIps'),
      inboundTags: values('inboundTags'),
      users: values('users'),
      protocols: values('protocols'),
      attributes: json['attributes'] is Map
          ? (json['attributes'] as Map).map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      processes: values('processes'),
      ruleTag: json['ruleTag']?.toString() ?? '',
      webhook: json['webhook'] is Map
          ? XrayRoutingWebhook.fromJson(
              Map<String, dynamic>.from(json['webhook'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'action': action.name,
    'domains': domains,
    'ips': ips,
    'ports': ports,
    'sourcePorts': sourcePorts,
    'localPorts': localPorts,
    'networks': networks,
    'sourceIps': sourceIps,
    'localIps': localIps,
    'inboundTags': inboundTags,
    'users': users,
    'protocols': protocols,
    'attributes': attributes,
    'processes': processes,
    'ruleTag': ruleTag,
    'webhook': webhook?.toJson(),
  };

  Map<String, dynamic> toXrayJson(String outboundTag) => {
    'type': 'field',
    if (domains.isNotEmpty) 'domain': domains,
    if (ips.isNotEmpty) 'ip': ips,
    if (ports.isNotEmpty) 'port': ports.join(','),
    if (sourcePorts.isNotEmpty) 'sourcePort': sourcePorts.join(','),
    if (localPorts.isNotEmpty) 'localPort': localPorts.join(','),
    if (networks.isNotEmpty) 'network': networks.join(','),
    if (sourceIps.isNotEmpty) 'sourceIP': sourceIps,
    if (localIps.isNotEmpty) 'localIP': localIps,
    if (inboundTags.isNotEmpty) 'inboundTag': inboundTags,
    if (users.isNotEmpty) 'user': users,
    if (protocols.isNotEmpty) 'protocol': protocols,
    if (attributes.isNotEmpty) 'attrs': attributes,
    if (processes.isNotEmpty) 'process': processes,
    if (ruleTag.trim().isNotEmpty) 'ruleTag': ruleTag.trim(),
    if (webhook != null) 'webhook': webhook!.toXrayJson(),
    'outboundTag': outboundTag,
  };

  void validate() {
    if ([
      domains,
      ips,
      ports,
      sourcePorts,
      localPorts,
      sourceIps,
      localIps,
      inboundTags,
      users,
      protocols,
      processes,
    ].any((values) => values.length > 32)) {
      throw const FormatException(
        'A routing rule supports at most 32 values per match type.',
      );
    }
    if (domains.isEmpty &&
        ips.isEmpty &&
        ports.isEmpty &&
        sourcePorts.isEmpty &&
        localPorts.isEmpty &&
        networks.isEmpty &&
        sourceIps.isEmpty &&
        localIps.isEmpty &&
        inboundTags.isEmpty &&
        users.isEmpty &&
        protocols.isEmpty &&
        attributes.isEmpty &&
        processes.isEmpty) {
      throw const FormatException('Add at least one routing match.');
    }
    for (final value in domains) {
      _validateDomainMatcher(value);
    }
    for (final value in ips) {
      _validateIpMatcher(value);
    }
    for (final value in ports) {
      _validatePortMatcher(value);
    }
    for (final value in [...sourcePorts, ...localPorts]) {
      _validatePortMatcher(value);
    }
    for (final value in [...sourceIps, ...localIps]) {
      _validateIpMatcher(value);
    }
    for (final value in [...inboundTags, ...processes]) {
      if (value.trim().isEmpty ||
          value.length > 256 ||
          value.contains(RegExp(r'[\r\n\x00-\x1f]'))) {
        throw const FormatException(
          'Routing tags and process matchers must be single-line values.',
        );
      }
    }
    for (final value in users) {
      if (value.trim().isEmpty || value.contains(RegExp(r'[\r\n]'))) {
        throw const FormatException(
          'Routing users must be single-line values.',
        );
      }
      if (value.startsWith('regexp:')) _validateRegex(value.substring(7));
    }
    const supportedProtocols = {'http', 'tls', 'quic', 'bittorrent'};
    if (protocols.toSet().length != protocols.length ||
        protocols.any((value) => !supportedProtocols.contains(value))) {
      throw const FormatException(
        'Protocol matches can contain HTTP, TLS, QUIC, or BitTorrent.',
      );
    }
    if (attributes.length > 32) {
      throw const FormatException(
        'A rule supports at most 32 HTTP attributes.',
      );
    }
    for (final entry in attributes.entries) {
      if (entry.key.trim().isEmpty ||
          entry.key.length > 128 ||
          entry.key.contains(RegExp(r'[\r\n=]')) ||
          entry.value.isEmpty ||
          entry.value.length > 512 ||
          entry.value.contains(RegExp(r'[\r\n]'))) {
        throw const FormatException(
          'HTTP attribute keys and values must be valid single-line values.',
        );
      }
      _validateRegex(entry.value);
    }
    if (ruleTag.length > 128 || ruleTag.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException(
        'A rule tag must be a short single-line value.',
      );
    }
    if (networks.toSet().length != networks.length ||
        networks.any((value) => value != 'tcp' && value != 'udp')) {
      throw const FormatException('Network matches can contain TCP or UDP.');
    }
    webhook?.validate();
  }

  static void _validateRegex(String value) {
    if (value.isEmpty) throw const FormatException('Enter a match expression.');
    try {
      RegExp(value);
    } on FormatException {
      throw const FormatException('Enter a valid regular expression.');
    }
  }

  static List<String> parseValues(String input) =>
      _routingLines(input).toSet().toList();

  static List<String> parseDomains(String input) {
    final values = _routingLines(input);
    final normalized = values.map((value) {
      final matcher = value.toLowerCase();
      if (matcher.startsWith('domain:') ||
          matcher.startsWith('full:') ||
          matcher.startsWith('geosite:') ||
          matcher.startsWith('keyword:') ||
          matcher.startsWith('regexp:')) {
        return matcher;
      }
      return 'domain:$matcher';
    }).toList();
    final result = normalized.toSet().toList();
    for (final value in result) {
      _validateDomainMatcher(value);
    }
    return result;
  }

  static List<String> parseIps(String input) {
    final result = _routingLines(
      input,
    ).map((value) => value.toLowerCase()).toSet().toList();
    for (final value in result) {
      _validateIpMatcher(value);
    }
    return result;
  }

  static List<String> parsePorts(String input) {
    final result = _routingLines(input).toSet().toList();
    for (final value in result) {
      _validatePortMatcher(value);
    }
    return result;
  }

  static Map<String, String> parseAttributes(String input) {
    final result = <String, String>{};
    for (final line in input.split(RegExp(r'\r?\n'))) {
      final value = line.trim();
      if (value.isEmpty) continue;
      final separator = value.indexOf('=');
      if (separator < 1 || separator == value.length - 1) {
        throw const FormatException(
          'Enter each HTTP attribute as key=value, one per line.',
        );
      }
      result[value.substring(0, separator).trim()] = value
          .substring(separator + 1)
          .trim();
    }
    if (result.length > 32) {
      throw const FormatException('Add at most 32 HTTP attributes.');
    }
    for (final entry in result.entries) {
      if (entry.key.isEmpty || entry.value.isEmpty) {
        throw const FormatException(
          'HTTP attribute keys and values are required.',
        );
      }
      _validateRegex(entry.value);
    }
    return result;
  }

  static List<String> _routingLines(String input) => input
      .split(RegExp(r'[,;\n]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  static void _validateDomainMatcher(String value) {
    const prefixes = ['domain:', 'full:', 'keyword:', 'regexp:', 'geosite:'];
    final prefix = prefixes.where(value.startsWith).firstOrNull;
    if (prefix == null) {
      throw FormatException('Unsupported Xray domain matcher: $value');
    }
    final matcher = value.substring(prefix.length);
    if (matcher.isEmpty || matcher.contains(RegExp(r'[\r\n]'))) {
      throw FormatException('Invalid Xray domain matcher: $value');
    }
    if (prefix == 'domain:' || prefix == 'full:') {
      XrayPreferences.normalizeDomains([matcher]);
    } else if (prefix == 'geosite:' &&
        !RegExp(r'^[a-z0-9_-]{1,64}$').hasMatch(matcher)) {
      throw FormatException('Invalid Xray geosite matcher: $value');
    } else if (prefix == 'regexp:') {
      try {
        RegExp(matcher);
      } on FormatException {
        throw FormatException('Invalid Xray domain expression: $value');
      }
    }
  }

  static void _validateIpMatcher(String value) {
    if (value.startsWith('geoip:')) {
      if (!RegExp(r'^geoip:[a-z0-9_-]{1,64}$').hasMatch(value)) {
        throw FormatException('Invalid Xray GeoIP matcher: $value');
      }
      return;
    }
    final parts = value.split('/');
    if (parts.length > 2) {
      throw FormatException('Invalid IP or CIDR matcher: $value');
    }
    final address = InternetAddress.tryParse(parts.first);
    if (address == null) {
      throw FormatException('Invalid IP or CIDR matcher: $value');
    }
    if (parts.length == 2) {
      final prefix = int.tryParse(parts.last);
      final maxPrefix = address.type == InternetAddressType.IPv4 ? 32 : 128;
      if (prefix == null || prefix < 0 || prefix > maxPrefix) {
        throw FormatException('Invalid IP or CIDR matcher: $value');
      }
    }
  }

  static void _validatePortMatcher(String value) {
    final parts = value.split('-');
    if (parts.length > 2) throw FormatException('Invalid port match: $value');
    final start = int.tryParse(parts.first);
    final end = parts.length == 2 ? int.tryParse(parts.last) : start;
    if (start == null ||
        end == null ||
        start < 1 ||
        end > 65535 ||
        start > end) {
      throw FormatException('Invalid port match: $value');
    }
  }
}

/// Controls the real inbound sniffers used by Xray's transparent/TUN traffic.
class XraySniffingSettings {
  const XraySniffingSettings({
    this.enabled = true,
    this.destOverride = const ['http', 'tls', 'quic'],
    this.routeOnly = true,
    this.metadataOnly = false,
    this.domainsExcluded = const [],
    this.ipsExcluded = const [],
  });

  final bool enabled;
  final List<String> destOverride;
  final bool routeOnly;
  final bool metadataOnly;
  final List<String> domainsExcluded;
  final List<String> ipsExcluded;

  factory XraySniffingSettings.fromJson(Map<String, dynamic> json) {
    List<String> values(String key, List<String> fallback) => json[key] is List
        ? (json[key] as List).whereType<String>().toList()
        : fallback;
    return XraySniffingSettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      destOverride: values('destOverride', const ['http', 'tls', 'quic']),
      routeOnly: json['routeOnly'] is bool ? json['routeOnly'] as bool : true,
      metadataOnly: json['metadataOnly'] == true,
      domainsExcluded: values('domainsExcluded', const []),
      ipsExcluded: values('ipsExcluded', const []),
    );
  }

  XraySniffingSettings copyWith({
    bool? enabled,
    List<String>? destOverride,
    bool? routeOnly,
    bool? metadataOnly,
    List<String>? domainsExcluded,
    List<String>? ipsExcluded,
  }) => XraySniffingSettings(
    enabled: enabled ?? this.enabled,
    destOverride: destOverride ?? this.destOverride,
    routeOnly: routeOnly ?? this.routeOnly,
    metadataOnly: metadataOnly ?? this.metadataOnly,
    domainsExcluded: domainsExcluded ?? this.domainsExcluded,
    ipsExcluded: ipsExcluded ?? this.ipsExcluded,
  );

  Map<String, dynamic> toJson() {
    validate();
    return {
      'enabled': enabled,
      'destOverride': destOverride,
      'routeOnly': routeOnly,
      'metadataOnly': metadataOnly,
      'domainsExcluded': XrayRoutingRule.parseDomains(
        domainsExcluded.join('\n'),
      ),
      'ipsExcluded': XrayRoutingRule.parseIps(ipsExcluded.join('\n')),
    };
  }

  void validate() {
    const supported = {'http', 'tls', 'quic', 'fakedns'};
    if (destOverride.length > supported.length ||
        destOverride.toSet().length != destOverride.length ||
        destOverride.any((value) => !supported.contains(value))) {
      throw const FormatException(
        'Sniffing supports HTTP, TLS, QUIC and FakeDNS without duplicates.',
      );
    }
    if (domainsExcluded.length > 64 || ipsExcluded.length > 64) {
      throw const FormatException(
        'Add at most 64 sniffing exclusions per type.',
      );
    }
    XrayRoutingRule.parseDomains(domainsExcluded.join('\n'));
    XrayRoutingRule.parseIps(ipsExcluded.join('\n'));
  }

  Map<String, dynamic> toXrayJson({bool forceFakeDns = false}) {
    validate();
    final overrides = [...destOverride];
    if (forceFakeDns && !overrides.contains('fakedns')) {
      overrides.add('fakedns');
    }
    return {
      'enabled': enabled || forceFakeDns,
      'destOverride': overrides,
      'routeOnly': routeOnly,
      'metadataOnly': metadataOnly,
      'domainsExcluded': XrayRoutingRule.parseDomains(
        domainsExcluded.join('\n'),
      ),
      'ipsExcluded': XrayRoutingRule.parseIps(ipsExcluded.join('\n')),
    };
  }
}

/// Optional Xray-core release bounds applied through the core's native
/// top-level `version` guard.
class XrayVersionRequirement {
  const XrayVersionRequirement({this.minimum = '', this.maximum = ''});

  final String minimum;
  final String maximum;

  bool get hasBounds => minimum.trim().isNotEmpty || maximum.trim().isNotEmpty;

  XrayVersionRequirement copyWith({String? minimum, String? maximum}) =>
      XrayVersionRequirement(
        minimum: minimum ?? this.minimum,
        maximum: maximum ?? this.maximum,
      );

  Map<String, dynamic> toJson() {
    validate();
    return {
      if (minimum.trim().isNotEmpty) 'min': minimum.trim(),
      if (maximum.trim().isNotEmpty) 'max': maximum.trim(),
    };
  }

  factory XrayVersionRequirement.fromJson(Map<String, dynamic> json) =>
      XrayVersionRequirement(
        minimum: json['min']?.toString() ?? '',
        maximum: json['max']?.toString() ?? '',
      );

  void validate() {
    List<int> parse(String value, String label) {
      final normalized = value.trim();
      if (normalized.isEmpty) return const [];
      if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(normalized)) {
        throw FormatException('$label must use X.Y.Z format.');
      }
      return normalized.split('.').map(int.parse).toList(growable: false);
    }

    final min = parse(minimum, 'Minimum Xray version');
    final max = parse(maximum, 'Maximum Xray version');
    if (min.isNotEmpty && max.isNotEmpty) {
      for (var index = 0; index < 3; index++) {
        if (min[index] == max[index]) continue;
        if (min[index] > max[index]) {
          throw const FormatException(
            'Minimum Xray version cannot be greater than maximum.',
          );
        }
        break;
      }
    }
  }
}

/// JSON-native settings for Xray's final transport camouflage stage.
///
/// The core owns validation of mask-specific fields; this model validates the
/// outer schema so malformed UI input never reaches the native tunnel.
class XrayFinalMaskSettings {
  const XrayFinalMaskSettings({this.json = '{}'});

  final String json;

  bool get hasOverrides => toXrayJson().isNotEmpty;

  factory XrayFinalMaskSettings.fromJsonText(String input) {
    final settings = XrayFinalMaskSettings(json: input.trim());
    settings.validate();
    return settings;
  }

  Map<String, dynamic> toXrayJson() {
    validate();
    final decoded = jsonDecode(json);
    return Map<String, dynamic>.from(decoded as Map);
  }

  void validate() {
    if (json.length > 65536) {
      throw const FormatException('FinalMask JSON must be under 64 KB.');
    }
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('FinalMask must be a JSON object.');
    }
    final object = Map<String, dynamic>.from(decoded);
    const supported = {'tcp', 'udp', 'quicParams'};
    if (object.keys.any((key) => !supported.contains(key))) {
      throw const FormatException(
        'FinalMask accepts only tcp, udp and quicParams fields.',
      );
    }
    for (final network in const ['tcp', 'udp']) {
      final entries = object[network];
      if (entries == null) continue;
      if (entries is! List || entries.length > 16) {
        throw FormatException('FinalMask $network must be a list of masks.');
      }
      for (final entry in entries) {
        if (entry is! Map ||
            entry['type'] is! String ||
            (entry['type'] as String).trim().isEmpty ||
            entry['settings'] is! Map) {
          throw FormatException(
            'Each FinalMask $network item needs a type and settings object.',
          );
        }
      }
    }
    if (object['quicParams'] != null && object['quicParams'] is! Map) {
      throw const FormatException('FinalMask quicParams must be an object.');
    }
  }
}
