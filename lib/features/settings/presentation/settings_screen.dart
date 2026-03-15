import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client_logs_screen.dart';
import 'usage_statistics_screen.dart';
import 'dns_settings_screen.dart';
import 'split_tunneling_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final fgMuted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: fg, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: PremiumBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Theme Section
              _SectionHeader(title: 'APPEARANCE', color: fgMuted),
              const SizedBox(height: 12),
              const _ThemeSelector(),
              const SizedBox(height: 32),

              // Connection Section
              _SectionHeader(title: 'CONNECTION', color: fgMuted),
              const SizedBox(height: 12),
              _SwitchTile(
                icon: Icons.block,
                title: 'Kill Switch',
                initialValue: true,
                onChanged: (val) {},
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.dns_outlined,
                title: 'DNS Settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DnsSettingsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.call_split,
                title: 'Split Tunneling',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SplitTunnelingScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Notifications Section
              _SectionHeader(title: 'NOTIFICATIONS', color: fgMuted),
              const SizedBox(height: 12),
              _SwitchTile(
                icon: Icons.notifications_none,
                title: 'Push Notifications',
                initialValue: true,
                onChanged: (val) {},
              ),
              const SizedBox(height: 32),

              // Diagnostics Section
              _SectionHeader(title: 'DIAGNOSTICS', color: fgMuted),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.bar_chart,
                title: 'Usage Statistics',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UsageStatisticsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.receipt_long,
                title: 'Client Logs',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientLogsScreen()),
                ),
              ),
              const SizedBox(height: 32),

              // General Section
              _SectionHeader(title: 'COMPANY', color: fgMuted),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Privacy Policy',
                onTap: () => _launchUrl('https://securevpn.cx/privacy-policy'),
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () =>
                    _launchUrl('https://securevpn.cx/terms-of-service'),
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'About',
                onTap: () => _launchUrl('https://securevpn.cx/about'),
                trailing: Text(
                  'v1.0.0',
                  style: TextStyle(color: fgMuted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = [
      (AppThemeMode.system, Icons.smartphone, 'System'),
      (AppThemeMode.light, Icons.light_mode, 'Light'),
      (AppThemeMode.dark, Icons.dark_mode, 'Dark'),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final fgMuted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    final currentTheme = ref.watch(themeProvider);

    return FrostedCard(
      padding: const EdgeInsets.all(4),
      borderRadius: 14,
      child: Row(
        children: themes.map((entry) {
          final (mode, icon, label) = entry;
          final isSelected = currentTheme == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).setTheme(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.08))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 20, color: isSelected ? fg : fgMuted),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? fg : fgMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;

    return FrostedCard(
      padding: EdgeInsets.zero,
      borderRadius: 14,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: fg, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing:
            trailing ??
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppTheme.foregroundSubtle
                  : AppTheme.lightForegroundSubtle,
              size: 20,
            ),
      ),
    );
  }
}

class _SwitchTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool initialValue;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_SwitchTile> createState() => _SwitchTileState();
}

class _SwitchTileState extends State<_SwitchTile> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: widget.icon,
      title: widget.title,
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch(
          value: _value,
          onChanged: (v) => setState(() => _value = v),
          activeThumbColor: AppTheme.successColor,
        ),
      ),
    );
  }
}
