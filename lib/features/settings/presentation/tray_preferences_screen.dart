import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/desktop/tray_click_preferences.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'connection_settings_widgets.dart';

/// The native tray remains platform-owned; app preference menus follow Oculve
/// styling independently of the operating system.
class TrayPreferencesScreen extends ConsumerStatefulWidget {
  const TrayPreferencesScreen({super.key});
  @override
  ConsumerState<TrayPreferencesScreen> createState() =>
      _TrayPreferencesScreenState();
}

class _TrayPreferencesScreenState extends ConsumerState<TrayPreferencesScreen> {
  bool _busy = false;
  Future<bool> _save(Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(
          context,
          error,
          fallback: 'Could not save tray settings. Please try again.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(trayClickPreferencesProvider);
    final notifier = ref.read(trayClickPreferencesProvider.notifier);
    final linux = Theme.of(context).platform == TargetPlatform.linux;
    return AppPage(
      title: 'Tray & Window',
      headerHeight: 52,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                const SettingsCaption(
                  'CLICK ACTIONS',
                  compact: true,
                  topPadding: 4,
                ),
                SettingsGroup(
                  children: [
                    _TraySelector<TrayClickAction>(
                      id: 'left',
                      title: 'Left click',
                      value: preferences.left,
                      label: _actionLabel(preferences.left),
                      enabled: !_busy,
                      options: {
                        for (final action in TrayClickAction.values)
                          if (action != preferences.right &&
                              (!linux || action != TrayClickAction.showMenu))
                            action: _actionLabel(action),
                      },
                      onChanged: (value) =>
                          _save(() => notifier.setLeft(value)),
                    ),
                    _TraySelector<TrayClickAction>(
                      id: 'right',
                      title: 'Right click',
                      value: preferences.right,
                      label: _actionLabel(preferences.right),
                      enabled: !_busy,
                      options: {
                        for (final action in TrayClickAction.values)
                          if (action != preferences.left)
                            action: _actionLabel(action),
                      },
                      onChanged: (value) =>
                          _save(() => notifier.setRight(value)),
                    ),
                  ],
                ),
                if (linux)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                    child: SizedBox(
                      height: 26 * MediaQuery.textScalerOf(context).scale(1),
                      child: Text(
                        'On Linux, click behavior depends on the desktop environment.',
                        style: TextStyle(
                          color: settingsMuted(context),
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                const SettingsCaption('WINDOW BEHAVIOR', compact: true),
                SettingsGroup(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            72 * MediaQuery.textScalerOf(context).scale(1),
                      ),
                      child: SettingRow(
                        compact: true,
                        title: 'Hide when focus is lost',
                        subtitle: 'Keep the app running in the tray.',
                        trailing: SizedBox(
                          width: 48,
                          height: 32,
                          child: FittedBox(
                            child: Switch(
                              key: const ValueKey('tray-hide-on-blur'),
                              value: preferences.hideOnBlur,
                              activeTrackColor: AppTheme.successColor,
                              activeThumbColor: Colors.white,
                              overlayColor: quietOverlay,
                              onChanged: _busy
                                  ? null
                                  : (value) => _save(
                                      () => notifier.setHideOnBlur(value),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _TraySelector<TrayCloseAction>(
                      id: 'close',
                      title: 'When closing the window',
                      value: preferences.closeAction,
                      label: _closeLabel(preferences.closeAction),
                      enabled: !_busy,
                      options: {
                        for (final value in TrayCloseAction.values)
                          value: _closeLabel(value),
                      },
                      onChanged: (value) =>
                          _save(() => notifier.setCloseAction(value)),
                    ),
                  ],
                ),
                const SettingsCaption('TRAY APPEARANCE', compact: true),
                SettingsGroup(
                  children: [
                    _TraySelector<TrayStatusIndicator>(
                      id: 'indicator',
                      title: 'Status indicator',
                      value: preferences.indicator,
                      label: _indicatorLabel(preferences.indicator),
                      enabled: !_busy,
                      options: {
                        for (final value in TrayStatusIndicator.values)
                          value: _indicatorLabel(value),
                      },
                      onChanged: (value) =>
                          _save(() => notifier.setIndicator(value)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: SettingsRestoreButton(
              enabled: !_busy,
              onRestore: () => _save(notifier.reset),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraySelector<T> extends StatelessWidget {
  const _TraySelector({
    required this.id,
    required this.title,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
  });
  final String id, title, label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${context.tr(title)}: ${context.tr(label)}',
    child: InkWell(
      key: ValueKey('tray-selector-$id'),
      onTap: enabled ? _cycle : null,
      borderRadius: BorderRadius.circular(14),
      overlayColor: quietOverlay,
      splashFactory: NoSplash.splashFactory,
      child: SizedBox(
        height: 60 * MediaQuery.textScalerOf(context).scale(1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: settingsMuted(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 30 * MediaQuery.textScalerOf(context).scale(1),
                      child: SettingsSlidingValue(
                        label: label,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_left, size: 18, color: settingsMuted(context)),
            ],
          ),
        ),
      ),
    ),
  );
  void _cycle() {
    final values = options.keys.toList();
    onChanged(values[(values.indexOf(value) + 1) % values.length]);
  }
}

String _actionLabel(TrayClickAction value) => switch (value) {
  TrayClickAction.toggleWindow => 'Open or hide app',
  TrayClickAction.toggleConnection => 'Connect or disconnect VPN',
  TrayClickAction.chooseServer => 'Choose a location',
  TrayClickAction.showMenu => 'Show tray menu',
  TrayClickAction.quit => 'Quit Oculve',
};
String _closeLabel(TrayCloseAction value) =>
    value == TrayCloseAction.hide ? 'Hide to tray' : 'Quit Oculve';
String _indicatorLabel(TrayStatusIndicator value) =>
    value == TrayStatusIndicator.connection ? 'Connection state' : 'App icon';
