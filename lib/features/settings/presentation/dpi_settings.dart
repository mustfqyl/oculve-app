import 'package:oculve/core/models/vpn_state.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/connection/dpi_preferences.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'connection_settings_widgets.dart';

class DpiSettings extends ConsumerStatefulWidget {
  const DpiSettings({super.key});
  @override
  ConsumerState<DpiSettings> createState() => _DpiSettingsState();
}

class _DpiSettingsState extends ConsumerState<DpiSettings> {
  DpiStrategy _strategy = DpiStrategy.automatic;
  bool _busy = true, _done = false;
  Timer? _feedback;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final strategy = await DpiPreferences.read();
      if (mounted) setState(() => _strategy = strategy);
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cycle() async {
    setState(() => _busy = true);
    try {
      final next =
          DpiStrategy.values[(_strategy.index + 1) % DpiStrategy.values.length];
      await DpiPreferences.save(next);
      if (mounted) setState(() => _strategy = next);
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      // ByeDPI learns groups in its own destination cache, scoped to its process.
      // Restarting the active DPI session clears that cache while preserving the
      // user's manual strategy and using the existing disconnect/connect path.
      final active =
          ref.read(selectedServerProvider) == dpiBypassServerId &&
          ref.read(vpnTunnelMayBeActiveProvider);
      if (active) {
        final vpn = ref.read(vpnProvider.notifier);
        await vpn.disconnect();
        if (ref.read(vpnTunnelMayBeActiveProvider)) {
          throw StateError('Could not stop DPI Bypass.');
        }
        await vpn.connect(automatic: true);
      }
      if (mounted) {
        setState(() => _done = true);
        _feedback?.cancel();
        _feedback = Timer(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _done = false);
        });
      }
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _feedback?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vpnProvider);
    final transitioning =
        state == VpnState.connecting || state == VpnState.disconnecting;
    return SettingsGroup(
      children: [
        SettingsCycleRow(
          key: const ValueKey('dpi-strategy'),
          title: 'Strategy',
          label: _strategy.label,
          options: DpiStrategy.values.map((value) => value.label).toList(),
          onTap: _busy ? null : _cycle,
        ),
        SettingRow(
          key: const ValueKey('dpi-retry'),
          title: 'Retry DPI Bypass',
          subtitle: 'Clears learned strategies. Reconnects if active.',
          onTap: _busy || transitioning ? null : _retry,
          trailing: _done
              ? Icon(
                  Icons.check,
                  color: AppTheme.successForeground(
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                  size: 18,
                )
              : null,
        ),
      ],
    );
  }
}
