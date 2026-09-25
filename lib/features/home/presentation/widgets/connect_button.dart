import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';

/// A prominent circular control keeps the primary action visually distinct
/// from the secondary location picker.
class ConnectButton extends ConsumerWidget {
  const ConnectButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vpnProvider);
    final errorMessage = ref.watch(vpnErrorProvider);
    final connected = state == VpnState.connected;
    final busy =
        state == VpnState.connecting || state == VpnState.disconnecting;
    final failed = state == VpnState.error;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? AppTheme.foreground : AppTheme.lightForeground;
    final accent = connected
        ? AppTheme.successColor
        : failed
        ? AppTheme.errorColor
        : (dark ? AppTheme.foregroundMuted : AppTheme.lightForegroundMuted);
    final label = switch (state) {
      VpnState.connected => context.tr('DISCONNECT'),
      VpnState.connecting => context.tr('CONNECTING'),
      VpnState.disconnecting => context.tr('STOPPING'),
      VpnState.error => context.tr('TRY AGAIN'),
      VpnState.disconnected => context.tr('CONNECT'),
    };
    final detail = switch (state) {
      VpnState.connected => context.tr('Your traffic is protected.'),
      VpnState.connecting => context.tr('Setting up a secure connection…'),
      VpnState.disconnecting => context.tr('Disconnecting securely…'),
      VpnState.error =>
        errorMessage == null
            ? context.tr('Tap to retry.')
            : context.tr(errorMessage),
      VpnState.disconnected => context.tr('Tap to protect your connection.'),
    };

    return Semantics(
      button: true,
      enabled: !busy,
      label: connected
          ? context.tr('Connected. Tap to disconnect.')
          : busy
          ? context.tr('VPN connection in progress')
          : failed
          ? context.tr('Connection failed. Tap to retry.')
          : context.tr('Tap to connect to the VPN'),
      child: SizedBox(
        width: 208,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              width: 164,
              height: 164,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(
                    alpha: connected || failed ? .38 : (dark ? .12 : .16),
                  ),
                ),
                boxShadow: [
                  if (connected || failed)
                    BoxShadow(
                      color: accent.withValues(alpha: .10),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const ValueKey('vpn-connect-control'),
                  customBorder: const CircleBorder(),
                  onTap: busy
                      ? null
                      : () => ref.read(vpnProvider.notifier).toggle(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark
                          ? (connected
                                ? const Color(0xFF142A25)
                                : const Color(0xFF171A20))
                          : (connected
                                ? const Color(0xFFEAF8F3)
                                : Colors.white.withValues(alpha: .86)),
                      border: Border.all(
                        color: accent.withValues(
                          alpha: connected || failed ? .28 : .10,
                        ),
                      ),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: busy
                            ? SizedBox(
                                key: ValueKey('busy-$state'),
                                width: 37,
                                height: 37,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: accent,
                                ),
                              )
                            : Column(
                                key: ValueKey('power-$state'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    failed
                                        ? Icons.refresh_rounded
                                        : Icons.power_settings_new_rounded,
                                    size: 38,
                                    color: accent,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: foreground,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                detail,
                key: ValueKey('connection-detail-$state-$errorMessage'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: failed
                      ? AppTheme.errorColor
                      : foreground.withValues(alpha: .55),
                  fontSize: 9.5,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
