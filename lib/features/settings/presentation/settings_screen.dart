import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oculve/core/providers/theme_provider.dart';
import 'package:oculve/core/providers/locale_provider.dart';
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
      title: context.tr('Settings'),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Theme Section
          _SectionHeader(title: context.tr('Appearance'), color: fgMuted),
          const SizedBox(height: 12),
          const _LanguageSelector(),
          const SizedBox(height: 10),
          const _ThemeSelector(),
          const SizedBox(height: 24),

          _SectionHeader(title: context.tr('Connection'), color: fgMuted),
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
          _SectionHeader(title: context.tr('Diagnostics'), color: fgMuted),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.bar_chart,
            title: 'Statistics',
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

          _SectionHeader(title: context.tr('Help & resources'), color: fgMuted),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.download_outlined,
            title: 'Downloads',
            onTap: () => launchUrl(
              Uri.parse('https://www.oculve.com/download'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.support_agent_outlined,
            title: 'Support',
            onTap: () => launchUrl(
              Uri.parse('https://www.oculve.com/contact'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector();

  static const _languages = [
    ('en', 'English', 'EN'),
    ('es', 'Español', 'ES'),
    ('tr', 'Türkçe', 'TR'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(localeProvider).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final muted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    return FrostedCard(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      borderRadius: 13,
      child: Row(
        children: [
          Icon(Icons.translate_rounded, size: 18, color: muted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              context.tr('Language'),
              style: TextStyle(fontSize: 12, color: fg),
            ),
          ),
          for (final (code, _, short) in _languages) ...[
            if (code != 'en') const SizedBox(width: 5),
            _LanguageOption(
              key: ValueKey('language-$code'),
              code: code,
              label: short,
              selected: selected == code,
              onTap: () => ref.read(localeProvider.notifier).setLanguage(code),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    super.key,
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: switch (code) {
      'es' => 'Español',
      'tr' => 'Türkçe',
      _ => 'English',
    },
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 34, minHeight: 30),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.successColor.withValues(alpha: .18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppTheme.successColor.withValues(alpha: .5)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected
                ? AppTheme.successColor
                : Theme.of(context).brightness == Brightness.dark
                ? AppTheme.foregroundMuted
                : AppTheme.lightForegroundMuted,
          ),
        ),
      ),
    ),
  );
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
