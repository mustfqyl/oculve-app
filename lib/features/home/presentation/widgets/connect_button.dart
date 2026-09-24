import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';

/// A compact horizontal action makes the connection command readable at a
/// glance while keeping the server location secondary.
class ConnectButton extends ConsumerWidget {
  const ConnectButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vpnProvider);
    final connected = state == VpnState.connected;
    final busy =
        state == VpnState.connecting || state == VpnState.disconnecting;
    final failed = state == VpnState.error;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = connected
        ? AppTheme.successColor
        : failed
        ? AppTheme.errorColor
        : (dark ? AppTheme.foregroundMuted : AppTheme.lightForegroundMuted);
    final foreground = dark ? AppTheme.foreground : AppTheme.lightForeground;
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
      VpnState.error => context.tr('Connection failed. Tap to retry.'),
      VpnState.disconnected => context.tr('Tap to protect your connection.'),
    };

    return Semantics(
      button: true,
      enabled: !busy,
      label: connected
          ? context.tr('Connected. Tap to disconnect.')
          : busy
          ? context.tr('VPN connection in progress')
          : context.tr('Tap to connect to the VPN'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('vpn-connect-control'),
          borderRadius: BorderRadius.circular(17),
          onTap: busy ? null : () => ref.read(vpnProvider.notifier).toggle(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: 206,
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: connected ? .075 : .045)
                  : Colors.white.withValues(alpha: connected ? .92 : .75),
              border: Border.all(
                color: accent.withValues(
                  alpha: connected || failed ? .48 : .16,
                ),
              ),
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                if (connected || failed)
                  BoxShadow(
                    color: accent.withValues(alpha: .12),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: accent.withValues(
                      alpha: connected || failed ? .13 : .07,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: busy
                          ? SizedBox(
                              key: ValueKey('busy-$state'),
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            )
                          : Icon(
                              failed
                                  ? Icons.refresh_rounded
                                  : Icons.power_settings_new_rounded,
                              key: ValueKey('power-$state'),
                              size: 20,
                              color: accent,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Text(
                          label,
                          key: ValueKey('label-$state'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .65,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Text(
                          detail,
                          key: ValueKey('detail-$state'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground.withValues(alpha: .58),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                if (connected || failed)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: foreground.withValues(alpha: .38),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
