part of 'xray_preferences.dart';

enum RealityFingerprint {
  serverDefault('Server default'),
  chrome('Chrome'),
  firefox('Firefox'),
  safari('Safari'),
  ios('iOS'),
  android('Android'),
  edge('Edge'),
  browser360('360 Browser', '360'),
  qq('QQ'),
  random('Random browser'),
  randomized('Randomized');

  const RealityFingerprint(this.label, [this.configValue]);

  final String label;
  final String? configValue;
  String get value => configValue ?? name;
}

class XrayTlsSettings {
  const XrayTlsSettings({
    this.clientHelloFingerprint = '',
    this.serverName = '',
    this.verifyPeerCertByName = '',
    this.allowInsecure = false,
    this.alpn = '',
    this.minVersion = '',
    this.maxVersion = '',
    this.cipherSuites = '',
    this.disableSystemRoot = false,
    this.enableSessionResumption = false,
    this.pinnedPeerCertSha256 = '',
    this.curvePreferences = '',
    this.masterKeyLog = '',
    this.echConfigList = '',
    this.certificatePem = '',
  });

  final String clientHelloFingerprint;
  final String serverName;
  final String verifyPeerCertByName;
  final bool allowInsecure;
  final String alpn;
  final String minVersion;
  final String maxVersion;
  final String cipherSuites;
  final bool disableSystemRoot;
  final bool enableSessionResumption;
  final String pinnedPeerCertSha256;
  final String curvePreferences;
  final String masterKeyLog;
  final String echConfigList;
  final String certificatePem;

  XrayTlsSettings copyWith({
    String? clientHelloFingerprint,
    String? serverName,
    String? verifyPeerCertByName,
    bool? allowInsecure,
    String? alpn,
    String? minVersion,
    String? maxVersion,
    String? cipherSuites,
    bool? disableSystemRoot,
    bool? enableSessionResumption,
    String? pinnedPeerCertSha256,
    String? curvePreferences,
    String? masterKeyLog,
    String? echConfigList,
    String? certificatePem,
  }) => XrayTlsSettings(
    clientHelloFingerprint:
        clientHelloFingerprint ?? this.clientHelloFingerprint,
    serverName: serverName ?? this.serverName,
    verifyPeerCertByName: verifyPeerCertByName ?? this.verifyPeerCertByName,
    allowInsecure: allowInsecure ?? this.allowInsecure,
    alpn: alpn ?? this.alpn,
    minVersion: minVersion ?? this.minVersion,
    maxVersion: maxVersion ?? this.maxVersion,
    cipherSuites: cipherSuites ?? this.cipherSuites,
    disableSystemRoot: disableSystemRoot ?? this.disableSystemRoot,
    enableSessionResumption:
        enableSessionResumption ?? this.enableSessionResumption,
    pinnedPeerCertSha256: pinnedPeerCertSha256 ?? this.pinnedPeerCertSha256,
    curvePreferences: curvePreferences ?? this.curvePreferences,
    masterKeyLog: masterKeyLog ?? this.masterKeyLog,
    echConfigList: echConfigList ?? this.echConfigList,
    certificatePem: certificatePem ?? this.certificatePem,
  );

  bool get hasOverrides =>
      clientHelloFingerprint.trim().isNotEmpty ||
      serverName.trim().isNotEmpty ||
      verifyPeerCertByName.trim().isNotEmpty ||
      allowInsecure ||
      alpn.trim().isNotEmpty ||
      minVersion.trim().isNotEmpty ||
      maxVersion.trim().isNotEmpty ||
      cipherSuites.trim().isNotEmpty ||
      disableSystemRoot ||
      enableSessionResumption ||
      pinnedPeerCertSha256.trim().isNotEmpty ||
      curvePreferences.trim().isNotEmpty ||
      masterKeyLog.trim().isNotEmpty ||
      echConfigList.trim().isNotEmpty ||
      certificatePem.trim().isNotEmpty;

  bool get hasRealityOverrides =>
      serverName.trim().isNotEmpty || clientHelloFingerprint.trim().isNotEmpty;
  bool get hasTlsOnlyOverrides =>
      verifyPeerCertByName.trim().isNotEmpty ||
      allowInsecure ||
      alpn.trim().isNotEmpty ||
      minVersion.trim().isNotEmpty ||
      maxVersion.trim().isNotEmpty ||
      cipherSuites.trim().isNotEmpty ||
      disableSystemRoot ||
      enableSessionResumption ||
      pinnedPeerCertSha256.trim().isNotEmpty ||
      curvePreferences.trim().isNotEmpty ||
      masterKeyLog.trim().isNotEmpty ||
      echConfigList.trim().isNotEmpty ||
      certificatePem.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'clientHelloFingerprint': clientHelloFingerprint,
    'serverName': serverName,
    'verifyPeerCertByName': verifyPeerCertByName,
    'allowInsecure': allowInsecure,
    'alpn': alpn,
    'minVersion': minVersion,
    'maxVersion': maxVersion,
    'cipherSuites': cipherSuites,
    'disableSystemRoot': disableSystemRoot,
    'enableSessionResumption': enableSessionResumption,
    'pinnedPeerCertSha256': pinnedPeerCertSha256,
    'curvePreferences': curvePreferences,
    'masterKeyLog': masterKeyLog,
    'echConfigList': echConfigList,
    'certificatePem': certificatePem,
  };

  factory XrayTlsSettings.fromJson(Map<String, dynamic> json) =>
      XrayTlsSettings(
        clientHelloFingerprint:
            json['clientHelloFingerprint']?.toString() ?? '',
        serverName: json['serverName']?.toString() ?? '',
        verifyPeerCertByName: json['verifyPeerCertByName']?.toString() ?? '',
        allowInsecure: json['allowInsecure'] == true,
        alpn: json['alpn']?.toString() ?? '',
        minVersion: json['minVersion']?.toString() ?? '',
        maxVersion: json['maxVersion']?.toString() ?? '',
        cipherSuites: json['cipherSuites']?.toString() ?? '',
        disableSystemRoot: json['disableSystemRoot'] == true,
        enableSessionResumption: json['enableSessionResumption'] == true,
        pinnedPeerCertSha256: json['pinnedPeerCertSha256']?.toString() ?? '',
        curvePreferences: json['curvePreferences']?.toString() ?? '',
        masterKeyLog: json['masterKeyLog']?.toString() ?? '',
        echConfigList: json['echConfigList']?.toString() ?? '',
        certificatePem: json['certificatePem']?.toString() ?? '',
      );

  void validate() {
    final fingerprint = clientHelloFingerprint.trim();
    if (fingerprint.isNotEmpty &&
        !const {
          'chrome',
          'firefox',
          'safari',
          'ios',
          'android',
          'edge',
          '360',
          'qq',
          'random',
          'randomized',
        }.contains(fingerprint) &&
        !RegExp(r'^Hello[A-Za-z0-9_]+$').hasMatch(fingerprint)) {
      throw const FormatException(
        'Use a supported browser fingerprint or native uTLS Hello name.',
      );
    }
    for (final value in [serverName, verifyPeerCertByName]) {
      if (value.contains(RegExp(r'[\r\n]'))) {
        throw const FormatException('TLS server names must be single-line.');
      }
    }
    const tlsVersions = ['', '1.0', '1.1', '1.2', '1.3'];
    if (!tlsVersions.contains(minVersion) ||
        !tlsVersions.contains(maxVersion)) {
      throw const FormatException('TLS versions must be 1.0, 1.1, 1.2 or 1.3.');
    }
    if (minVersion.isNotEmpty &&
        maxVersion.isNotEmpty &&
        double.parse(minVersion) > double.parse(maxVersion)) {
      throw const FormatException('TLS minimum version exceeds maximum.');
    }
    final protocols = _splitList(alpn);
    if (protocols.length > 8 ||
        protocols.any(
          (value) => !RegExp(r'^[A-Za-z0-9._/-]{1,32}$').hasMatch(value),
        )) {
      throw const FormatException('Enter valid comma-separated ALPN values.');
    }
    if (cipherSuites.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('Cipher suites must be separated by colons.');
    }
    const curves = {
      'CurveP256',
      'CurveP384',
      'CurveP521',
      'X25519',
      'X25519MLKEM768',
      'SecP256r1MLKEM768',
      'SecP384r1MLKEM1024',
    };
    if (_splitList(curvePreferences).any((curve) => !curves.contains(curve))) {
      throw const FormatException('Choose supported TLS curve names.');
    }
    final pins = _splitList(
      pinnedPeerCertSha256,
      separator: ',',
    ).map((pin) => pin.replaceAll(':', ''));
    if (pins.any((pin) => !RegExp(r'^[A-Fa-f0-9]{64}$').hasMatch(pin))) {
      throw const FormatException(
        'Certificate pins must be SHA-256 hex values.',
      );
    }
    final pem = certificatePem.trim();
    if (pem.isNotEmpty &&
        (!pem.contains('-----BEGIN CERTIFICATE-----') ||
            !pem.contains('-----END CERTIFICATE-----'))) {
      throw const FormatException('Enter a complete PEM CA certificate.');
    }
    if (masterKeyLog.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('TLS key log path must be a single line.');
    }
    validateEchConfig(echConfigList);
  }

  Map<String, dynamic> toXrayJson() {
    validate();
    final pins = _splitList(
      pinnedPeerCertSha256,
      separator: ',',
    ).map((pin) => pin.replaceAll(':', '').toLowerCase()).toList();
    final pemLines = certificatePem
        .trim()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return {
      if (clientHelloFingerprint.trim().isNotEmpty)
        'fingerprint': clientHelloFingerprint.trim(),
      if (serverName.trim().isNotEmpty) 'serverName': serverName.trim(),
      if (verifyPeerCertByName.trim().isNotEmpty)
        'verifyPeerCertByName': _splitList(verifyPeerCertByName).join(','),
      'allowInsecure': allowInsecure,
      if (_splitList(alpn).isNotEmpty) 'alpn': _splitList(alpn),
      if (minVersion.isNotEmpty) 'minVersion': minVersion,
      if (maxVersion.isNotEmpty) 'maxVersion': maxVersion,
      if (cipherSuites.trim().isNotEmpty) 'cipherSuites': cipherSuites.trim(),
      'disableSystemRoot': disableSystemRoot || pemLines.isNotEmpty,
      'enableSessionResumption': enableSessionResumption,
      if (pins.isNotEmpty) 'pinnedPeerCertSha256': pins.join(','),
      if (_splitList(curvePreferences).isNotEmpty)
        'curvePreferences': _splitList(curvePreferences),
      if (masterKeyLog.trim().isNotEmpty) 'masterKeyLog': masterKeyLog.trim(),
      if (echConfigList.trim().isNotEmpty)
        'echConfigList': echConfigList.trim(),
      if (pemLines.isNotEmpty)
        'certificates': [
          {'usage': 'verify', 'certificate': pemLines},
        ],
    };
  }

  static List<String> _splitList(String value, {String separator = ','}) =>
      value
          .split(separator)
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

  static void validateEchConfig(String value) {
    final input = value.trim();
    if (input.isEmpty) return;
    if (input.contains(RegExp(r'\s'))) {
      throw const FormatException('ECH configuration must not contain spaces.');
    }
    final dynamicUri = RegExp(
      r'^(?:([a-z0-9.-]+)\+)?(udp|https|h2c)://(.+)$',
      caseSensitive: false,
    ).firstMatch(input);
    if (dynamicUri != null) {
      final dedicatedDomain = dynamicUri.group(1);
      if (dedicatedDomain != null &&
          !RegExp(
            r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?$',
            caseSensitive: false,
          ).hasMatch(dedicatedDomain)) {
        throw const FormatException('ECH lookup domain is invalid.');
      }
      final uri = Uri.tryParse(
        '${dynamicUri.group(2)}://${dynamicUri.group(3)}',
      );
      if (uri == null ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          (dynamicUri.group(2)!.toLowerCase() == 'udp' &&
              uri.path.isNotEmpty &&
              uri.path != '/')) {
        throw const FormatException('Enter a valid ECH DNS lookup URL.');
      }
      try {
        if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
          throw const FormatException('ECH DNS port is invalid.');
        }
      } on FormatException {
        throw const FormatException('ECH DNS port is invalid.');
      }
      return;
    }
    try {
      final bytes = base64.decode(input);
      if (bytes.length < 6 || _readUint16(bytes, 0) != bytes.length - 2) {
        throw const FormatException('ECH config list framing is invalid.');
      }
      var offset = 2;
      while (offset < bytes.length) {
        if (bytes.length - offset < 4) {
          throw const FormatException('ECH config list entry is truncated.');
        }
        final configLength = _readUint16(bytes, offset + 2);
        offset += 4;
        if (configLength == 0 || offset + configLength > bytes.length) {
          throw const FormatException('ECH config list entry is invalid.');
        }
        offset += configLength;
      }
    } on FormatException {
      throw const FormatException(
        'Enter a valid ECH config list or DNS lookup URL.',
      );
    }
  }

  static int _readUint16(List<int> bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];
}

enum XrayLogLevel {
  debug('Debug'),
  info('Info'),
  warning('Warning'),
  error('Error'),
  none('Off');

  const XrayLogLevel(this.label);

  final String label;
}

enum DnsResolver {
  cloudflare('1.1.1.1', 'Cloudflare'),
  google('8.8.8.8', 'Google'),
  quad9('9.9.9.9', 'Quad9'),
  custom('', 'Custom');

  const DnsResolver(this.address, this.label);
  final String address;
  final String label;
}

enum DnsQueryStrategy {
  useIP('UseIP'),
  useIPv4('UseIPv4'),
  useIPv6('UseIPv6'),
  useSystem('UseSystem');

  const DnsQueryStrategy(this.configValue);
  final String configValue;
}

/// User-controlled DNS options that are written directly to Xray's config.
/// Server entries may be documented Xray DNS URI strings or full
/// DnsServerObject JSON lines for per-domain rules and IP filtering.
class XrayDnsSettings {
  const XrayDnsSettings({
    this.servers = const ['tcp://1.1.1.1'],
    this.queryStrategy = DnsQueryStrategy.useIPv4,
    this.disableCache = false,
    this.serveStale = false,
    this.serveExpiredTtl = 0,
    this.disableFallback = true,
    this.disableFallbackIfMatch = false,
    this.enableParallelQuery = false,
    this.useSystemHosts = false,
    this.fakeDns = false,
    this.clientIp = '',
    this.hosts = const {},
  });

  final List<String> servers;
  final DnsQueryStrategy queryStrategy;
  final bool disableCache;
  final bool serveStale;
  final int serveExpiredTtl;
  final bool disableFallback;
  final bool disableFallbackIfMatch;
  final bool enableParallelQuery;
  final bool useSystemHosts;
  final bool fakeDns;
  final String clientIp;
  final Map<String, dynamic> hosts;

  XrayDnsSettings copyWith({
    List<String>? servers,
    DnsQueryStrategy? queryStrategy,
    bool? disableCache,
    bool? serveStale,
    int? serveExpiredTtl,
    bool? disableFallback,
    bool? disableFallbackIfMatch,
    bool? enableParallelQuery,
    bool? useSystemHosts,
    bool? fakeDns,
    String? clientIp,
    Map<String, dynamic>? hosts,
  }) => XrayDnsSettings(
    servers: servers ?? this.servers,
    queryStrategy: queryStrategy ?? this.queryStrategy,
    disableCache: disableCache ?? this.disableCache,
    serveStale: serveStale ?? this.serveStale,
    serveExpiredTtl: serveExpiredTtl ?? this.serveExpiredTtl,
    disableFallback: disableFallback ?? this.disableFallback,
    disableFallbackIfMatch:
        disableFallbackIfMatch ?? this.disableFallbackIfMatch,
    enableParallelQuery: enableParallelQuery ?? this.enableParallelQuery,
    useSystemHosts: useSystemHosts ?? this.useSystemHosts,
    fakeDns: fakeDns ?? this.fakeDns,
    clientIp: clientIp ?? this.clientIp,
    hosts: hosts ?? this.hosts,
  );

  Map<String, dynamic> toJson() => {
    'servers': servers,
    'queryStrategy': queryStrategy.name,
    'disableCache': disableCache,
    'serveStale': serveStale,
    'serveExpiredTtl': serveExpiredTtl,
    'disableFallback': disableFallback,
    'disableFallbackIfMatch': disableFallbackIfMatch,
    'enableParallelQuery': enableParallelQuery,
    'useSystemHosts': useSystemHosts,
    'fakeDns': fakeDns,
    'clientIp': clientIp,
    'hosts': hosts,
  };

  factory XrayDnsSettings.fromJson(Map<String, dynamic> json) {
    final rawServers = json['servers'];
    final rawHosts = json['hosts'];
    final queryStrategy = DnsQueryStrategy.values.firstWhere(
      (strategy) => strategy.name == json['queryStrategy'],
      orElse: () => DnsQueryStrategy.useIPv4,
    );
    return XrayDnsSettings(
      servers: rawServers is List
          ? rawServers.whereType<String>().toList()
          : const ['tcp://1.1.1.1'],
      queryStrategy: queryStrategy,
      disableCache: json['disableCache'] == true,
      serveStale: json['serveStale'] == true,
      serveExpiredTtl: (json['serveExpiredTtl'] as num?)?.toInt() ?? 0,
      disableFallback: json['disableFallback'] != false,
      disableFallbackIfMatch: json['disableFallbackIfMatch'] == true,
      enableParallelQuery: json['enableParallelQuery'] == true,
      useSystemHosts: json['useSystemHosts'] == true,
      fakeDns: json['fakeDns'] == true,
      clientIp: json['clientIp']?.toString() ?? '',
      hosts: rawHosts is Map ? Map<String, dynamic>.from(rawHosts) : const {},
    );
  }

  List<dynamic> get configServers => [
    if (fakeDns) 'fakedns',
    ...servers.map((entry) {
      final value = entry.trim();
      if (value.startsWith('{')) {
        return Map<String, dynamic>.from(jsonDecode(value) as Map);
      }
      return value;
    }),
  ];

  void validate() {
    if (servers.isEmpty || servers.length > 8) {
      throw const FormatException('Add between 1 and 8 DNS servers.');
    }
    for (final entry in servers) {
      final value = entry.trim();
      if (value.startsWith('{')) {
        final decoded = jsonDecode(value);
        if (decoded is! Map) {
          throw const FormatException(
            'A DNS server JSON line must be an object.',
          );
        }
        final server = Map<String, dynamic>.from(decoded);
        final address = server['address'];
        if (address is! String) {
          throw const FormatException('A DNS server object needs an address.');
        }
        validateDnsServer(address);
        final port = server['port'];
        if (port != null && (port is! int || port < 1 || port > 65535)) {
          throw const FormatException(
            'DNS server port must be from 1 to 65535.',
          );
        }
        for (final key in ['domains', 'expectedIPs', 'unexpectedIPs']) {
          final value = server[key];
          if (value != null &&
              (value is! List || value.any((item) => item is! String))) {
            throw FormatException('$key must be a list of strings.');
          }
        }
        for (final key in ['skipFallback', 'finalQuery', 'disableCache']) {
          if (server[key] != null && server[key] is! bool) {
            throw FormatException('$key must be true or false.');
          }
        }
      } else {
        validateDnsServer(value);
      }
    }
    if (serveExpiredTtl < 0 || serveExpiredTtl > 31536000) {
      throw const FormatException(
        'Stale DNS lifetime must be 0 to 31536000 seconds.',
      );
    }
    final normalizedClientIp = clientIp.trim();
    if (normalizedClientIp.isNotEmpty &&
        InternetAddress.tryParse(normalizedClientIp) == null) {
      throw const FormatException('EDNS client IP must be a valid IP address.');
    }
    if (hosts.length > 128) {
      throw const FormatException('Add at most 128 DNS host mappings.');
    }
    for (final entry in hosts.entries) {
      if (entry.key.isEmpty || entry.key.contains(RegExp(r'\s'))) {
        throw const FormatException('DNS host names cannot contain spaces.');
      }
      if (entry.value is! String && entry.value is! List) {
        throw FormatException('Invalid DNS host mapping for ${entry.key}.');
      }
      final values = entry.value is List
          ? (entry.value as List).whereType<String>()
          : [entry.value.toString()];
      if (values.isEmpty ||
          values.any(
            (value) =>
                value.isEmpty ||
                value.contains(RegExp(r'\s')) ||
                !_isDnsHostTarget(value),
          )) {
        throw FormatException('Invalid DNS host mapping for ${entry.key}.');
      }
    }
  }

  static String validateDnsServer(String value) {
    final address = value.trim();
    if (address.isEmpty || address == 'fakedns') {
      throw const FormatException('Enter a DNS endpoint.');
    }
    if (address == 'localhost') return address;
    final schemeMatch = RegExp(
      r'^([a-z][a-z0-9+.-]*)://',
      caseSensitive: false,
    ).firstMatch(address);
    if (schemeMatch == null) {
      if (InternetAddress.tryParse(address) != null) return address;
      var host = address;
      if (address.startsWith('[')) {
        final match = RegExp(r'^\[([^\]]+)\](?::(\d+))?$').firstMatch(address);
        if (match == null) {
          throw const FormatException('Enter a valid DNS server host.');
        }
        host = match.group(1)!;
        final candidatePort = match.group(2);
        if (candidatePort != null) _validateDnsPort(candidatePort);
      } else {
        final colonCount = ':'.allMatches(address).length;
        if (colonCount > 1) {
          throw const FormatException(
            'Wrap an IPv6 DNS server in brackets when adding a port.',
          );
        }
        if (colonCount == 1) {
          final portSeparator = address.lastIndexOf(':');
          final candidatePort = address.substring(portSeparator + 1);
          if (candidatePort.isNotEmpty) {
            _validateDnsPort(candidatePort);
            host = address.substring(0, portSeparator);
          }
        }
      }
      _validateDnsHost(host);
      return address;
    }
    final scheme = schemeMatch.group(1)!.toLowerCase();
    const allowedSchemes = {
      'tcp',
      'tcp+local',
      'https',
      'https+local',
      'h2c',
      'quic+local',
    };
    if (!allowedSchemes.contains(scheme)) {
      throw const FormatException('Unsupported Xray DNS transport.');
    }
    final uri = Uri.tryParse(address);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException('Enter a valid Xray DNS endpoint.');
    }
    _validateDnsHost(uri.host);
    if (uri.hasPort) _validateDnsPort('${uri.port}');
    if (const {'https', 'https+local', 'h2c'}.contains(scheme) &&
        uri.path.isEmpty) {
      throw const FormatException('DoH endpoints must include a request path.');
    }
    return address;
  }

  static void _validateDnsHost(String host) {
    if (InternetAddress.tryParse(host) != null) return;
    final validDomain = RegExp(
      r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?$',
      caseSensitive: false,
    );
    if (!validDomain.hasMatch(host)) {
      throw const FormatException('Enter a valid DNS server host.');
    }
  }

  static void _validateDnsPort(String value) {
    final port = int.tryParse(value);
    if (port == null || port < 1 || port > 65535) {
      throw const FormatException('DNS server port must be from 1 to 65535.');
    }
  }

  static bool _isDnsHostTarget(String value) {
    if (InternetAddress.tryParse(value) != null ||
        RegExp(r'^#\d+$').hasMatch(value)) {
      return true;
    }
    try {
      _validateDnsHost(value);
      return true;
    } on FormatException {
      return false;
    }
  }
}
