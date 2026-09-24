import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';

/// The primary action is a compact power control, with a clear status ring.
/// Its circular footprint keeps it visually distinct from the smaller
/// location selector beneath it.
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
      VpnState.connected => context.tr('CONNECTED'),
      VpnState.connecting => context.tr('CONNECTING'),
      VpnState.disconnecting => context.tr('STOPPING'),
      _ => context.tr('CONNECT'),
    };

    return Semantics(
      button: true,
      enabled: !busy,
      label: connected
          ? context.tr('Connected. Tap to disconnect.')
          : busy
          ? context.tr('VPN connection in progress')
          : context.tr('Tap to connect to the VPN'),
      child: SizedBox.square(
        dimension: 142,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: 142,
              height: 142,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: connected ? .42 : .18),
                  width: connected ? 1.4 : 1,
                ),
                boxShadow: [
                  if (connected || failed)
                    BoxShadow(
                      color: accent.withValues(alpha: .14),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                ],
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkResponse(
                key: const ValueKey('vpn-connect-control'),
                radius: 66,
                containedInkWell: true,
                highlightShape: BoxShape.circle,
                onTap: busy
                    ? null
                    : () => ref.read(vpnProvider.notifier).toggle(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark
                        ? Colors.white.withValues(
                            alpha: connected ? .085 : .045,
                          )
                        : Colors.white.withValues(alpha: connected ? .92 : .72),
                    border: Border.all(
                      color: accent.withValues(alpha: connected ? .6 : .2),
                      width: connected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: busy
                            ? SizedBox(
                                key: ValueKey('busy-$state'),
                                width: 27,
                                height: 27,
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
                                size: 31,
                                color: accent,
                              ),
                      ),
                      const SizedBox(height: 9),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          label,
                          key: ValueKey('label-$state'),
                          style: TextStyle(
                            color: foreground.withValues(alpha: .76),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
