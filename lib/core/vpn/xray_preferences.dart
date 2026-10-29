import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
part 'xray_preferences_tls_dns.dart';
part 'xray_preferences_transport.dart';
part 'xray_preferences_policy_routing.dart';

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
  static const _vpnOnlyDomainsKey = 'xray.routing.vpn_only_domains.v1';
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

  /// Returns only DNS controls intended for regular VPN users. Older builds
  /// stored low-level options such as EDNS client IP and custom host overrides;
  /// those are deliberately discarded so they cannot silently affect a new
  /// connection after the settings screen has been simplified.
  static Future<XrayDnsSettings> userDnsSettings() async {
    final stored = await dnsSettings();
    const known = {
      'https://cloudflare-dns.com/dns-query',
      'https://dns.google/dns-query',
      'https://dns.quad9.net/dns-query',
    };
    const legacy = {
      'tcp://1.1.1.1': 'https://cloudflare-dns.com/dns-query',
      'tcp://8.8.8.8': 'https://dns.google/dns-query',
      'tcp://9.9.9.9': 'https://dns.quad9.net/dns-query',
    };
    final first = stored.servers.firstOrNull;
    final endpoint = first == null
        ? null
        : known.contains(first)
        ? first
        : legacy[first] ?? (isUserDnsEndpoint(first) ? first : null);
    return XrayDnsSettings(
      servers: [endpoint ?? 'https://cloudflare-dns.com/dns-query'],
      queryStrategy: stored.queryStrategy,
    );
  }

  static bool isUserDnsEndpoint(String? value) {
    final uri = Uri.tryParse(value ?? '');
    return value != null &&
        value.length <= 2048 &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment &&
        uri.path.isNotEmpty &&
        !value.contains(RegExp(r'\s')) &&
        (!uri.hasPort || uri.port > 0 && uri.port <= 65535);
  }

  /// Persists the small, validated DNS surface exposed by Oculve's UI.
  static Future<void> setUserDnsSettings(XrayDnsSettings settings) async {
    if (settings.servers.length != 1 ||
        !isUserDnsEndpoint(settings.servers.single)) {
      throw const FormatException(
        'Enter a valid HTTPS DNS URL without credentials or a fragment.',
      );
    }
    await setDnsSettings(
      XrayDnsSettings(
        servers: settings.servers,
        queryStrategy: settings.queryStrategy,
      ),
    );
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

  static Future<bool> tlsHelloFragmentationEnabled() async {
    final actual = (await finalMaskSettings()).toXrayJson();
    final tcp = actual['tcp'];
    if (actual.length != 1 ||
        tcp is! List ||
        tcp.length != 1 ||
        tcp.single is! Map) {
      return false;
    }
    final item = tcp.single as Map;
    final settings = item['settings'];
    return item['type'] == 'fragment' &&
        settings is Map &&
        settings['packets'] == 'tlshello';
  }

  static Future<Map<String, String>> fragmentRanges() async {
    final p = await SharedPreferences.getInstance();
    return {
      'length': p.getString('connection.fragment.length') ?? '100-200',
      'delay': p.getString('connection.fragment.delay') ?? '10-20',
      'splits': p.getString('connection.fragment.splits') ?? '3-6',
    };
  }

  static Future<void> setFragmentRanges({
    required String length,
    required String delay,
    required String splits,
  }) async {
    bool valid(String value, int min, int max) {
      if (!RegExp(r'^\d+(?:-\d+)?$').hasMatch(value)) return false;
      final parts = value.split('-').map(int.parse).toList();
      return parts.first >= min &&
          parts.last <= max &&
          parts.first <= parts.last;
    }

    if (!valid(length, 1, 16384) ||
        !valid(delay, 0, 1000) ||
        !valid(splits, 1, 32)) {
      throw const FormatException(
        'Enter valid numeric ranges for fragment length, delay and splits.',
      );
    }
    final enabled = await tlsHelloFragmentationEnabled();
    final p = await SharedPreferences.getInstance();
    await p.setString('connection.fragment.length', length);
    await p.setString('connection.fragment.delay', delay);
    await p.setString('connection.fragment.splits', splits);
    if (enabled) await setTlsHelloFragmentation(true);
  }

  static Future<XrayFinalMaskSettings> userFinalMaskSettings() async =>
      await tlsHelloFragmentationEnabled()
      ? await finalMaskSettings()
      : const XrayFinalMaskSettings();

  static Future<void> setTlsHelloFragmentation(bool enabled) async {
    final ranges = await fragmentRanges();
    await setFinalMaskSettings(
      enabled
          ? XrayFinalMaskSettings.fromJsonText(
              jsonEncode({
                'tcp': [
                  {
                    'type': 'fragment',
                    'settings': {
                      'packets': 'tlshello',
                      'lengths': [ranges['length']],
                      'delays': [ranges['delay']],
                      'maxSplit': ranges['splits'],
                    },
                  },
                ],
              }),
            )
          : const XrayFinalMaskSettings(),
    );
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

  static Future<bool> vpnOnlyDomainsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_vpnOnlyDomainsKey) ?? false;
  }

  static Future<void> setVpnOnlyDomainsEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_vpnOnlyDomainsKey, enabled);
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

  /// Builds the client-owned Xray session used by the DPI Bypass location.
  /// The native tunnel backend replaces the loopback placeholder with the
  /// port returned by its managed ByeDPI engine before starting Xray.
  static String configureDpiBypass({
    required int localProxyPort,
    int dpiProfile = 4,
    required XrayDnsSettings dnsSettings,
    List<String> bypassDomains = const [],
    bool vpnOnlyDomains = false,
    List<XrayRoutingRule> routingRules = const [],
  }) {
    dnsSettings.validate();
    if (dpiProfile < 0 || dpiProfile > 4) {
      throw const FormatException('Invalid DPI strategy.');
    }
    if (localProxyPort < 1 || localProxyPort > 65535) {
      throw const FormatException('Invalid local DPI proxy port.');
    }
    if (routingRules.length > 32) {
      throw const FormatException('Add at most 32 routing rules.');
    }
    for (final rule in routingRules) {
      rule.validate();
    }
    final domains = normalizeDomains(bypassDomains);
    final outbounds = <Map<String, dynamic>>[
      {
        'tag': 'byedpi',
        'protocol': 'socks',
        'settings': {
          'servers': [
            {'address': '127.0.0.1', 'port': localProxyPort},
          ],
        },
        // Resolve request hostnames with Xray's DNS settings so ByeDPI never
        // starts its own resolver that could re-enter the system tunnel.
        'targetStrategy': 'UseIP',
      },
      {'tag': 'direct', 'protocol': 'freedom'},
      {'tag': 'block', 'protocol': 'blackhole'},
    ];
    // Profile readiness must prove that the ByeDPI outbound works even when
    // user split-tunnel rules send ordinary traffic to Direct or Block.
    final rules = <Map<String, dynamic>>[
      {
        'type': 'field',
        'domain': ['full:www.gstatic.com'],
        'outboundTag': 'byedpi',
      },
      {
        'type': 'field',
        'domain': ['full:cp.cloudflare.com'],
        'outboundTag': 'byedpi',
      },
    ];
    if (vpnOnlyDomains) {
      if (domains.isNotEmpty) {
        rules.add({
          'type': 'field',
          'domain': domains.map((domain) => 'domain:$domain').toList(),
          'outboundTag': 'byedpi',
        });
        rules.add({'type': 'field', 'outboundTag': 'direct'});
      }
    } else {
      for (final rule in routingRules) {
        final outboundTag = switch (rule.action) {
          XrayRoutingAction.proxy => 'byedpi',
          XrayRoutingAction.direct => 'direct',
          XrayRoutingAction.block => 'block',
        };
        rules.add(rule.toXrayJson(outboundTag));
      }
    }
    if (domains.isNotEmpty && !vpnOnlyDomains) {
      rules.add({
        'type': 'field',
        'domain': domains.map((domain) => 'domain:$domain').toList(),
        'outboundTag': 'direct',
      });
    }
    return jsonEncode({
      'oculveDpiProfile': dpiProfile,
      'log': {
        'loglevel': 'warning',
        'access': 'none',
        'error': 'none',
        'dnsLog': false,
      },
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
      'outbounds': outbounds,
      'dns': {
        'servers': dnsSettings.configServers,
        'queryStrategy': dnsSettings.queryStrategy.configValue,
        'disableCache': dnsSettings.disableCache,
        'serveStale': dnsSettings.serveStale,
        'serveExpiredTTL': dnsSettings.serveExpiredTtl,
        'disableFallback': dnsSettings.disableFallback,
        'disableFallbackIfMatch': dnsSettings.disableFallbackIfMatch,
        'enableParallelQuery': dnsSettings.enableParallelQuery,
        'useSystemHosts': dnsSettings.useSystemHosts,
        if (dnsSettings.clientIp.trim().isNotEmpty)
          'clientIp': dnsSettings.clientIp.trim(),
        if (dnsSettings.hosts.isNotEmpty) 'hosts': dnsSettings.hosts,
      },
      'routing': {'domainStrategy': 'AsIs', 'rules': rules},
    });
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
    bool vpnOnlyDomains = false,
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
    if (domains.isNotEmpty || routingRules.isNotEmpty || vpnOnlyDomains) {
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
      if (vpnOnlyDomains) {
        if (domains.isNotEmpty) {
          configuredRules.add({
            'type': 'field',
            'domain': domains.map((domain) => 'domain:$domain').toList(),
            'outboundTag': node['tag'],
          });
          // Keep the VPN opt-in explicit: listed domains use the proxy, while
          // every other destination leaves through the physical connection.
          final directTag = _ensureDirectOutbound(outbounds);
          configuredRules.add({'type': 'field', 'outboundTag': directTag});
        }
        routing['rules'] = configuredRules;
      } else {
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
      }
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
