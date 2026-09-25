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
    if (!_expanded.add(title)) _expanded.remove(title);
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
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(3, 0, 3, 10),
                  child: Text(
                    context.tr(
                      'Most users can leave these settings as they are.',
                    ),
                    style: TextStyle(color: muted, fontSize: 11, height: 1.35),
                  ),
                ),
                if (_error != null) ...[
                  _MessageCard(
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 8),
                ],
                _GroupCard(
                  title: 'DNS & network',
                  subtitle: context.tr(
                    'Choose how names are looked up and which IP versions to use.',
                  ),
                  icon: Icons.dns_outlined,
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
                    Text(
                      context.tr('Changes apply after you reconnect.'),
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
                _GroupCard(
                  title: 'Traffic routing',
                  subtitle: context.tr(
                    'Choose which sites or Android apps bypass the VPN.',
                  ),
                  icon: Icons.alt_route_rounded,
                  expanded: _expanded.contains('Traffic routing'),
                  onToggle: () => _toggleGroup('Traffic routing'),
                  children: [
                    TextField(
                      key: const ValueKey('bypass-domains-field'),
                      controller: _bypassController,
                      minLines: 1,
                      maxLines: 4,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: context.tr('Sites outside the VPN'),
                        hintText: 'example.com\nsubdomain.example.org',
                        helperText: context.tr(
                          'Enter one domain per line. These sites bypass the VPN.',
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('save-bypass-domains'),
                        onPressed: _saving ? null : _saveBypassDomains,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text(context.tr('Save domains')),
                      ),
                    ),
                    if (Theme.of(context).platform == TargetPlatform.android)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          appRoute(const AndroidAppRoutingScreen()),
                        ),
                        icon: const Icon(Icons.apps_outlined, size: 17),
                        label: Text(context.tr('Android app routing')),
                      ),
                  ],
                ),
                _GroupCard(
                  title: 'Secure connection',
                  subtitle: context.tr(
                    'Optional connection details. The server defaults work for most people.',
                  ),
                  icon: Icons.shield_outlined,
                  expanded: _expanded.contains('Secure connection'),
                  onToggle: () => _toggleGroup('Secure connection'),
                  children: [
                    if (profile != null)
                      Text(
                        '${profile.name} · ${profile.proxyProtocol?.toUpperCase() ?? context.tr('Server')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 10),
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
                        label: context.tr('Connection fingerprint'),
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
                    Text(
                      context.tr(
                        'This changes the TLS ClientHello only. Keep the server default unless you need another profile.',
                      ),
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    if (supportsFragmentation)
                      SwitchListTile.adaptive(
                        key: const ValueKey('xray-fragmentation-switch'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.tr('Connection fragmentation')),
                        subtitle: Text(
                          context.tr(
                            'Can help on restricted networks, but may reduce speed. Use only when needed.',
                          ),
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                        value: _fragmentationEnabled,
                        onChanged: _saving ? null : _setFragmentation,
                      ),
                    if (!supportsFragmentation)
                      Text(
                        context.tr(
                          'Fragmentation is available for VLESS Reality over TCP.',
                        ),
                        style: TextStyle(color: muted, fontSize: 10),
                      ),
                  ],
                ),
                _GroupCard(
                  title: 'Diagnostics',
                  subtitle: context.tr(
                    'Choose how much connection information is recorded.',
                  ),
                  icon: Icons.receipt_long_outlined,
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
                    Text(
                      context.tr('Access and DNS query logs are disabled.'),
                      style: TextStyle(color: muted, fontSize: 10),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: FrostedCard(
      padding: EdgeInsets.zero,
      borderRadius: 14,
      child: Column(
        children: [
          ListTile(
            key: ValueKey('xray-section-$title'),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Icon(icon, size: 18),
            title: Text(
              context.tr(title),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, height: 1.2),
            ),
            trailing: Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20,
            ),
            onTap: onToggle,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 9),
                  ...children.map(
                    (child) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
    final muted = dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 5,
          runSpacing: 3,
          children: [
            for (final option in values)
              ChoiceChip(
                key: ValueKey('xray-choice-$label-${valueLabel(option)}'),
                label: Text(
                  valueLabel(option),
                  style: TextStyle(
                    color: foreground,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: option == value,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                pressElevation: 0,
                side: BorderSide(
                  color: muted.withValues(alpha: option == value ? .42 : .18),
                ),
                selectedColor: dark
                    ? Colors.white.withValues(alpha: .10)
                    : Colors.black.withValues(alpha: .07),
                backgroundColor: dark
                    ? Colors.white.withValues(alpha: .025)
                    : Colors.black.withValues(alpha: .02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    borderRadius: 12,
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppTheme.errorColor,
          size: 17,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.errorColor, fontSize: 10),
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
