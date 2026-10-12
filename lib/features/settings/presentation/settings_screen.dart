import 'dart:io' show Platform;

import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oculve/core/providers/theme_provider.dart';
import 'package:oculve/core/providers/animation_provider.dart';
import 'package:oculve/core/providers/locale_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'client_logs_screen.dart';
import 'usage_statistics_screen.dart';
import 'xray_core_settings_screen.dart';
import 'tray_preferences_screen.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        children: [
          // Appearance Section
          _SectionCaption(title: context.tr('Appearance'), color: fgMuted),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(10),
            borderRadius: 16,
            child: Column(
              children: [
                const _ThemeSelector(),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                const SizedBox(height: 10),
                const _LanguageSelector(),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                const SizedBox(height: 4),
                const _PageAnimationsSetting(),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Connection Section
          _SectionCaption(title: context.tr('Connection'), color: fgMuted),
          const SizedBox(height: 8),
          FrostedCard(
            padding: EdgeInsets.zero,
            borderRadius: 16,
            child: Column(
              children: [
                _GroupedSettingRow(
                  icon: Icons.tune_rounded,
                  title: 'Connection settings',
                  onTap: () => Navigator.push(
                    context,
                    appRoute(const XrayCoreSettingsScreen()),
                  ),
                ),
                if (Platform.isWindows ||
                    Platform.isMacOS ||
                    Platform.isLinux) ...[
                  _RowDivider(isDark: isDark),
                  _GroupedSettingRow(
                    icon: Icons.desktop_windows_outlined,
                    title: 'Tray & window',
                    onTap: () => Navigator.push(
                      context,
                      appRoute(const TrayPreferencesScreen()),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Diagnostics Section
          _SectionCaption(title: context.tr('Diagnostics'), color: fgMuted),
          const SizedBox(height: 8),
          FrostedCard(
            padding: EdgeInsets.zero,
            borderRadius: 16,
            child: Column(
              children: [
                _GroupedSettingRow(
                  icon: Icons.bar_chart_rounded,
                  title: 'Statistics',
                  onTap: () => Navigator.push(
                    context,
                    appRoute(const UsageStatisticsScreen()),
                  ),
                ),
                _RowDivider(isDark: isDark),
                _GroupedSettingRow(
                  icon: Icons.receipt_long_rounded,
                  title: 'Client Logs',
                  onTap: () => Navigator.push(
                    context,
                    appRoute(const ClientLogsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Help & Resources Section
          _SectionCaption(
            title: context.tr('Help & resources'),
            color: fgMuted,
          ),
          const SizedBox(height: 8),
          FrostedCard(
            padding: EdgeInsets.zero,
            borderRadius: 16,
            child: Column(
              children: [
                _GroupedSettingRow(
                  icon: Icons.download_outlined,
                  title: 'Downloads',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.oculve.com/download'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                _RowDivider(isDark: isDark),
                _GroupedSettingRow(
                  icon: Icons.support_agent_outlined,
                  title: 'Support',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.oculve.com/contact'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PageAnimationsSetting extends ConsumerWidget {
  const _PageAnimationsSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final muted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    final enabled = ref.watch(pageAnimationsProvider);

    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      value: enabled,
      onChanged: ref.read(pageAnimationsProvider.notifier).setEnabled,
      secondary: Icon(Icons.animation_rounded, size: 18, color: muted),
      title: Text(
        context.tr('Page animations'),
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        context.tr('Use smooth transitions between screens.'),
        style: TextStyle(color: muted, fontSize: 11, height: 1.25),
      ),
      dense: true,
    );
  }
}

class _SectionCaption extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionCaption({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  final bool isDark;
  const _RowDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.8,
      indent: 52,
      endIndent: 12,
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05),
    );
  }
}

class _GroupedSettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _GroupedSettingRow({
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final subtle = isDark
        ? AppTheme.foregroundSubtle
        : AppTheme.lightForegroundSubtle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                child: Center(child: Icon(icon, color: fg, size: 17)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: subtle, size: 18),
            ],
          ),
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
      (AppThemeMode.system, Icons.smartphone_rounded, 'System'),
      (AppThemeMode.light, Icons.light_mode_rounded, 'Light'),
      (AppThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final fgMuted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    final currentTheme = ref.watch(themeProvider);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: themes.map((entry) {
          final (mode, icon, label) = entry;
          final isSelected = currentTheme == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).setTheme(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected && !isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: isSelected ? fg : fgMuted),
                    const SizedBox(height: 3),
                    CompactLabel(
                      label,
                      style: TextStyle(
                        fontSize: 11,
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

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
          child: Center(
            child: Icon(Icons.translate_rounded, size: 15, color: fg),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CompactLabel(
            context.tr('Language'),
            textAlign: TextAlign.start,
            alignment: Alignment.centerLeft,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (code, _, short) in _languages) ...[
                if (code != 'en') const SizedBox(width: 2),
                _LanguageOption(
                  key: ValueKey('language-$code'),
                  code: code,
                  label: short,
                  selected: selected == code,
                  onTap: () =>
                      ref.read(localeProvider.notifier).setLanguage(code),
                ),
              ],
            ],
          ),
        ),
      ],
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;

    final languageName = switch (code) {
      'es' => 'Español',
      'tr' => 'Türkçe',
      _ => 'English',
    };
    return Semantics(
      label: languageName,
      button: true,
      selected: selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.successColor.withValues(alpha: .18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? AppTheme.successColor.withValues(alpha: .45)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected ? AppTheme.successColor : muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
