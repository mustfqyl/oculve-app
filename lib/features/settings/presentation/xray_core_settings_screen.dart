import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'android_app_routing_screen.dart';

class XrayCoreSettingsScreen extends ConsumerStatefulWidget {
  const XrayCoreSettingsScreen({super.key});

  @override
  ConsumerState<XrayCoreSettingsScreen> createState() =>
      _XrayCoreSettingsScreenState();
}

class _XrayCoreSettingsScreenState
    extends ConsumerState<XrayCoreSettingsScreen> {
  final _bypassController = TextEditingController();
  final _expanded = <String>{};
  XrayDnsSettings? _dns;
  RealityFingerprint? _fingerprint;
  XrayLogLevel? _logLevel;
  bool _fragmentationEnabled = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _dnsPresets = <String, String>{
    'Cloudflare': 'https://cloudflare-dns.com/dns-query',
    'Google': 'https://dns.google/dns-query',
    'Quad9': 'https://dns.quad9.net/dns-query',
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bypassController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object>([
        XrayPreferences.fingerprint(),
        XrayPreferences.userDnsSettings(),
        XrayPreferences.bypassDomains(),
        XrayPreferences.logLevel(),
        XrayPreferences.tlsHelloFragmentationEnabled(),
      ]);
      if (!mounted) return;
      setState(() {
        _fingerprint = values[0] as RealityFingerprint;
        _dns = values[1] as XrayDnsSettings;
        _bypassController.text = (values[2] as List<String>).join('\n');
        final level = values[3] as XrayLogLevel;
        _logLevel =
            const {
              XrayLogLevel.error,
              XrayLogLevel.warning,
              XrayLogLevel.info,
            }.contains(level)
            ? level
            : XrayLogLevel.warning;
        _fragmentationEnabled = values[4] as bool;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _fingerprint = RealityFingerprint.serverDefault;
          _dns = const XrayDnsSettings(
            servers: ['https://cloudflare-dns.com/dns-query'],
            queryStrategy: DnsQueryStrategy.useSystem,
          );
          _logLevel = XrayLogLevel.warning;
          _bypassController.clear();
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _saveDns({
    String? server,
    DnsQueryStrategy? queryStrategy,
  }) async {
    final current = _dns;
    if (current == null || _saving) return;
    setState(() => _saving = true);
    try {
      final next = current.copyWith(
        servers: server == null ? current.servers : [server],
        queryStrategy: queryStrategy ?? current.queryStrategy,
      );
      await XrayPreferences.setUserDnsSettings(next);
      if (mounted) {
        setState(() {
          _dns = next;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveFingerprint(RealityFingerprint value) async {
    try {
      await XrayPreferences.setFingerprint(value);
      if (mounted) {
        setState(() {
          _fingerprint = value;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _saveBypassDomains() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await XrayPreferences.setBypassDomains(
        _bypassController.text.split(RegExp(r'[,\n]')),
      );
      final saved = await XrayPreferences.bypassDomains();
      if (mounted) {
        setState(() {
          _bypassController.text = saved.join('\n');
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveLogLevel(XrayLogLevel value) async {
    try {
      await XrayPreferences.setLogLevel(value);
      if (mounted) {
        setState(() {
          _logLevel = value;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _setFragmentation(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await XrayPreferences.setTlsHelloFragmentation(enabled);
      if (mounted) {
        setState(() {
          _fragmentationEnabled = enabled;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleGroup(String title) => setState(() {
    if (_expanded.contains(title)) {
      _expanded.clear();
    } else {
      _expanded
        ..clear()
        ..add(title);
    }
  });

  String _selectedDnsServer(XrayDnsSettings settings) {
    final saved = settings.servers.firstOrNull;
    return _dnsPresets.values.contains(saved)
        ? saved!
        : _dnsPresets.values.first;
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(sessionProvider).valueOrNull?.profiles ?? [];
    final selected = ref.watch(selectedServerProvider);
    final profile =
        profiles.where((item) => item.id == selected).firstOrNull ??
        profiles.firstOrNull;
    final supportsFingerprint = profile?.supportsTlsFingerprint ?? false;
    final supportsFragmentation = selected == optimalServerId
        ? profiles.isNotEmpty &&
              profiles.every((item) => item.supportsTlsHelloFragmentation)
        : profile?.supportsTlsHelloFragmentation ?? false;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;

    return AppPage(
      title: context.tr('Connection settings'),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr(
                            'Most users can leave these settings as they are.',
                          ),
                          style: TextStyle(
                            color: muted,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  _MessageCard(
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 10),
                ],
                _GroupCard(
                  title: 'DNS & network',
                  subtitle: context.tr(
                    'Choose an encrypted DNS provider and lookup address family.',
                  ),
                  icon: Icons.dns_rounded,
                  expanded: _expanded.contains('DNS & network'),
                  onToggle: () => _toggleGroup('DNS & network'),
                  children: [
                    _OptionRow<String>(
                      label: context.tr('DNS provider'),
                      value: _selectedDnsServer(_dns!),
                      values: _dnsPresets.values.toList(),
                      valueLabel: (server) => _dnsPresets.entries
                          .firstWhere((entry) => entry.value == server)
                          .key,
                      onSelected: (server) => _saveDns(server: server),
                    ),
                    const SizedBox(height: 4),
                    _OptionRow<DnsQueryStrategy>(
                      label: context.tr('DNS address family'),
                      value: _dns!.queryStrategy,
                      values: DnsQueryStrategy.values,
                      valueLabel: (strategy) => context.tr(switch (strategy) {
                        DnsQueryStrategy.useSystem => 'Automatic',
                        DnsQueryStrategy.useIP => 'IPv4 + IPv6',
                        DnsQueryStrategy.useIPv4 => 'IPv4 only',
                        DnsQueryStrategy.useIPv6 => 'IPv6 only',
                      }),
                      onSelected: (strategy) =>
                          _saveDns(queryStrategy: strategy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('Changes apply after you reconnect.'),
                      style: TextStyle(color: muted, fontSize: 10.5),
                    ),
                  ],
                ),
                _GroupCard(
                  title: 'Split tunneling',
                  subtitle: context.tr(
                    'Choose which sites or Android apps bypass the VPN.',
                  ),
                  icon: Icons.alt_route_rounded,
                  expanded: _expanded.contains('Split tunneling'),
                  onToggle: () => _toggleGroup('Split tunneling'),
                  children: [
                    TextField(
                      key: const ValueKey('bypass-domains-field'),
                      controller: _bypassController,
                      minLines: 1,
                      maxLines: 4,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        labelText: context.tr('Sites outside the VPN'),
                        hintText: 'example.com\nsubdomain.example.org',
                        helperText: context.tr(
                          'Enter one domain per line. These sites bypass the VPN.',
                        ),
                        helperMaxLines: 2,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('save-bypass-domains'),
                        onPressed: _saving ? null : _saveBypassDomains,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 15),
                        label: Text(
                          context.tr('Save domains'),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                    if (Theme.of(context).platform ==
                        TargetPlatform.android) ...[
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          appRoute(const AndroidAppRoutingScreen()),
                        ),
                        icon: const Icon(Icons.apps_rounded, size: 16),
                        label: Text(context.tr('Android app routing')),
                      ),
                    ],
                  ],
                ),
                _GroupCard(
                  title: 'Transport & TLS',
                  subtitle: context.tr(
                    'Optional connection details. The server defaults work for most people.',
                  ),
                  icon: Icons.security_rounded,
                  expanded: _expanded.contains('Transport & TLS'),
                  onToggle: () => _toggleGroup('Transport & TLS'),
                  children: [
                    if (profile != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${profile.name} · ${profile.proxyProtocol?.toUpperCase() ?? context.tr('Server')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (!supportsFingerprint)
                      Text(
                        context.tr(
                          'The selected server does not use TLS or Reality.',
                        ),
                        style: TextStyle(color: muted, fontSize: 11),
                      )
                    else
                      _OptionRow<RealityFingerprint>(
                        label: context.tr('TLS identity'),
                        value: _fingerprint!,
                        values: const [
                          RealityFingerprint.serverDefault,
                          RealityFingerprint.chrome,
                          RealityFingerprint.firefox,
                          RealityFingerprint.safari,
                        ],
                        valueLabel: (value) => context.tr(value.label),
                        onSelected: _saveFingerprint,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                        'This changes the TLS ClientHello only. Keep the server default unless you need another profile.',
                      ),
                      style: TextStyle(color: muted, fontSize: 10.5),
                    ),
                    const SizedBox(height: 6),
                    if (supportsFragmentation)
                      SwitchListTile.adaptive(
                        key: const ValueKey('xray-fragmentation-switch'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          context.tr('Connection fragmentation'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          context.tr(
                            'Can help on restricted networks, but may reduce speed. Use only when needed.',
                          ),
                          style: TextStyle(color: muted, fontSize: 10.5),
                        ),
                        value: _fragmentationEnabled,
                        onChanged: _saving ? null : _setFragmentation,
                      ),
                    if (!supportsFragmentation)
                      Text(
                        context.tr(
                          'Fragmentation is available for VLESS Reality over TCP.',
                        ),
                        style: TextStyle(color: muted, fontSize: 10.5),
                      ),
                  ],
                ),
                _GroupCard(
                  title: 'Diagnostics',
                  subtitle: context.tr(
                    'Choose how much connection information is recorded.',
                  ),
                  icon: Icons.receipt_long_rounded,
                  expanded: _expanded.contains('Diagnostics'),
                  onToggle: () => _toggleGroup('Diagnostics'),
                  children: [
                    _OptionRow<XrayLogLevel>(
                      label: context.tr('Diagnostic detail'),
                      value: _logLevel!,
                      values: const [
                        XrayLogLevel.error,
                        XrayLogLevel.warning,
                        XrayLogLevel.info,
                      ],
                      valueLabel: (level) => context.tr(level.label),
                      onSelected: _saveLogLevel,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('Access and DNS query logs are disabled.'),
                      style: TextStyle(color: muted, fontSize: 10.5),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppTheme.foreground : AppTheme.lightForeground;
    final muted = dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FrostedCard(
        padding: EdgeInsets.zero,
        borderRadius: 14,
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: ValueKey('xray-section-$title'),
                borderRadius: BorderRadius.circular(14),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: dark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                        child: Center(child: Icon(icon, size: 17, color: fg)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(title),
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeBody,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeCaption,
                                height: 1.25,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(
                      height: 1,
                      thickness: 0.8,
                      color: dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                    const SizedBox(height: 10),
                    ...children.map(
                      (child) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.value,
    required this.values,
    required this.valueLabel,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) valueLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? AppTheme.foreground : AppTheme.lightForeground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: [
            for (final option in values)
              ChoiceChip(
                key: ValueKey('xray-choice-$label-${valueLabel(option)}'),
                label: Text(
                  valueLabel(option),
                  style: TextStyle(
                    color: option == value ? AppTheme.successColor : foreground,
                    fontSize: 10,
                    fontWeight: option == value
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                selected: option == value,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                pressElevation: 0,
                side: BorderSide(
                  color: option == value
                      ? AppTheme.successColor.withValues(alpha: .5)
                      : (dark
                            ? Colors.white.withValues(alpha: .08)
                            : Colors.black.withValues(alpha: .07)),
                ),
                selectedColor: AppTheme.successColor.withValues(
                  alpha: dark ? .15 : .12,
                ),
                backgroundColor: dark
                    ? Colors.white.withValues(alpha: .03)
                    : Colors.black.withValues(alpha: .02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (selected) {
                  if (selected) onSelected(option);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => FrostedCard(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    borderRadius: 12,
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppTheme.errorColor,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.errorColor, fontSize: 11),
          ),
        ),
        IconButton(
          onPressed: onDismiss,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close_rounded, size: 15),
        ),
      ],
    ),
  );
}
