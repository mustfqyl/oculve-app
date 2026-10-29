part of 'xray_preferences.dart';

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
