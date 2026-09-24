import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/providers/theme_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'client_logs_screen.dart';
import 'usage_statistics_screen.dart';
import 'xray_core_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgMuted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;

    return AppPage(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Theme Section
          _SectionHeader(title: 'APPEARANCE', color: fgMuted),
          const SizedBox(height: 12),
          const _ThemeSelector(),
          const SizedBox(height: 24),

          _SectionHeader(title: 'CONNECTION', color: fgMuted),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.tune,
            title: 'Xray core',
            onTap: () => Navigator.push(
              context,
              appRoute(const XrayCoreSettingsScreen()),
            ),
          ),
          const SizedBox(height: 24),

          // Diagnostics Section
          _SectionHeader(title: 'DIAGNOSTICS', color: fgMuted),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.bar_chart,
            title: 'Usage Statistics',
            onTap: () => Navigator.push(
              context,
              appRoute(const UsageStatisticsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.receipt_long,
            title: 'Client Logs',
            onTap: () =>
                Navigator.push(context, appRoute(const ClientLogsScreen())),
          ),
          const SizedBox(height: 24),
        ],
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

  const _SettingsTile({required this.icon, required this.title, this.onTap});

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
        trailing: Icon(
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
