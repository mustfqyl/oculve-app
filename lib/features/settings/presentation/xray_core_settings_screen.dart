import 'package:oculve/core/connection/dpi_preferences.dart';
import 'dpi_settings.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/connection/connection_preferences.dart';
import 'package:oculve/core/connection/lan_proxy_service.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/inline_feedback.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'connection_settings_widgets.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'android_app_routing_screen.dart';
import 'client_logs_screen.dart';
import 'lan_sharing_screen.dart';
import 'startup_setting.dart';

class XrayCoreSettingsScreen extends ConsumerStatefulWidget {
  const XrayCoreSettingsScreen({super.key});
  @override
  ConsumerState<XrayCoreSettingsScreen> createState() =>
      _XrayCoreSettingsScreenState();
}

class _XrayCoreSettingsScreenState
    extends ConsumerState<XrayCoreSettingsScreen> {
  static const _presets = {
    'Cloudflare': 'https://cloudflare-dns.com/dns-query',
    'Google': 'https://dns.google/dns-query',
    'Quad9': 'https://dns.quad9.net/dns-query',
  };
  final _custom = TextEditingController();
  Timer? _customSaveTimer;
  int _customRevision = 0;
  bool _customDirty = false;
  Future<void> _customWrites = Future.value();
  XrayDnsSettings? _dns;
  XrayLogLevel _log = XrayLogLevel.warning;
  ConnectionPreferences _options = const ConnectionPreferences();
  List<String> _domains = [];
  int _dpiResetEpoch = 0;
  bool _fragment = false, _customMode = false, _busy = false;
  String? _customError;
  // One failure line per group, shown in place of that group's heading.
  final _dnsErrors = InlineErrorController();
  final _connectionErrors = InlineErrorController();
  final _dpiErrors = InlineErrorController();
  final _diagErrors = InlineErrorController();
  final _restoreErrors = InlineErrorController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customSaveTimer?.cancel();
    if (_customDirty &&
        _customMode &&
        _dns != null &&
        XrayPreferences.isUserDnsEndpoint(
          XrayPreferences.normalizeUserDnsInput(_custom.text),
        )) {
      unawaited(
        _persistCustomDns(
          _dns!.copyWith(
            servers: [XrayPreferences.normalizeUserDnsInput(_custom.text)],
          ),
        ).catchError((Object _) {}),
      );
    }
    _custom.dispose();
    for (final controller in [
      _dnsErrors,
      _connectionErrors,
      _dpiErrors,
      _diagErrors,
      _restoreErrors,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dns = await XrayPreferences.userDnsSettings();
      final domains = await XrayPreferences.bypassDomains();
      final log = await XrayPreferences.logLevel();
      final fragment = await XrayPreferences.tlsHelloFragmentationEnabled();
      final options = await ConnectionPreferences.read();
      if (!mounted) return;
      setState(() {
        _dns = dns;
        _domains = domains;
        _log =
            [
              XrayLogLevel.error,
              XrayLogLevel.warning,
              XrayLogLevel.info,
            ].contains(log)
            ? log
            : XrayLogLevel.warning;
        _fragment = fragment;
        _options = options;
        _customMode = !_presets.containsValue(dns.servers.single);
        _custom.text = _customMode ? dns.servers.single : '';
        _customError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _dns = const XrayDnsSettings(
          servers: ['https://cloudflare-dns.com/dns-query'],
          queryStrategy: DnsQueryStrategy.useSystem,
        ),
      );
      _dnsErrors.show(error, fallback: 'Could not load connection settings.');
    }
  }

  Future<bool> _saveDns(Future<void> Function() action) =>
      _saveIn(_dnsErrors, action);
  Future<bool> _saveConnection(Future<void> Function() action) =>
      _saveIn(_connectionErrors, action);
  Future<bool> _saveDiag(Future<void> Function() action) =>
      _saveIn(_diagErrors, action);
  Future<bool> _saveRestore(Future<void> Function() action) =>
      _saveIn(_restoreErrors, action);

  /// Runs [action]; a failure is shown by [errors], next to the group that
  /// owns the setting, instead of in a banner.
  Future<bool> _saveIn(
    InlineErrorController errors,
    Future<void> Function() action,
  ) async {
    if (_busy) return false;
    errors.clear();
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) {
        errors.show(
          error,
          fallback:
              'Could not save connection settings. Check your input and try again.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _queueCustomDns(String value) {
    _customSaveTimer?.cancel();
    _customDirty = true;
    final revision = ++_customRevision;
    _customSaveTimer = Timer(
      const Duration(milliseconds: 400),
      () => _commitCustomDns(revision),
    );
  }

  /// Autosaves a valid custom endpoint. An invalid one is never written: the
  /// previously saved value stays active and the field shows a calm hint.
  Future<void> _commitCustomDns(int revision) async {
    if (!mounted ||
        !_customMode ||
        revision != _customRevision ||
        _dns == null) {
      return;
    }
    final typed = _custom.text.trim();
    final endpoint = XrayPreferences.normalizeUserDnsInput(typed);
    if (!XrayPreferences.isUserDnsEndpoint(endpoint)) {
      _setCustomError(
        typed.isEmpty
            ? null
            : context.tr(
                'Enter a DNS address, such as dns.adguard.com or 94.140.14.14.',
              ),
      );
      return;
    }
    _setCustomError(null);
    if (_busy) {
      _customSaveTimer = Timer(
        const Duration(milliseconds: 100),
        () => _commitCustomDns(revision),
      );
      return;
    }
    await _saveDns(() async {
      final next = _dns!.copyWith(servers: [endpoint]);
      await _persistCustomDns(next);
      if (mounted && revision == _customRevision && _customMode) {
        _customDirty = false;
        setState(() => _dns = next);
      }
    });
  }

  void _setCustomError(String? message) {
    if (!mounted || message == _customError) return;
    setState(() => _customError = message);
  }

  Future<void> _persistCustomDns(XrayDnsSettings next) {
    _customWrites = _customWrites
        .catchError((Object _) {})
        .then((_) => XrayPreferences.setUserDnsSettings(next));
    return _customWrites;
  }

  Future<void> _provider() async {
    _customSaveTimer?.cancel();
    _customRevision++;
    _customDirty = false;
    final selected = _customMode
        ? 'Custom'
        : _presets.entries
              .firstWhere((entry) => entry.value == _dns!.servers.single)
              .key;
    final providers = [..._presets.keys, 'Custom'];
    final value =
        providers[(providers.indexOf(selected) + 1) % providers.length];
    if (value == 'Custom') {
      setState(() {
        _customMode = true;
        _customError = null;
      });
      _queueCustomDns(_custom.text);
      return;
    }
    await _saveDns(() async {
      await _customWrites.catchError((Object _) {});
      final next = _dns!.copyWith(servers: [_presets[value]!]);
      await XrayPreferences.setUserDnsSettings(next);
      if (mounted) {
        setState(() {
          _dns = next;
          _customMode = false;
          _customError = null;
        });
      }
    });
  }

  static String _strategy(DnsQueryStrategy value) => switch (value) {
    DnsQueryStrategy.useSystem => 'Network-aware',
    DnsQueryStrategy.useIP => 'IPv4 + IPv6',
    DnsQueryStrategy.useIPv4 => 'IPv4 only',
    DnsQueryStrategy.useIPv6 => 'IPv6 only',
  };
  Future<void> _queryMode() async {
    final modes = DnsQueryStrategy.values;
    final value =
        modes[(modes.indexOf(_dns!.queryStrategy) + 1) % modes.length];
    await _saveDns(() async {
      final next = _dns!.copyWith(queryStrategy: value);
      await XrayPreferences.setUserDnsSettings(next);
      if (mounted) setState(() => _dns = next);
    });
  }

  Future<void> _protection() async {
    bool armed = false;
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.macOS) {
      try {
        armed =
            (await const MethodChannel(
              'flutter_vless',
            ).invokeMapMethod<String, dynamic>(
              'getTrafficProtection',
            ))?['armed'] ==
            true;
      } catch (_) {}
    }
    if (!mounted) return;
    final explanation = switch (platform) {
      TargetPlatform.macOS =>
        '${context.tr(armed ? 'System protection is armed.' : 'System protection activates when you connect.')}\n\n${context.tr('Traffic protection stays enabled during tunnel recovery. Disconnecting manually ends the VPN session and its protection. Certain essential system traffic is exempted by macOS.')}',
      TargetPlatform.windows => context.tr(
        'Windows installs system traffic protection before the VPN starts. It stays active during tunnel recovery and ends when you disconnect.',
      ),
      TargetPlatform.linux => context.tr(
        'Linux installs a firewall guard before VPN routing starts. It stays active during recovery and is removed when you stop the VPN.',
      ),
      _ => context.tr(
        'Traffic protection depends on your platform. System-level verification is required before this feature can be enabled.',
      ),
    };
    await showDialog<void>(
      context: context,
      builder: (context) => SettingsModal(
        title: const Text('Kill switch'),
        content: SingleChildScrollView(child: Text(explanation)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<bool> _reset() async {
    _customSaveTimer?.cancel();
    _customRevision++;
    _customDirty = false;
    return _saveRestore(() async {
      await _customWrites.catchError((Object _) {});
      await XrayPreferences.setUserDnsSettings(
        const XrayDnsSettings(
          servers: ['https://cloudflare-dns.com/dns-query'],
          queryStrategy: DnsQueryStrategy.useSystem,
        ),
      );
      await XrayPreferences.setBypassDomains([]);
      await XrayPreferences.setVpnOnlyDomainsEnabled(false);
      await XrayPreferences.setTlsHelloFragmentation(false);
      await XrayPreferences.setFragmentRanges(
        length: '100-200',
        delay: '10-20',
        splits: '3-6',
      );
      await XrayPreferences.setLogLevel(XrayLogLevel.warning);
      await ConnectionPreferences.setReconnect(true);
      await DpiPreferences.save(DpiStrategy.automatic);
      _dpiResetEpoch++;
      await ConnectionPreferences.disableLan();
      await ref.read(lanProxyProvider).stop();
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(sessionProvider).valueOrNull?.profiles ?? [];
    final selected = ref.watch(selectedServerProvider);
    final profile =
        profiles.where((p) => p.id == selected).firstOrNull ??
        profiles.firstOrNull;
    final supportsFragment = selected == optimalServerId
        ? profiles.isNotEmpty &&
              profiles.every((p) => p.supportsTlsHelloFragmentation)
        : profile?.supportsTlsHelloFragmentation ?? false;
    final service = ref.watch(lanProxyProvider);
    return AppPage(
      title: 'Connection Settings',
      child: _dns == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                SettingsCaption('DNS', errors: _dnsErrors),
                SettingsGroup(
                  children: [
                    SettingsCycleRow(
                      key: const ValueKey('dns-provider-row'),
                      options: const [
                        'Cloudflare',
                        'Google',
                        'Quad9',
                        'Custom',
                      ],
                      title: 'Provider',
                      label: _customMode
                          ? 'Custom'
                          : _presets.entries
                                .firstWhere(
                                  (entry) =>
                                      entry.value == _dns!.servers.single,
                                  orElse: () => const MapEntry('Custom', ''),
                                )
                                .key,
                      onTap: _busy ? null : _provider,
                    ),
                    if (_customMode)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              key: const ValueKey('custom-dns-field'),
                              controller: _custom,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.done,
                              autocorrect: false,
                              enableSuggestions: false,
                              style: const TextStyle(fontSize: 12),
                              onChanged: _queueCustomDns,
                              onSubmitted: (_) {
                                _customSaveTimer?.cancel();
                                _commitCustomDns(_customRevision);
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                hintText: 'https://dns.example.net/dns-query',
                                hintStyle: TextStyle(
                                  fontSize: 11,
                                  color: settingsMuted(context),
                                ),
                                errorText: _customError,
                                errorMaxLines: 3,
                                errorStyle: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.35,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!Platform.isMacOS)
                      SettingsCycleRow(
                        key: const ValueKey('dns-strategy-row'),
                        title: 'IP lookup',
                        label: _strategy(_dns!.queryStrategy),
                        options: [
                          for (final mode in DnsQueryStrategy.values)
                            _strategy(mode),
                        ],
                        onTap: _busy ? null : _queryMode,
                      )
                    else
                      SettingRow(
                        key: const ValueKey('dns-strategy-row'),
                        title: 'IP lookup',
                        value: _strategy(
                          Platform.isMacOS
                              ? DnsQueryStrategy.useIPv4
                              : _dns!.queryStrategy,
                        ),
                        subtitle: Platform.isMacOS
                            ? 'macOS tunnel uses IPv4.'
                            : null,
                        onTap: _busy || Platform.isMacOS ? null : _queryMode,
                      ),
                  ],
                ),
                const SettingsCaption('SPLIT TUNNELING'),
                SettingsGroup(
                  children: [
                    SettingRow(
                      key: const ValueKey('split-tunneling-domains-row'),
                      title: 'Domain routing',
                      subtitle: _domains.isEmpty
                          ? 'Choose domains for VPN routing.'
                          : '${_domains.length} ${context.tr('domains')}',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          appRoute(const SplitTunnelingScreen()),
                        );
                        await _load();
                      },
                    ),
                    if (Platform.isAndroid)
                      SettingRow(
                        title: 'Android app routing',
                        onTap: () => Navigator.push(
                          context,
                          appRoute(const AndroidAppRoutingScreen()),
                        ),
                      ),
                  ],
                ),
                SettingsCaption('CONNECTION', errors: _connectionErrors),
                SettingsGroup(
                  children: [
                    SettingRow(
                      title: 'Automatic reconnect',
                      subtitle:
                          'Retry interrupted sessions. Manual Disconnect cancels retries.',
                      trailing: Switch(
                        activeTrackColor: AppTheme.successForeground(
                          isDark:
                              Theme.of(context).brightness == Brightness.dark,
                        ),
                        activeThumbColor: Colors.white,
                        value: _options.reconnect,
                        overlayColor: quietOverlay(context),
                        onChanged: _busy
                            ? null
                            : (value) => _saveConnection(() async {
                                await ConnectionPreferences.setReconnect(value);
                                final next = await ConnectionPreferences.read();
                                if (mounted) setState(() => _options = next);
                              }),
                      ),
                    ),
                    if (Platform.isMacOS ||
                        Platform.isWindows ||
                        Platform.isLinux)
                      StartupSetting(errors: _connectionErrors),
                    SettingRow(
                      title: 'Kill switch',
                      value: switch (Theme.of(context).platform) {
                        TargetPlatform.macOS ||
                        TargetPlatform.windows ||
                        TargetPlatform.linux => 'System-managed',
                        _ => 'Platform dependent',
                      },
                      onTap: _protection,
                    ),
                    SettingRow(
                      title: 'TLS fragmentation',
                      subtitle: supportsFragment
                          ? 'For compatible connections'
                          : 'Available for VLESS Reality over TCP.',
                      trailing: Switch(
                        activeTrackColor: AppTheme.successForeground(
                          isDark:
                              Theme.of(context).brightness == Brightness.dark,
                        ),
                        activeThumbColor: Colors.white,
                        key: const ValueKey('xray-fragmentation-switch'),
                        value: _fragment,
                        overlayColor: quietOverlay(context),
                        onChanged: _busy || !supportsFragment
                            ? null
                            : (value) => _saveConnection(() async {
                                await XrayPreferences.setTlsHelloFragmentation(
                                  value,
                                );
                                if (mounted) setState(() => _fragment = value);
                              }),
                      ),
                    ),
                    if (supportsFragment && _fragment)
                      SettingRow(
                        title: 'Fragmentation settings',
                        onTap: () => Navigator.push(
                          context,
                          appRoute(const FragmentationSettingsScreen()),
                        ),
                      ),
                  ],
                ),
                SettingsCaption('DPI BYPASS', errors: _dpiErrors),
                DpiSettings(key: ValueKey(_dpiResetEpoch), errors: _dpiErrors),
                if (Platform.isMacOS) ...[
                  const SettingsCaption('LOCAL NETWORK'),
                  SettingsGroup(
                    children: [
                      SettingRow(
                        title: 'LAN proxy sharing',
                        value: service.running
                            ? 'Active'
                            : _options.shareLan
                            ? 'Ready after reconnect'
                            : 'Off',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            appRoute(const LanSharingScreen()),
                          );
                          await _load();
                        },
                      ),
                    ],
                  ),
                ],
                SettingsCaption('DIAGNOSTICS', errors: _diagErrors),
                SettingsGroup(
                  children: [
                    SettingsCycleRow(
                      options: const ['Errors', 'Warnings', 'Detailed'],
                      title: 'Diagnostic detail',
                      label: switch (_log) {
                        XrayLogLevel.error => 'Errors',
                        XrayLogLevel.info => 'Detailed',
                        _ => 'Warnings',
                      },
                      onTap: _busy
                          ? null
                          : () async {
                              const levels = [
                                XrayLogLevel.error,
                                XrayLogLevel.warning,
                                XrayLogLevel.info,
                              ];
                              final level =
                                  levels[(levels.indexOf(_log) + 1) %
                                      levels.length];
                              if (mounted) {
                                await _saveDiag(() async {
                                  await XrayPreferences.setLogLevel(level);
                                  if (mounted) setState(() => _log = level);
                                });
                              }
                            },
                    ),
                    SettingRow(
                      title: 'Troubleshooting report',
                      subtitle: 'Export without account codes or credentials.',
                      onTap: () => Navigator.push(
                        context,
                        appRoute(const ClientLogsScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsRestoreButton(enabled: !_busy, onRestore: _reset),
                InlineErrorOf(_restoreErrors, height: 28),
              ],
            ),
    );
  }
}

class SplitTunnelingScreen extends StatefulWidget {
  const SplitTunnelingScreen({super.key});
  @override
  State<SplitTunnelingScreen> createState() => _SplitTunnelingScreenState();
}

class _SplitTunnelingScreenState extends State<SplitTunnelingScreen> {
  final _input = TextEditingController();
  List<String> _domains = [];
  bool _vpnOnlyDomains = false;
  bool _busy = false;
  final _modeErrors = InlineErrorController();
  final _domainErrors = InlineErrorController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final domains = await XrayPreferences.bypassDomains();
    final vpnOnlyDomains = await XrayPreferences.vpnOnlyDomainsEnabled();
    if (mounted) {
      setState(() {
        _domains = domains;
        _vpnOnlyDomains = vpnOnlyDomains;
      });
    }
  }

  Future<void> _toggleMode() async {
    if (_busy) return;
    _modeErrors.clear();
    final next = !_vpnOnlyDomains;
    setState(() => _busy = true);
    try {
      await XrayPreferences.setVpnOnlyDomainsEnabled(next);
      if (mounted) setState(() => _vpnOnlyDomains = next);
    } catch (error) {
      if (mounted) {
        _modeErrors.show(error, fallback: 'Could not save settings.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(List<String> domains) async {
    if (_busy) return;
    _domainErrors.clear();
    setState(() => _busy = true);
    try {
      await XrayPreferences.setBypassDomains(domains);
      await _load();
      _input.clear();
    } catch (error) {
      if (mounted) {
        _domainErrors.show(
          error,
          fallback: 'Enter valid website domains, such as example.com.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _modeErrors.dispose();
    _domainErrors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Split tunneling',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsGroup(
          children: [
            SettingsCycleRow(
              key: const ValueKey('split-tunneling-mode-row'),
              title: 'Route domains',
              label: context.tr(
                _vpnOnlyDomains ? 'Only selected' : 'Except selected',
              ),
              options: [
                context.tr('Except selected'),
                context.tr('Only selected'),
              ],
              onTap: _busy ? null : _toggleMode,
            ),
          ],
        ),
        // The failure of the mode switch above fades in here.
        InlineErrorOf(_modeErrors, height: 28),
        TextField(
          key: const ValueKey('bypass-domains-field'),
          controller: _input,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: context.tr('Domain'),
            hintText: 'example.com',
          ),
          onSubmitted: _busy ? null : (_) => _save([..._domains, _input.text]),
        ),
        // The failure of saving a domain fades in here.
        InlineErrorOf(_domainErrors, height: 28),
        if (_domains.isNotEmpty)
          SettingsGroup(
            children: [
              for (final domain in _domains)
                SettingRow(
                  title: domain,
                  trailing: Semantics(
                    label: 'Remove $domain',
                    child: IconButton(
                      style: IconButton.styleFrom().copyWith(
                        overlayColor: quietOverlay(context),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _save(
                              _domains.where((d) => d != domain).toList(),
                            ),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                    ),
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

class FragmentationSettingsScreen extends StatefulWidget {
  const FragmentationSettingsScreen({super.key});
  @override
  State<FragmentationSettingsScreen> createState() =>
      _FragmentationSettingsScreenState();
}

class _FragmentationSettingsScreenState
    extends State<FragmentationSettingsScreen> {
  final _length = TextEditingController(),
      _delay = TextEditingController(),
      _splits = TextEditingController();
  Timer? _saveTimer;
  int _saveRevision = 0;
  String? _validationError;
  Future<void> _writes = Future.value();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ranges = await XrayPreferences.fragmentRanges();
    if (mounted) {
      setState(() {
        _length.text = ranges['length']!;
        _delay.text = ranges['delay']!;
        _splits.text = ranges['splits']!;
      });
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_writes.catchError((Object _) {}));
    _length.dispose();
    _delay.dispose();
    _splits.dispose();
    super.dispose();
  }

  void _queueSave() {
    _saveTimer?.cancel();
    final revision = ++_saveRevision;
    _saveTimer = Timer(
      const Duration(milliseconds: 450),
      () => _save(revision),
    );
  }

  void _saveNow() {
    _saveTimer?.cancel();
    _save(++_saveRevision);
  }

  Future<void> _save(int revision) async {
    if (!mounted) return;
    final length = _length.text.trim();
    final delay = _delay.text.trim();
    final splits = _splits.text.trim();
    try {
      _writes = _writes
          .catchError((Object _) {})
          .then(
            (_) => XrayPreferences.setFragmentRanges(
              length: length,
              delay: delay,
              splits: splits,
            ),
          );
      await _writes;
      if (mounted && revision == _saveRevision) {
        setState(() => _validationError = null);
      }
    } catch (error) {
      if (mounted && revision == _saveRevision) {
        setState(
          () => _validationError = context.tr(
            'Enter valid numeric ranges for fragment length, delay and splits.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Fragmentation settings',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Only the TLS hello is fragmented. Settings save automatically; reconnect to apply. Smaller fragments or longer delays may reduce speed.',
          style: TextStyle(color: settingsMuted(context), fontSize: 12),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('fragment-length-field'),
          controller: _length,
          onChanged: (_) => _queueSave(),
          onSubmitted: (_) => _saveNow(),
          decoration: InputDecoration(
            labelText: context.tr('Fragment length (bytes)'),
            helperText: context.tr('1–16384, for example 100-200'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('fragment-delay-field'),
          controller: _delay,
          onChanged: (_) => _queueSave(),
          onSubmitted: (_) => _saveNow(),
          decoration: InputDecoration(
            labelText: context.tr('Delay (milliseconds)'),
            helperText: context.tr('0–1000, for example 10-20'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('fragment-splits-field'),
          controller: _splits,
          onChanged: (_) => _queueSave(),
          onSubmitted: (_) => _saveNow(),
          decoration: InputDecoration(
            labelText: context.tr('Maximum splits'),
            helperText: context.tr('1–32, for example 3-6'),
          ),
        ),
        if (_validationError != null) ...[
          const SizedBox(height: 12),
          Text(
            _validationError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
  );
}
