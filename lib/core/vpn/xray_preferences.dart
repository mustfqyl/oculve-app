import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

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

enum Udp443Behavior { reject, allow, skip }

enum TcpFastOpenMode { coreDefault, enabled, disabled }

enum XrayOutboundDomainStrategy {
  asIs('AsIs'),
  useIp('UseIP'),
  useIPv4('UseIPv4'),
  useIPv6('UseIPv6'),
  useIPv4v6('UseIPv4v6'),
  useIPv6v4('UseIPv6v4'),
  forceIp('ForceIP'),
  forceIPv4('ForceIPv4'),
  forceIPv6('ForceIPv6'),
  forceIPv4v6('ForceIPv4v6'),
  forceIPv6v4('ForceIPv6v4');

  const XrayOutboundDomainStrategy(this.value);
  final String value;
}

enum XrayTcpCongestionControl {
  coreDefault(''),
  bbr('bbr'),
  cubic('cubic'),
  reno('reno');

  const XrayTcpCongestionControl(this.value);
  final String value;
}

enum XrayAddressPortStrategy {
  none(''),
  srvPortOnly('SrvPortOnly'),
  srvAddressOnly('SrvAddressOnly'),
  srvPortAndAddress('SrvPortAndAddress'),
  txtPortOnly('TxtPortOnly'),
  txtAddressOnly('TxtAddressOnly'),
  txtPortAndAddress('TxtPortAndAddress');

  const XrayAddressPortStrategy(this.value);
  final String value;
}

enum XrayVlessTrafficAppearance {
  native('Native'),
  xorpub('XOR public key'),
  random('Randomized');

  const XrayVlessTrafficAppearance(this.label);
  final String label;
}

enum XrayVlessResumption {
  zeroRtt('0rtt'),
  oneRtt('1rtt');

  const XrayVlessResumption(this.value);
  final String value;
}

/// Per-profile VLESS Encryption parameters. The final authentication token is
/// supplied by the server operator and must match that server's inbound.
class XrayVlessEncryptionSettings {
  const XrayVlessEncryptionSettings({
    required this.serverAuthentication,
    this.trafficAppearance = XrayVlessTrafficAppearance.native,
    this.resumption = XrayVlessResumption.zeroRtt,
    this.padding = '',
  });

  static const handshake = 'mlkem768x25519plus';

  final String serverAuthentication;
  final XrayVlessTrafficAppearance trafficAppearance;
  final XrayVlessResumption resumption;
  final String padding;

  XrayVlessEncryptionSettings copyWith({
    String? serverAuthentication,
    XrayVlessTrafficAppearance? trafficAppearance,
    XrayVlessResumption? resumption,
    String? padding,
  }) => XrayVlessEncryptionSettings(
    serverAuthentication: serverAuthentication ?? this.serverAuthentication,
    trafficAppearance: trafficAppearance ?? this.trafficAppearance,
    resumption: resumption ?? this.resumption,
    padding: padding ?? this.padding,
  );

  Map<String, dynamic> toJson() => {
    'serverAuthentication': serverAuthentication,
    'trafficAppearance': trafficAppearance.name,
    'resumption': resumption.name,
    'padding': padding,
  };

  factory XrayVlessEncryptionSettings.fromJson(Map<String, dynamic> json) =>
      XrayVlessEncryptionSettings(
        serverAuthentication: json['serverAuthentication']?.toString() ?? '',
        trafficAppearance: XrayVlessTrafficAppearance.values.firstWhere(
          (value) => value.name == json['trafficAppearance'],
          orElse: () => XrayVlessTrafficAppearance.native,
        ),
        resumption: XrayVlessResumption.values.firstWhere(
          (value) => value.name == json['resumption'],
          orElse: () => XrayVlessResumption.zeroRtt,
        ),
        padding: json['padding']?.toString() ?? '',
      );

  String toXrayValue() {
    validate();
    return [
      handshake,
      trafficAppearance.name,
      resumption.value,
      if (padding.trim().isNotEmpty) padding.trim(),
      serverAuthentication.trim(),
    ].join('.');
  }

  void validate() {
    final authentication = serverAuthentication.trim();
    if (authentication.isEmpty ||
        authentication.length > 8192 ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(authentication)) {
      throw const FormatException(
        'Paste the VLESS Encryption authentication parameter from the server.',
      );
    }
    final pattern = padding.trim();
    if (pattern.isEmpty) return;
    final blocks = pattern.split('.');
    if (blocks.length.isEven || blocks.length > 19) {
      throw const FormatException(
        'Padding must alternate padding and delay blocks, starting and ending with padding.',
      );
    }
    for (var index = 0; index < blocks.length; index++) {
      final match = RegExp(
        r'^(\d{1,3})-(\d+)-(\d+)$',
      ).firstMatch(blocks[index]);
      if (match == null) {
        throw const FormatException(
          'Use probability-min-max blocks separated by periods.',
        );
      }
      final probability = int.parse(match.group(1)!);
      final minimum = int.parse(match.group(2)!);
      final maximum = int.parse(match.group(3)!);
      final isPaddingBlock = index.isEven;
      if (probability > 100 ||
          minimum > maximum ||
          maximum > 1000000 ||
          (isPaddingBlock && maximum == 0) ||
          (index == 0 && (probability != 100 || minimum == 0))) {
        throw const FormatException(
          'The first padding block must be 100% with a positive minimum; each block needs valid bounds.',
        );
      }
    }
  }
}

class XrayMuxSettings {
  const XrayMuxSettings({
    this.enabled = false,
    this.concurrency = 8,
    this.xudpConcurrency = 16,
    this.udp443Behavior = Udp443Behavior.reject,
  });

  final bool enabled;
  final int concurrency;
  final int xudpConcurrency;
  final Udp443Behavior udp443Behavior;

  XrayMuxSettings copyWith({
    bool? enabled,
    int? concurrency,
    int? xudpConcurrency,
    Udp443Behavior? udp443Behavior,
  }) => XrayMuxSettings(
    enabled: enabled ?? this.enabled,
    concurrency: concurrency ?? this.concurrency,
    xudpConcurrency: xudpConcurrency ?? this.xudpConcurrency,
    udp443Behavior: udp443Behavior ?? this.udp443Behavior,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'concurrency': concurrency,
    'xudpConcurrency': enabled ? xudpConcurrency : -1,
    'xudpProxyUDP443': enabled ? udp443Behavior.name : 'skip',
  };

  void validate() {
    if (concurrency < 1 || concurrency > 128) {
      throw const FormatException('Mux concurrency must be from 1 to 128.');
    }
    if (xudpConcurrency < 1 || xudpConcurrency > 1024) {
      throw const FormatException('XUDP concurrency must be from 1 to 1024.');
    }
  }
}

class XrayTcpSettings {
  const XrayTcpSettings({
    this.fastOpenMode = TcpFastOpenMode.coreDefault,
    this.keepAliveIdle = 0,
    this.keepAliveInterval = 0,
    this.maxSegmentBytes = 0,
    this.userTimeoutMs = 0,
    this.congestionControl = XrayTcpCongestionControl.coreDefault,
    this.windowClampBytes = 0,
    this.multipathTcp = false,
    this.interfaceName = '',
    this.sendThroughAddress = '',
    this.domainStrategy = XrayOutboundDomainStrategy.asIs,
    this.addressPortStrategy = XrayAddressPortStrategy.none,
    this.happyEyeballs = false,
    this.happyEyeballsDelayMs = 250,
    this.prioritizeIPv6 = false,
    this.addressInterleave = 1,
    this.maxConcurrentAddressAttempts = 4,
  });

  final TcpFastOpenMode fastOpenMode;
  final int keepAliveIdle;
  final int keepAliveInterval;
  final int maxSegmentBytes;
  final int userTimeoutMs;
  final XrayTcpCongestionControl congestionControl;
  final int windowClampBytes;
  final bool multipathTcp;
  final String interfaceName;
  final String sendThroughAddress;
  final XrayOutboundDomainStrategy domainStrategy;
  final XrayAddressPortStrategy addressPortStrategy;
  final bool happyEyeballs;
  final int happyEyeballsDelayMs;
  final bool prioritizeIPv6;
  final int addressInterleave;
  final int maxConcurrentAddressAttempts;

  XrayTcpSettings copyWith({
    TcpFastOpenMode? fastOpenMode,
    int? keepAliveIdle,
    int? keepAliveInterval,
    int? maxSegmentBytes,
    int? userTimeoutMs,
    XrayTcpCongestionControl? congestionControl,
    int? windowClampBytes,
    bool? multipathTcp,
    String? interfaceName,
    String? sendThroughAddress,
    XrayOutboundDomainStrategy? domainStrategy,
    XrayAddressPortStrategy? addressPortStrategy,
    bool? happyEyeballs,
    int? happyEyeballsDelayMs,
    bool? prioritizeIPv6,
    int? addressInterleave,
    int? maxConcurrentAddressAttempts,
  }) => XrayTcpSettings(
    fastOpenMode: fastOpenMode ?? this.fastOpenMode,
    keepAliveIdle: keepAliveIdle ?? this.keepAliveIdle,
    keepAliveInterval: keepAliveInterval ?? this.keepAliveInterval,
    maxSegmentBytes: maxSegmentBytes ?? this.maxSegmentBytes,
    userTimeoutMs: userTimeoutMs ?? this.userTimeoutMs,
    congestionControl: congestionControl ?? this.congestionControl,
    windowClampBytes: windowClampBytes ?? this.windowClampBytes,
    multipathTcp: multipathTcp ?? this.multipathTcp,
    interfaceName: interfaceName ?? this.interfaceName,
    sendThroughAddress: sendThroughAddress ?? this.sendThroughAddress,
    domainStrategy: domainStrategy ?? this.domainStrategy,
    addressPortStrategy: addressPortStrategy ?? this.addressPortStrategy,
    happyEyeballs: happyEyeballs ?? this.happyEyeballs,
    happyEyeballsDelayMs: happyEyeballsDelayMs ?? this.happyEyeballsDelayMs,
    prioritizeIPv6: prioritizeIPv6 ?? this.prioritizeIPv6,
    addressInterleave: addressInterleave ?? this.addressInterleave,
    maxConcurrentAddressAttempts:
        maxConcurrentAddressAttempts ?? this.maxConcurrentAddressAttempts,
  );

  Map<String, dynamic> toJson() => {
    if (fastOpenMode != TcpFastOpenMode.coreDefault)
      'tcpFastOpen': fastOpenMode == TcpFastOpenMode.enabled,
    'tcpKeepAliveIdle': keepAliveIdle,
    'tcpKeepAliveInterval': keepAliveInterval,
    if (maxSegmentBytes > 0) 'tcpMaxSeg': maxSegmentBytes,
    if (userTimeoutMs > 0) 'tcpUserTimeout': userTimeoutMs,
    if (congestionControl != XrayTcpCongestionControl.coreDefault)
      'tcpcongestion': congestionControl.value,
    if (windowClampBytes > 0) 'tcpWindowClamp': windowClampBytes,
    if (multipathTcp) 'tcpMptcp': true,
    if (interfaceName.trim().isNotEmpty) 'interface': interfaceName.trim(),
    if (addressPortStrategy != XrayAddressPortStrategy.none)
      'addressPortStrategy': addressPortStrategy.value,
    if (domainStrategy != XrayOutboundDomainStrategy.asIs)
      'domainStrategy': domainStrategy.value,
    if (happyEyeballs)
      'happyEyeballs': {
        'tryDelayMs': happyEyeballsDelayMs,
        'prioritizeIPv6': prioritizeIPv6,
        'interleave': addressInterleave,
        'maxConcurrentTry': maxConcurrentAddressAttempts,
      },
  };

  Map<String, dynamic> toPreferenceJson() => {
    'maxSegmentBytes': maxSegmentBytes,
    'userTimeoutMs': userTimeoutMs,
    'congestionControl': congestionControl.name,
    'windowClampBytes': windowClampBytes,
    'multipathTcp': multipathTcp,
    'interfaceName': interfaceName,
    'sendThroughAddress': sendThroughAddress,
    'domainStrategy': domainStrategy.name,
    'addressPortStrategy': addressPortStrategy.name,
    'happyEyeballs': happyEyeballs,
    'happyEyeballsDelayMs': happyEyeballsDelayMs,
    'prioritizeIPv6': prioritizeIPv6,
    'addressInterleave': addressInterleave,
    'maxConcurrentAddressAttempts': maxConcurrentAddressAttempts,
  };

  factory XrayTcpSettings.fromPreferenceJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) =>
        json[key] is int ? json[key] as int : fallback;
    final strategyName = json['domainStrategy'];
    final congestionName = json['congestionControl'];
    return XrayTcpSettings(
      maxSegmentBytes: readInt('maxSegmentBytes', 0),
      userTimeoutMs: readInt('userTimeoutMs', 0),
      congestionControl: XrayTcpCongestionControl.values.firstWhere(
        (value) => value.name == congestionName,
        orElse: () => XrayTcpCongestionControl.coreDefault,
      ),
      windowClampBytes: readInt('windowClampBytes', 0),
      multipathTcp: json['multipathTcp'] == true,
      interfaceName: json['interfaceName'] is String
          ? (json['interfaceName'] as String).trim()
          : '',
      sendThroughAddress: json['sendThroughAddress'] is String
          ? (json['sendThroughAddress'] as String).trim()
          : '',
      domainStrategy: XrayOutboundDomainStrategy.values.firstWhere(
        (value) => value.name == strategyName,
        orElse: () => XrayOutboundDomainStrategy.asIs,
      ),
      addressPortStrategy: XrayAddressPortStrategy.values.firstWhere(
        (value) => value.name == json['addressPortStrategy'],
        orElse: () => XrayAddressPortStrategy.none,
      ),
      happyEyeballs: json['happyEyeballs'] == true,
      happyEyeballsDelayMs: readInt('happyEyeballsDelayMs', 250),
      prioritizeIPv6: json['prioritizeIPv6'] == true,
      addressInterleave: readInt('addressInterleave', 1),
      maxConcurrentAddressAttempts: readInt('maxConcurrentAddressAttempts', 4),
    );
  }

  void validate() {
    if (keepAliveIdle < 0 || keepAliveIdle > 86400) {
      throw const FormatException(
        'TCP keepalive idle must be 0 to 86400 seconds.',
      );
    }
    if (keepAliveInterval < 0 || keepAliveInterval > 86400) {
      throw const FormatException(
        'TCP keepalive interval must be 0 to 86400 seconds.',
      );
    }
    if (maxSegmentBytes < 0 || maxSegmentBytes > 65535) {
      throw const FormatException('TCP MSS must be 0 to 65535 bytes.');
    }
    if (userTimeoutMs < 0 || userTimeoutMs > 600000) {
      throw const FormatException('TCP user timeout must be 0 to 600000 ms.');
    }
    if (windowClampBytes < 0 || windowClampBytes > 16777216) {
      throw const FormatException(
        'TCP window clamp must be 0 to 16777216 bytes.',
      );
    }
    if (interfaceName.trim().length > 128 ||
        interfaceName.contains(RegExp(r'[\r\n\u0000]'))) {
      throw const FormatException('Network interface name is invalid.');
    }
    if (sendThroughAddress.trim().isNotEmpty &&
        InternetAddress.tryParse(sendThroughAddress.trim()) == null) {
      throw const FormatException(
        'Send-through must be a local IPv4 or IPv6 address.',
      );
    }
    if (happyEyeballs && domainStrategy == XrayOutboundDomainStrategy.asIs) {
      throw const FormatException(
        'Happy Eyeballs requires an explicit IP domain strategy.',
      );
    }
    if (happyEyeballsDelayMs < 1 || happyEyeballsDelayMs > 10000) {
      throw const FormatException(
        'Happy Eyeballs delay must be 1 to 10000 ms.',
      );
    }
    if (addressInterleave < 1 || addressInterleave > 10) {
      throw const FormatException('Address interleave must be 1 to 10.');
    }
    if (maxConcurrentAddressAttempts < 1 || maxConcurrentAddressAttempts > 32) {
      throw const FormatException(
        'Concurrent address attempts must be 1 to 32.',
      );
    }
  }
}

enum XrayXhttpMode {
  profileDefault('Profile default', ''),
  auto('Auto', 'auto'),
  packetUp('Packet-up', 'packet-up'),
  streamUp('Stream-up', 'stream-up'),
  streamOne('Stream-one', 'stream-one');

  const XrayXhttpMode(this.label, this.value);

  final String label;
  final String value;
}

enum XrayBooleanOverride {
  profileDefault('Profile default'),
  enabled('Enabled'),
  disabled('Disabled');

  const XrayBooleanOverride(this.label);

  final String label;

  bool? get value => switch (this) {
    XrayBooleanOverride.profileDefault => null,
    XrayBooleanOverride.enabled => true,
    XrayBooleanOverride.disabled => false,
  };
}

class XrayXmuxSettings {
  const XrayXmuxSettings({
    this.maxConcurrency = '',
    this.maxConnections = '',
    this.connectionReuseLimit = '',
    this.maxRequestCount = '',
    this.maxReusableSeconds = '',
    this.keepAliveSeconds = '',
  });

  final String maxConcurrency;
  final String maxConnections;
  final String connectionReuseLimit;
  final String maxRequestCount;
  final String maxReusableSeconds;
  final String keepAliveSeconds;

  bool get hasOverrides => [
    maxConcurrency,
    maxConnections,
    connectionReuseLimit,
    maxRequestCount,
    maxReusableSeconds,
    keepAliveSeconds,
  ].any((value) => value.trim().isNotEmpty);

  XrayXmuxSettings copyWith({
    String? maxConcurrency,
    String? maxConnections,
    String? connectionReuseLimit,
    String? maxRequestCount,
    String? maxReusableSeconds,
    String? keepAliveSeconds,
  }) => XrayXmuxSettings(
    maxConcurrency: maxConcurrency ?? this.maxConcurrency,
    maxConnections: maxConnections ?? this.maxConnections,
    connectionReuseLimit: connectionReuseLimit ?? this.connectionReuseLimit,
    maxRequestCount: maxRequestCount ?? this.maxRequestCount,
    maxReusableSeconds: maxReusableSeconds ?? this.maxReusableSeconds,
    keepAliveSeconds: keepAliveSeconds ?? this.keepAliveSeconds,
  );

  Map<String, dynamic> toJson() => {
    if (maxConcurrency.trim().isNotEmpty)
      'maxConcurrency': _numberOrRange(maxConcurrency),
    if (maxConnections.trim().isNotEmpty)
      'maxConnections': _numberOrRange(maxConnections),
    if (connectionReuseLimit.trim().isNotEmpty)
      'cMaxReuseTimes': _numberOrRange(connectionReuseLimit),
    if (maxRequestCount.trim().isNotEmpty)
      'hMaxRequestTimes': _numberOrRange(maxRequestCount),
    if (maxReusableSeconds.trim().isNotEmpty)
      'hMaxReusableSecs': _numberOrRange(maxReusableSeconds),
    if (keepAliveSeconds.trim().isNotEmpty)
      'hKeepAlivePeriod': int.parse(keepAliveSeconds.trim()),
  };

  void validate() {
    for (final value in [
      maxConcurrency,
      maxConnections,
      connectionReuseLimit,
      maxRequestCount,
      maxReusableSeconds,
    ]) {
      if (value.trim().isNotEmpty) _validateRange(value, 'XMUX value');
    }
    final concurrency = maxConcurrency.trim();
    final connections = maxConnections.trim();
    if (concurrency.isNotEmpty && connections.isNotEmpty) {
      throw const FormatException(
        'XMUX maxConcurrency and maxConnections cannot both be set.',
      );
    }
    final keepAlive = keepAliveSeconds.trim();
    if (keepAlive.isNotEmpty &&
        (int.tryParse(keepAlive) == null || int.parse(keepAlive) < -1)) {
      throw const FormatException(
        'XMUX keepalive must be -1 or a whole number of seconds.',
      );
    }
  }

  static dynamic _numberOrRange(String input) =>
      int.tryParse(input.trim()) ?? input.trim();

  static void _validateRange(String input, String label) {
    final value = input.trim();
    final parts = value.split('-');
    if (parts.length > 2 ||
        parts.any((part) => int.tryParse(part) == null) ||
        parts.any((part) => int.parse(part) < 0)) {
      throw FormatException('$label must be a non-negative number or range.');
    }
    if (parts.length == 2 && int.parse(parts.first) > int.parse(parts.last)) {
      throw FormatException('$label range is reversed.');
    }
  }
}

class XrayXhttpSettings {
  const XrayXhttpSettings({
    this.mode = XrayXhttpMode.profileDefault,
    this.host = '',
    this.path = '',
    this.headersJson = '{}',
    this.paddingBytes = '',
    this.noGrpcHeader = XrayBooleanOverride.profileDefault,
    this.maxEachPostBytes = '',
    this.minimumPostIntervalMs = '',
    this.xmux = const XrayXmuxSettings(),
    this.downloadSettingsJson = '',
    this.extraJson = '{}',
  });

  final XrayXhttpMode mode;
  final String host;
  final String path;
  final String headersJson;
  final String paddingBytes;
  final XrayBooleanOverride noGrpcHeader;
  final String maxEachPostBytes;
  final String minimumPostIntervalMs;
  final XrayXmuxSettings xmux;
  final String downloadSettingsJson;
  final String extraJson;

  bool get hasOverrides =>
      mode != XrayXhttpMode.profileDefault ||
      host.trim().isNotEmpty ||
      path.trim().isNotEmpty ||
      _hasJsonObject(headersJson) ||
      paddingBytes.trim().isNotEmpty ||
      noGrpcHeader != XrayBooleanOverride.profileDefault ||
      maxEachPostBytes.trim().isNotEmpty ||
      minimumPostIntervalMs.trim().isNotEmpty ||
      xmux.hasOverrides ||
      downloadSettingsJson.trim().isNotEmpty ||
      _hasJsonObject(extraJson);

  XrayXhttpSettings copyWith({
    XrayXhttpMode? mode,
    String? host,
    String? path,
    String? headersJson,
    String? paddingBytes,
    XrayBooleanOverride? noGrpcHeader,
    String? maxEachPostBytes,
    String? minimumPostIntervalMs,
    XrayXmuxSettings? xmux,
    String? downloadSettingsJson,
    String? extraJson,
  }) => XrayXhttpSettings(
    mode: mode ?? this.mode,
    host: host ?? this.host,
    path: path ?? this.path,
    headersJson: headersJson ?? this.headersJson,
    paddingBytes: paddingBytes ?? this.paddingBytes,
    noGrpcHeader: noGrpcHeader ?? this.noGrpcHeader,
    maxEachPostBytes: maxEachPostBytes ?? this.maxEachPostBytes,
    minimumPostIntervalMs: minimumPostIntervalMs ?? this.minimumPostIntervalMs,
    xmux: xmux ?? this.xmux,
    downloadSettingsJson: downloadSettingsJson ?? this.downloadSettingsJson,
    extraJson: extraJson ?? this.extraJson,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'host': host,
    'path': path,
    'headersJson': headersJson,
    'paddingBytes': paddingBytes,
    'noGrpcHeader': noGrpcHeader.name,
    'maxEachPostBytes': maxEachPostBytes,
    'minimumPostIntervalMs': minimumPostIntervalMs,
    'xmux': {
      'maxConcurrency': xmux.maxConcurrency,
      'maxConnections': xmux.maxConnections,
      'connectionReuseLimit': xmux.connectionReuseLimit,
      'maxRequestCount': xmux.maxRequestCount,
      'maxReusableSeconds': xmux.maxReusableSeconds,
      'keepAliveSeconds': xmux.keepAliveSeconds,
    },
    'downloadSettingsJson': downloadSettingsJson,
    'extraJson': extraJson,
  };

  factory XrayXhttpSettings.fromJson(Map<String, dynamic> json) {
    final xmux = json['xmux'] is Map
        ? Map<String, dynamic>.from(json['xmux'] as Map)
        : const <String, dynamic>{};
    return XrayXhttpSettings(
      mode: XrayXhttpMode.values.firstWhere(
        (value) => value.name == json['mode'],
        orElse: () => XrayXhttpMode.profileDefault,
      ),
      host: json['host']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      headersJson: json['headersJson']?.toString() ?? '{}',
      paddingBytes: json['paddingBytes']?.toString() ?? '',
      noGrpcHeader: XrayBooleanOverride.values.firstWhere(
        (value) => value.name == json['noGrpcHeader'],
        orElse: () => XrayBooleanOverride.profileDefault,
      ),
      maxEachPostBytes: json['maxEachPostBytes']?.toString() ?? '',
      minimumPostIntervalMs: json['minimumPostIntervalMs']?.toString() ?? '',
      xmux: XrayXmuxSettings(
        maxConcurrency: xmux['maxConcurrency']?.toString() ?? '',
        maxConnections: xmux['maxConnections']?.toString() ?? '',
        connectionReuseLimit: xmux['connectionReuseLimit']?.toString() ?? '',
        maxRequestCount: xmux['maxRequestCount']?.toString() ?? '',
        maxReusableSeconds: xmux['maxReusableSeconds']?.toString() ?? '',
        keepAliveSeconds: xmux['keepAliveSeconds']?.toString() ?? '',
      ),
      downloadSettingsJson: json['downloadSettingsJson']?.toString() ?? '',
      extraJson: json['extraJson']?.toString() ?? '{}',
    );
  }

  void validate() {
    xmux.validate();
    if (host.contains(RegExp(r'[\r\n]')) ||
        path.contains(RegExp(r'[\r\n]')) ||
        (path.trim().isNotEmpty && !path.trim().startsWith('/'))) {
      throw const FormatException('XHTTP host and path are invalid.');
    }
    _validateRange(paddingBytes, 'XHTTP header padding');
    _validateRange(maxEachPostBytes, 'XHTTP max POST size');
    _validateRange(minimumPostIntervalMs, 'XHTTP POST interval');
    final headers = _parseJsonObject(headersJson, 'XHTTP headers');
    for (final entry in headers.entries) {
      if (entry.key.contains(RegExp(r'[\r\n:]')) ||
          entry.value is! String ||
          (entry.value as String).contains(RegExp(r'[\r\n]'))) {
        throw const FormatException('XHTTP headers must be safe text values.');
      }
    }
    final extra = _parseJsonObject(extraJson, 'XHTTP extra settings');
    final download = downloadSettingsJson.trim();
    if (download.isNotEmpty) {
      final parsed = _parseJsonObject(download, 'XHTTP download settings');
      final port = parsed['port'];
      if (parsed['network'] != 'xhttp' ||
          parsed['address'] is! String ||
          (parsed['address'] as String).trim().isEmpty ||
          port is! int ||
          port < 1 ||
          port > 65535 ||
          parsed['xhttpSettings'] is! Map ||
          !const {'none', 'tls', 'reality'}.contains(parsed['security'])) {
        throw const FormatException(
          'Download settings need an XHTTP address, port, security and transport object.',
        );
      }
    }
    if (extra['xmux'] != null && extra['xmux'] is! Map) {
      throw const FormatException('XHTTP extra.xmux must be an object.');
    }
  }

  Map<String, dynamic> applyTo(Map<String, dynamic> source) {
    validate();
    final settings = Map<String, dynamic>.from(source);
    if (mode != XrayXhttpMode.profileDefault) {
      settings['mode'] = mode.value;
    }
    if (host.trim().isNotEmpty) settings['host'] = host.trim();
    if (path.trim().isNotEmpty) settings['path'] = path.trim();
    final extra = Map<String, dynamic>.from(
      settings['extra'] as Map? ?? const {},
    );
    extra.addAll(_parseJsonObject(extraJson, 'XHTTP extra settings'));
    final headers = _parseJsonObject(headersJson, 'XHTTP headers');
    if (headers.isNotEmpty) extra['headers'] = headers;
    if (paddingBytes.trim().isNotEmpty) {
      extra['xPaddingBytes'] = paddingBytes.trim();
    }
    if (noGrpcHeader.value != null) {
      extra['noGRPCHeader'] = noGrpcHeader.value;
    }
    if (maxEachPostBytes.trim().isNotEmpty) {
      extra['scMaxEachPostBytes'] = XrayXmuxSettings._numberOrRange(
        maxEachPostBytes,
      );
    }
    if (minimumPostIntervalMs.trim().isNotEmpty) {
      extra['scMinPostsIntervalMs'] = XrayXmuxSettings._numberOrRange(
        minimumPostIntervalMs,
      );
    }
    if (xmux.hasOverrides) {
      final existingXmux = Map<String, dynamic>.from(
        extra['xmux'] as Map? ?? const {},
      );
      existingXmux.addAll(xmux.toJson());
      extra['xmux'] = existingXmux;
    }
    if (downloadSettingsJson.trim().isNotEmpty) {
      extra['downloadSettings'] = _parseJsonObject(
        downloadSettingsJson,
        'XHTTP download settings',
      );
    }
    if (extra.isNotEmpty) settings['extra'] = extra;
    return settings;
  }

  static bool _hasJsonObject(String input) {
    try {
      return _parseJsonObject(input, 'settings').isNotEmpty;
    } on FormatException {
      return false;
    }
  }

  static Map<String, dynamic> _parseJsonObject(String input, String label) {
    try {
      final decoded = jsonDecode(input);
      if (decoded is! Map) throw const FormatException();
      return Map<String, dynamic>.from(decoded);
    } on Object {
      throw FormatException('$label must be a JSON object.');
    }
  }

  static void _validateRange(String input, String label) {
    if (input.trim().isEmpty) return;
    XrayXmuxSettings._validateRange(input, label);
  }
}

/// Xray local policy for the managed client connection level (level 0).
///
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

class XrayPreferences {
  static const _fingerprintKey = 'xray.reality.fingerprint.v1';
  static const _tlsSettingsKey = 'xray.tls.settings.v1';
  static const _xhttpSettingsKey = 'xray.transport.xhttp.v1';
  static const _policySettingsKey = 'xray.policy.level0.v1';
  static const _customConfigKey = 'xray.config.overlay.v1';
  static const _versionRequirementKey = 'xray.core.version_requirement.v1';
  static const _finalMaskSettingsKey = 'xray.transport.finalmask.v1';
  static const _logLevelKey = 'xray.log.level.v1';
  static const _bypassDomainsKey = 'xray.routing.bypass_domains.v1';
  static const _routingRulesKey = 'xray.routing.rules.v1';
  static const _sniffingSettingsKey = 'xray.sniffing.settings.v1';
  static const _blockedAppsKey = 'xray.routing.android_blocked_apps.v1';
  static const _dnsResolverKey = 'xray.dns.resolver.v1';
  static const _customDnsAddressKey = 'xray.dns.custom_address.v1';
  static const _dnsSettingsKey = 'xray.dns.settings.v2';
  static const _muxEnabledKey = 'xray.mux.enabled.v1';
  static const _muxConcurrencyKey = 'xray.mux.concurrency.v1';
  static const _xudpConcurrencyKey = 'xray.mux.xudp_concurrency.v1';
  static const _udp443BehaviorKey = 'xray.mux.udp443_behavior.v1';
  static const _tcpFastOpenModeKey = 'xray.tcp.fast_open_mode.v1';
  static const _tcpKeepAliveIdleKey = 'xray.tcp.keepalive_idle.v1';
  static const _tcpKeepAliveIntervalKey = 'xray.tcp.keepalive_interval.v1';
  static const _tcpAdvancedSettingsKey = 'xray.tcp.advanced.v1';
  static const _vlessEncryptionOverridesKey =
      'xray.vless.encryption.profiles.v1';

  static Future<XrayVlessEncryptionSettings?> vlessEncryptionSettingsFor(
    String profileId,
  ) async {
    _validateProfileId(profileId);
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_vlessEncryptionOverridesKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded[profileId] is! Map) return null;
      return XrayVlessEncryptionSettings.fromJson(
        Map<String, dynamic>.from(decoded[profileId] as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> setVlessEncryptionSettingsFor(
    String profileId,
    XrayVlessEncryptionSettings settings,
  ) async {
    _validateProfileId(profileId);
    settings.validate();
    final preferences = await SharedPreferences.getInstance();
    final overrides = _readVlessEncryptionOverrides(
      preferences.getString(_vlessEncryptionOverridesKey),
    );
    overrides[profileId] = settings.toJson();
    await preferences.setString(
      _vlessEncryptionOverridesKey,
      jsonEncode(overrides),
    );
  }

  static Future<void> clearVlessEncryptionSettingsFor(String profileId) async {
    _validateProfileId(profileId);
    final preferences = await SharedPreferences.getInstance();
    final overrides = _readVlessEncryptionOverrides(
      preferences.getString(_vlessEncryptionOverridesKey),
    )..remove(profileId);
    await preferences.setString(
      _vlessEncryptionOverridesKey,
      jsonEncode(overrides),
    );
  }

  static Map<String, dynamic> _readVlessEncryptionOverrides(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  static void _validateProfileId(String profileId) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(profileId)) {
      throw const FormatException('Invalid VPN profile identifier.');
    }
  }

  static Future<XrayTcpSettings> tcpSettings() async {
    final preferences = await SharedPreferences.getInstance();
    Map<String, dynamic> advanced = const {};
    final rawAdvanced = preferences.getString(_tcpAdvancedSettingsKey);
    if (rawAdvanced != null) {
      try {
        final decoded = jsonDecode(rawAdvanced);
        if (decoded is Map) advanced = Map<String, dynamic>.from(decoded);
      } on FormatException {
        advanced = const {};
      }
    }
    final settings = XrayTcpSettings.fromPreferenceJson(advanced).copyWith(
      fastOpenMode: TcpFastOpenMode.values.firstWhere(
        (mode) => mode.name == preferences.getString(_tcpFastOpenModeKey),
        orElse: () => TcpFastOpenMode.coreDefault,
      ),
      keepAliveIdle: preferences.getInt(_tcpKeepAliveIdleKey) ?? 0,
      keepAliveInterval: preferences.getInt(_tcpKeepAliveIntervalKey) ?? 0,
    );
    try {
      settings.validate();
      return settings;
    } on FormatException {
      return const XrayTcpSettings();
    }
  }

  static Future<void> setTcpSettings(XrayTcpSettings settings) async {
    settings.validate();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _tcpFastOpenModeKey,
      settings.fastOpenMode.name,
    );
    await preferences.setInt(_tcpKeepAliveIdleKey, settings.keepAliveIdle);
    await preferences.setInt(
      _tcpKeepAliveIntervalKey,
      settings.keepAliveInterval,
    );
    await preferences.setString(
      _tcpAdvancedSettingsKey,
      jsonEncode(settings.toPreferenceJson()),
    );
  }

  static Future<XrayMuxSettings> muxSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final behavior = Udp443Behavior.values.firstWhere(
      (item) => item.name == preferences.getString(_udp443BehaviorKey),
      orElse: () => Udp443Behavior.reject,
    );
    final settings = XrayMuxSettings(
      enabled: preferences.getBool(_muxEnabledKey) ?? false,
      concurrency: preferences.getInt(_muxConcurrencyKey) ?? 8,
      xudpConcurrency: preferences.getInt(_xudpConcurrencyKey) ?? 16,
      udp443Behavior: behavior,
    );
    try {
      settings.validate();
      return settings;
    } on FormatException {
      return const XrayMuxSettings();
    }
  }

  static Future<void> setMuxSettings(XrayMuxSettings settings) async {
    settings.validate();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_muxEnabledKey, settings.enabled);
    await preferences.setInt(_muxConcurrencyKey, settings.concurrency);
    await preferences.setInt(_xudpConcurrencyKey, settings.xudpConcurrency);
    await preferences.setString(
      _udp443BehaviorKey,
      settings.udp443Behavior.name,
    );
  }

  static Future<DnsResolver> dnsResolver() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_dnsResolverKey);
    return DnsResolver.values.firstWhere(
      (item) => item.name == saved,
      orElse: () => DnsResolver.cloudflare,
    );
  }

  static Future<void> setDnsResolver(DnsResolver resolver) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_dnsResolverKey, resolver.name);
  }

  static Future<String> dnsServerAddress() async {
    final resolver = await dnsResolver();
    if (resolver != DnsResolver.custom) return resolver.address;
    final preferences = await SharedPreferences.getInstance();
    final address = preferences.getString(_customDnsAddressKey);
    if (address == null) {
      throw const FormatException('Enter a custom IPv4 DNS address.');
    }
    return validateDnsAddress(address);
  }

  static Future<void> setCustomDnsAddress(String address) async {
    final normalized = validateDnsAddress(address);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_customDnsAddressKey, normalized);
  }

  static Future<XrayDnsSettings> dnsSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_dnsSettingsKey);
    if (saved != null) {
      try {
        final settings = XrayDnsSettings.fromJson(
          jsonDecode(saved) as Map<String, dynamic>,
        );
        settings.validate();
        return settings;
      } catch (_) {
        return const XrayDnsSettings();
      }
    }
    final resolver = await dnsResolver();
    final address = resolver == DnsResolver.custom
        ? await dnsServerAddress().catchError((_) => '1.1.1.1')
        : resolver.address;
    return XrayDnsSettings(servers: ['tcp://$address']);
  }

  static Future<void> setDnsSettings(XrayDnsSettings settings) async {
    settings.validate();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_dnsSettingsKey, jsonEncode(settings.toJson()));
  }

  static Future<XrayXhttpSettings> xhttpSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_xhttpSettingsKey);
    if (saved == null) return const XrayXhttpSettings();
    try {
      final settings = XrayXhttpSettings.fromJson(
        jsonDecode(saved) as Map<String, dynamic>,
      );
      settings.validate();
      return settings;
    } catch (_) {
      return const XrayXhttpSettings();
    }
  }

  static Future<void> setXhttpSettings(XrayXhttpSettings settings) async {
    settings.validate();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _xhttpSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  static Future<XrayPolicySettings> policySettings() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_policySettingsKey);
    if (saved == null) return const XrayPolicySettings();
    try {
      final settings = XrayPolicySettings.fromJson(
        jsonDecode(saved) as Map<String, dynamic>,
      );
      settings.validate();
      return settings;
    } catch (_) {
      return const XrayPolicySettings();
    }
  }

  static Future<void> setPolicySettings(XrayPolicySettings settings) async {
    settings.validate();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _policySettingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  /// Returns the raw JSON overlay applied to every imported profile.
  static Future<String> customConfigSource() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_customConfigKey) ?? '{}';
    try {
      parseCustomConfigOverrides(saved);
      return saved;
    } on FormatException {
      return '{}';
    }
  }

  static Future<XrayVersionRequirement?> versionRequirement() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_versionRequirementKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final requirement = XrayVersionRequirement.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      requirement.validate();
      return requirement.hasBounds ? requirement : null;
    } catch (_) {
      return null;
    }
  }

  static Future<XrayFinalMaskSettings> finalMaskSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_finalMaskSettingsKey);
    if (raw == null) return const XrayFinalMaskSettings();
    try {
      return XrayFinalMaskSettings.fromJsonText(raw);
    } on Object {
      return const XrayFinalMaskSettings();
    }
  }

  static Future<void> setFinalMaskSettings(
    XrayFinalMaskSettings settings,
  ) async {
    settings.validate();
    final preferences = await SharedPreferences.getInstance();
    if (settings.toXrayJson().isEmpty) {
      await preferences.remove(_finalMaskSettingsKey);
    } else {
      await preferences.setString(_finalMaskSettingsKey, settings.json);
    }
  }

  static Future<void> setVersionRequirement(
    XrayVersionRequirement requirement,
  ) async {
    requirement.validate();
    final preferences = await SharedPreferences.getInstance();
    if (!requirement.hasBounds) {
      await preferences.remove(_versionRequirementKey);
      return;
    }
    await preferences.setString(
      _versionRequirementKey,
      jsonEncode(requirement.toJson()),
    );
  }

  static Future<Map<String, dynamic>> customConfigOverrides() async =>
      parseCustomConfigOverrides(await customConfigSource());

  static Future<void> setCustomConfigSource(String source) async {
    parseCustomConfigOverrides(source);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_customConfigKey, source.trim());
  }

  static Map<String, dynamic> parseCustomConfigOverrides(String source) {
    if (utf8.encode(source).length > 65536) {
      throw const FormatException('Custom Xray JSON must be 64 KB or smaller.');
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'Custom Xray JSON must be a top-level object.',
      );
    }
    final overrides = Map<String, dynamic>.from(decoded);
    _validateCustomJsonValue(overrides, r'$');
    return overrides;
  }

  static void _validateCustomJsonValue(Object? value, String path) {
    if (value == null) {
      throw FormatException('Remove null values from custom JSON at $path.');
    }
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw FormatException('JSON keys must be strings at $path.');
        }
        _validateCustomJsonValue(entry.value, '$path.${entry.key}');
      }
    } else if (value is List) {
      for (var index = 0; index < value.length; index++) {
        _validateCustomJsonValue(value[index], '$path[$index]');
      }
    } else if (value is! String && value is! num && value is! bool) {
      throw FormatException('Unsupported JSON value at $path.');
    }
  }

  static String validateDnsAddress(String value) {
    final address = value.trim();
    if (InternetAddress.tryParse(address)?.type != InternetAddressType.IPv4) {
      throw const FormatException('Enter a valid IPv4 DNS address.');
    }
    return address;
  }

  static Future<List<String>> bypassDomains() async {
    final preferences = await SharedPreferences.getInstance();
    return List.unmodifiable(
      preferences.getStringList(_bypassDomainsKey) ?? [],
    );
  }

  static Future<void> setBypassDomains(List<String> domains) async {
    final normalized = normalizeDomains(domains);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_bypassDomainsKey, normalized);
  }

  static Future<List<XrayRoutingRule>> routingRules() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_routingRulesKey);
    if (encoded == null) return const [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      return List.unmodifiable(
        decoded
            .whereType<Map>()
            .map(
              (value) =>
                  XrayRoutingRule.fromJson(Map<String, dynamic>.from(value)),
            )
            .where((rule) {
              try {
                rule.validate();
                return true;
              } on FormatException {
                return false;
              }
            }),
      );
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setRoutingRules(List<XrayRoutingRule> rules) async {
    if (rules.length > 32) {
      throw const FormatException('Add at most 32 routing rules.');
    }
    for (final rule in rules) {
      rule.validate();
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _routingRulesKey,
      jsonEncode(rules.map((rule) => rule.toJson()).toList()),
    );
  }

  static Future<XraySniffingSettings> sniffingSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_sniffingSettingsKey);
    if (encoded == null) return const XraySniffingSettings();
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return const XraySniffingSettings();
      final settings = XraySniffingSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      settings.validate();
      return settings;
    } catch (_) {
      return const XraySniffingSettings();
    }
  }

  static Future<void> setSniffingSettings(XraySniffingSettings settings) async {
    settings.validate();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _sniffingSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  static Future<List<String>> blockedApps() async {
    final preferences = await SharedPreferences.getInstance();
    return List.unmodifiable(preferences.getStringList(_blockedAppsKey) ?? []);
  }

  static Future<void> setBlockedApps(List<String> apps) async {
    final normalized = normalizeBlockedApps(apps);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_blockedAppsKey, normalized);
  }

  static List<String> normalizeBlockedApps(Iterable<String> apps) {
    final result = <String>[];
    final valid = RegExp(
      r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$',
    );
    for (final value in apps) {
      final app = value.trim();
      if (app.isEmpty) continue;
      if (!valid.hasMatch(app)) {
        throw FormatException('Invalid Android app identifier: $value');
      }
      if (!result.contains(app)) result.add(app);
      if (result.length > 100) {
        throw const FormatException('Choose at most 100 apps to bypass.');
      }
    }
    return result;
  }

  static List<String> normalizeDomains(Iterable<String> domains) {
    final result = <String>[];
    final valid = RegExp(
      r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?$',
    );
    for (final value in domains) {
      final domain = value.trim().toLowerCase();
      if (domain.isEmpty) continue;
      if (!valid.hasMatch(domain)) {
        throw FormatException('Invalid domain: $value');
      }
      if (!result.contains(domain)) result.add(domain);
      if (result.length > 32) {
        throw const FormatException('Add at most 32 bypass domains.');
      }
    }
    return result;
  }

  static Future<RealityFingerprint> fingerprint() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_fingerprintKey);
    return RealityFingerprint.values.firstWhere(
      (item) => item.name == saved,
      orElse: () => RealityFingerprint.serverDefault,
    );
  }

  static Future<XrayTlsSettings> tlsSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_tlsSettingsKey);
    if (saved == null) return const XrayTlsSettings();
    try {
      final settings = XrayTlsSettings.fromJson(
        jsonDecode(saved) as Map<String, dynamic>,
      );
      settings.validate();
      return settings;
    } catch (_) {
      return const XrayTlsSettings();
    }
  }

  static Future<void> setTlsSettings(XrayTlsSettings settings) async {
    settings.validate();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tlsSettingsKey, jsonEncode(settings.toJson()));
  }

  static Future<XrayLogLevel> logLevel() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_logLevelKey);
    return XrayLogLevel.values.firstWhere(
      (level) => level.name == saved,
      orElse: () => XrayLogLevel.warning,
    );
  }

  static Future<void> setLogLevel(XrayLogLevel value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_logLevelKey, value.name);
  }

  static Future<void> setFingerprint(RealityFingerprint value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_fingerprintKey, value.name);
  }

  static String? muxIncompatibility(String source) {
    final config = jsonDecode(source) as Map<String, dynamic>;
    final outbounds = (config['outbounds'] as List).whereType<Map>().map(
      (item) => Map<String, dynamic>.from(item),
    );
    final node = outbounds.firstWhere(
      (outbound) => outbound['tag'] == 'proxy',
      orElse: () => outbounds.firstWhere(
        (outbound) => const {
          'vless',
          'vmess',
          'trojan',
          'shadowsocks',
          'socks',
          'http',
          'hysteria',
          'wireguard',
        }.contains(outbound['protocol']),
      ),
    );
    final streamSettings = node['streamSettings'];
    if (streamSettings is Map &&
        streamSettings['network']?.toString().toLowerCase() == 'xhttp') {
      return 'Use XHTTP XMUX settings instead of the legacy Mux option.';
    }
    if (node['protocol'] != 'vless') return null;
    final settings = node['settings'];
    final servers = settings is Map ? settings['vnext'] : null;
    if (servers is! List) return null;
    for (final server in servers.whereType<Map>()) {
      final users = server['users'];
      if (users is! List) continue;
      if (users.whereType<Map>().any(
        (user) => user['flow'] == 'xtls-rprx-vision',
      )) {
        return 'Mux is not supported with VLESS Vision on this server.';
      }
    }
    return null;
  }

  static String _ensureDirectOutbound(List<Map<String, dynamic>> outbounds) {
    final reusable = outbounds.where(
      (outbound) =>
          outbound['tag'] == 'direct' && outbound['protocol'] == 'freedom',
    );
    if (reusable.isNotEmpty) return 'direct';

    final usedTags = outbounds
        .map((outbound) => outbound['tag'])
        .whereType<String>()
        .toSet();
    var tag = 'direct';
    var suffix = 2;
    while (usedTags.contains(tag)) {
      tag = 'direct-$suffix';
      suffix++;
    }
    outbounds.add({'tag': tag, 'protocol': 'freedom'});
    return tag;
  }

  static String _ensureBlockOutbound(List<Map<String, dynamic>> outbounds) {
    final reusable = outbounds.where(
      (outbound) =>
          outbound['tag'] == 'block' && outbound['protocol'] == 'blackhole',
    );
    if (reusable.isNotEmpty) return 'block';

    final usedTags = outbounds
        .map((outbound) => outbound['tag'])
        .whereType<String>()
        .toSet();
    var tag = 'block';
    var suffix = 2;
    while (usedTags.contains(tag)) {
      tag = 'block-$suffix';
      suffix++;
    }
    outbounds.add({'tag': tag, 'protocol': 'blackhole'});
    return tag;
  }

  static String configure(
    String source,
    RealityFingerprint fingerprint, {
    List<String> bypassDomains = const [],
    List<XrayRoutingRule> routingRules = const [],
    DnsResolver dnsResolver = DnsResolver.cloudflare,
    String? dnsServer,
    XrayLogLevel logLevel = XrayLogLevel.warning,
    XrayTcpSettings tcpSettings = const XrayTcpSettings(),
    XrayMuxSettings muxSettings = const XrayMuxSettings(),
    XrayDnsSettings? dnsSettings,
    XrayTlsSettings tlsSettings = const XrayTlsSettings(),
    XrayXhttpSettings? xhttpSettings,
    XrayPolicySettings? policySettings,
    XrayVlessEncryptionSettings? vlessEncryptionSettings,
    XraySniffingSettings? sniffingSettings,
    XrayVersionRequirement? versionRequirement,
    XrayFinalMaskSettings? finalMaskSettings,
    Map<String, dynamic> customConfigOverrides = const {},
  }) {
    tcpSettings.validate();
    muxSettings.validate();
    dnsSettings?.validate();
    tlsSettings.validate();
    xhttpSettings?.validate();
    policySettings?.validate();
    vlessEncryptionSettings?.validate();
    sniffingSettings?.validate();
    versionRequirement?.validate();
    finalMaskSettings?.validate();
    if (routingRules.length > 32) {
      throw const FormatException('Add at most 32 routing rules.');
    }
    for (final rule in routingRules) {
      rule.validate();
    }
    _validateCustomJsonValue(customConfigOverrides, r'$');
    final domains = normalizeDomains(bypassDomains);
    final config = jsonDecode(source) as Map<String, dynamic>;
    final log = Map<String, dynamic>.from(config['log'] as Map? ?? const {});
    log['loglevel'] = logLevel.name;
    config['log'] = log;
    final outbounds = (config['outbounds'] as List)
        .cast<Map<String, dynamic>>();
    final node = outbounds.firstWhere(
      (outbound) => outbound['tag'] == 'proxy',
      orElse: () => outbounds.firstWhere(
        (outbound) => const {
          'vless',
          'vmess',
          'trojan',
          'shadowsocks',
          'socks',
          'http',
          'hysteria',
          'wireguard',
        }.contains(outbound['protocol']),
      ),
    );
    if (vlessEncryptionSettings != null) {
      if (node['protocol'] != 'vless') {
        throw const FormatException(
          'VLESS Encryption can only be applied to a VLESS server.',
        );
      }
      final settings = Map<String, dynamic>.from(
        node['settings'] as Map? ?? const {},
      );
      final servers = settings['vnext'];
      if (servers is! List || servers.isEmpty) {
        throw const FormatException(
          'The VLESS server does not contain any user entries.',
        );
      }
      var changed = false;
      final updatedServers = <dynamic>[];
      for (final serverValue in servers) {
        if (serverValue is! Map) {
          updatedServers.add(serverValue);
          continue;
        }
        final server = Map<String, dynamic>.from(serverValue);
        final users = server['users'];
        if (users is List && users.isNotEmpty) {
          server['users'] = users
              .map(
                (user) => user is Map
                    ? <String, dynamic>{
                        ...Map<String, dynamic>.from(user),
                        'encryption': vlessEncryptionSettings.toXrayValue(),
                      }
                    : user,
              )
              .toList();
          changed = true;
        }
        updatedServers.add(server);
      }
      if (!changed) {
        throw const FormatException(
          'The VLESS server does not contain any user entries.',
        );
      }
      settings['vnext'] = updatedServers;
      node['settings'] = settings;
    }
    if (muxSettings.enabled) {
      final incompatibility = muxIncompatibility(source);
      if (incompatibility != null) throw FormatException(incompatibility);
    }
    final stream = node['streamSettings'];
    final configuredStream = stream is Map
        ? Map<String, dynamic>.from(stream)
        : <String, dynamic>{};
    final security = configuredStream['security'];
    if (security == 'reality') {
      final reality = Map<String, dynamic>.from(
        configuredStream['realitySettings'] as Map? ?? const {},
      );
      if (tlsSettings.clientHelloFingerprint.trim().isNotEmpty) {
        reality['fingerprint'] = tlsSettings.clientHelloFingerprint.trim();
      } else if (fingerprint != RealityFingerprint.serverDefault) {
        reality['fingerprint'] = fingerprint.value;
      }
      if (tlsSettings.serverName.trim().isNotEmpty) {
        reality['serverName'] = tlsSettings.serverName.trim();
      }
      if (tlsSettings.hasTlsOnlyOverrides) {
        throw const FormatException(
          'Advanced TLS fields require a TLS profile; Reality supports SNI and its ClientHello fingerprint.',
        );
      }
      configuredStream['realitySettings'] = reality;
    } else if (security == 'tls') {
      final tls = Map<String, dynamic>.from(
        configuredStream['tlsSettings'] as Map? ?? const {},
      );
      tls.addAll(tlsSettings.toXrayJson());
      if (tlsSettings.clientHelloFingerprint.trim().isEmpty &&
          fingerprint != RealityFingerprint.serverDefault) {
        tls['fingerprint'] = fingerprint.value;
      }
      configuredStream['tlsSettings'] = tls;
    } else if (fingerprint != RealityFingerprint.serverDefault ||
        tlsSettings.hasOverrides) {
      throw const FormatException(
        'TLS and Reality options require a TLS or Reality server profile.',
      );
    }
    final network = configuredStream['network']?.toString().toLowerCase();
    if (tcpSettings.sendThroughAddress.trim().isNotEmpty) {
      node['sendThrough'] = tcpSettings.sendThroughAddress.trim();
    }
    final supportsTcpSockopt =
        node['protocol'] != 'wireguard' &&
        node['protocol'] != 'hysteria' &&
        !const {'kcp', 'mkcp', 'quic', 'hysteria'}.contains(network);
    if (supportsTcpSockopt) {
      final sockopt = Map<String, dynamic>.from(
        configuredStream['sockopt'] as Map? ?? const {},
      );
      if (tcpSettings.happyEyeballs &&
          sockopt['dialerProxy'] is String &&
          (sockopt['dialerProxy'] as String).trim().isNotEmpty) {
        throw const FormatException(
          'Happy Eyeballs cannot be combined with an outbound dialer proxy.',
        );
      }
      sockopt.addAll(tcpSettings.toJson());
      configuredStream['sockopt'] = sockopt;
    }
    if (stream is Map || supportsTcpSockopt) {
      if (network == 'xhttp' && xhttpSettings != null) {
        configuredStream['xhttpSettings'] = xhttpSettings.applyTo(
          Map<String, dynamic>.from(
            configuredStream['xhttpSettings'] as Map? ?? const {},
          ),
        );
      }
      if (finalMaskSettings?.hasOverrides == true) {
        final finalmask = Map<String, dynamic>.from(
          configuredStream['finalmask'] as Map? ?? const {},
        );
        _mergeConfigObject(finalmask, finalMaskSettings!.toXrayJson());
        configuredStream['finalmask'] = finalmask;
      }
      node['streamSettings'] = configuredStream;
    } else if (finalMaskSettings?.hasOverrides == true) {
      node['streamSettings'] = {'finalmask': finalMaskSettings!.toXrayJson()};
    }
    node['mux'] = muxSettings.toJson();
    if (domains.isNotEmpty || routingRules.isNotEmpty) {
      final routing = Map<String, dynamic>.from(
        config['routing'] as Map? ?? const {},
      );
      final existingRules = routing['rules'];
      if (existingRules != null && existingRules is! List) {
        throw const FormatException('Xray routing rules must be a list.');
      }
      final preservedRules = existingRules is List
          ? List<dynamic>.from(existingRules)
          : const <dynamic>[];
      routing.putIfAbsent('domainStrategy', () => 'AsIs');
      if (routingRules.any((rule) => rule.ips.isNotEmpty)) {
        routing['domainStrategy'] = 'IPIfNonMatch';
      }
      final configuredRules = <Map<String, dynamic>>[];
      for (final rule in routingRules) {
        final outboundTag = switch (rule.action) {
          XrayRoutingAction.proxy => 'proxy',
          XrayRoutingAction.direct => _ensureDirectOutbound(outbounds),
          XrayRoutingAction.block => _ensureBlockOutbound(outbounds),
        };
        configuredRules.add(rule.toXrayJson(outboundTag));
      }
      if (domains.isNotEmpty) {
        final directTag = _ensureDirectOutbound(outbounds);
        configuredRules.add({
          'type': 'field',
          'domain': domains.map((domain) => 'domain:$domain').toList(),
          'outboundTag': directTag,
        });
      }
      routing['rules'] = [...configuredRules, ...preservedRules];
      config['routing'] = routing;
    }
    if (policySettings != null) {
      final policy = Map<String, dynamic>.from(
        config['policy'] as Map? ?? const {},
      );
      final levels = Map<String, dynamic>.from(
        policy['levels'] as Map? ?? const {},
      );
      final levelZero = Map<String, dynamic>.from(
        levels['0'] as Map? ?? const {},
      )..addAll(policySettings.toXrayJson());
      levels['0'] = levelZero;
      policy['levels'] = levels;
      final system = Map<String, dynamic>.from(
        policy['system'] as Map? ?? const {},
      )..addAll(policySettings.toSystemXrayJson());
      policy['system'] = system;
      config['policy'] = policy;
      config['stats'] = Map<String, dynamic>.from(
        config['stats'] as Map? ?? const {},
      );
    }
    final dns = Map<String, dynamic>.from(config['dns'] as Map? ?? const {});
    if (dnsSettings == null) {
      final dnsAddress = dnsServer == null
          ? dnsResolver == DnsResolver.custom
                ? throw const FormatException(
                    'Enter a custom IPv4 DNS address.',
                  )
                : dnsResolver.address
          : validateDnsAddress(dnsServer);
      dns['servers'] = ['tcp://$dnsAddress'];
      dns['queryStrategy'] = 'UseIPv4';
      dns['disableFallback'] = true;
    } else {
      dns['servers'] = dnsSettings.configServers;
      dns['queryStrategy'] = dnsSettings.queryStrategy.configValue;
      dns['disableCache'] = dnsSettings.disableCache;
      dns['serveStale'] = dnsSettings.serveStale;
      dns['serveExpiredTTL'] = dnsSettings.serveExpiredTtl;
      dns['disableFallback'] = dnsSettings.disableFallback;
      dns['disableFallbackIfMatch'] = dnsSettings.disableFallbackIfMatch;
      dns['enableParallelQuery'] = dnsSettings.enableParallelQuery;
      dns['useSystemHosts'] = dnsSettings.useSystemHosts;
      if (dnsSettings.clientIp.trim().isEmpty) {
        dns.remove('clientIp');
      } else {
        dns['clientIp'] = dnsSettings.clientIp.trim();
      }
      if (dnsSettings.hosts.isEmpty) {
        dns.remove('hosts');
      } else {
        dns['hosts'] = dnsSettings.hosts;
      }
    }
    final fakeDnsEnabled = dnsSettings?.fakeDns == true;
    if (sniffingSettings != null || fakeDnsEnabled) {
      for (final inbound
          in (config['inbounds'] as List? ?? const []).whereType<Map>()) {
        final mutable = inbound as Map<String, dynamic>;
        if (sniffingSettings != null) {
          mutable['sniffing'] = sniffingSettings.toXrayJson(
            forceFakeDns: fakeDnsEnabled,
          );
          continue;
        }
        final sniffing = Map<String, dynamic>.from(
          mutable['sniffing'] as Map? ?? const {},
        );
        final overrides = (sniffing['destOverride'] as List? ?? const [])
            .whereType<String>()
            .toList();
        if (!overrides.contains('fakedns')) overrides.add('fakedns');
        sniffing['enabled'] = true;
        sniffing['metadataOnly'] = false;
        sniffing['destOverride'] = overrides;
        mutable['sniffing'] = sniffing;
      }
    }
    config['dns'] = dns;
    _mergeConfigObject(config, customConfigOverrides);
    if (versionRequirement?.hasBounds == true) {
      config['version'] = versionRequirement!.toJson();
    }
    return jsonEncode(config);
  }

  /// Deep-merges object fields; array values replace the matching base array.
  /// This lets advanced users add Xray settings without a client update while
  /// preserving the imported node and app-generated defaults unless replaced.
  static void _mergeConfigObject(
    Map<String, dynamic> target,
    Map<String, dynamic> overlay,
  ) {
    for (final entry in overlay.entries) {
      final override = entry.value;
      final current = target[entry.key];
      if (override is Map) {
        final merged = current is Map
            ? Map<String, dynamic>.from(current)
            : <String, dynamic>{};
        _mergeConfigObject(merged, Map<String, dynamic>.from(override));
        target[entry.key] = merged;
      } else {
        target[entry.key] = override;
      }
    }
  }
}
