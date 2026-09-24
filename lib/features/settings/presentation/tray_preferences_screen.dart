import 'dart:io' show Platform;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/desktop/tray_click_preferences.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';

class TrayPreferencesScreen extends ConsumerWidget {
  const TrayPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(trayClickPreferencesProvider);
    final notifier = ref.read(trayClickPreferencesProvider.notifier);
    final linux = Platform.isLinux;
    return AppPage(
      title: context.tr('Tray & menu bar'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        children: [
          _ActionSetting(
            title: context.tr('Left-click action'),
            value: preferences.left,
            enabled: !linux,
            onChanged: notifier.setLeft,
          ),
          const SizedBox(height: 10),
          _ActionSetting(
            title: context.tr('Right-click action'),
            value: preferences.right,
            enabled: !linux,
            onChanged: notifier.setRight,
          ),
          if (linux) ...[
            const SizedBox(height: 12),
            FrostedCard(
              padding: const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 17),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      context.tr(
                        'On Linux, tray click behavior is controlled by the desktop environment. Use the Oculve tray menu for connection and location actions.',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.foregroundMuted
                            : AppTheme.lightForegroundMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionSetting extends StatelessWidget {
  const _ActionSetting({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final TrayClickAction value;
  final bool enabled;
  final ValueChanged<TrayClickAction> onChanged;

  @override
  Widget build(BuildContext context) => FrostedCard(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        PopupMenuButton<TrayClickAction>(
          key: ValueKey(
            'tray-action-${title.toLowerCase().replaceAll(' ', '-')}',
          ),
          enabled: enabled,
          initialValue: value,
          onSelected: onChanged,
          itemBuilder: (context) => TrayClickAction.values
              .map(
                (action) => PopupMenuItem(
                  value: action,
                  child: Text(_actionLabel(context, action)),
                ),
              )
              .toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(_actionLabel(context, value))),
                Icon(
                  Icons.expand_more_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.foregroundMuted
                      : AppTheme.lightForegroundMuted,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  String _actionLabel(BuildContext context, TrayClickAction action) =>
      context.tr(switch (action) {
        TrayClickAction.toggleWindow => 'Open or hide the app',
        TrayClickAction.toggleConnection => 'Connect or disconnect VPN',
        TrayClickAction.chooseServer => 'Choose a location',
        TrayClickAction.showMenu => 'Show the tray menu',
        TrayClickAction.quit => 'Quit Oculve',
      });
}
