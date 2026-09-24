import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';

class ConnectButton extends ConsumerWidget {
  const ConnectButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vpnProvider);
    final connected = state == VpnState.connected;
    final busy =
        state == VpnState.connecting || state == VpnState.disconnecting;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final failed = state == VpnState.error;
    final foreground = connected || failed
        ? Colors.white
        : dark
        ? AppTheme.backgroundColor
        : Colors.white;
    final fill = connected
        ? const Color(0xFF168D6A)
        : failed
        ? AppTheme.errorColor
        : dark
        ? Colors.white
        : AppTheme.lightForeground;
    final label = switch (state) {
      VpnState.connected => context.tr('DISCONNECT'),
      VpnState.connecting => context.tr('CONNECTING'),
      VpnState.disconnecting => context.tr('STOPPING'),
      _ => context.tr('CONNECT'),
    };
    final icon = failed
        ? Icons.refresh_rounded
        : Icons.power_settings_new_rounded;

    return Semantics(
      button: true,
      enabled: !busy,
      label: connected
          ? context.tr('Connected. Tap to disconnect.')
          : busy
          ? context.tr('VPN connection in progress')
          : context.tr('Tap to connect to the VPN'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: 216,
        height: 56,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: connected
                ? const Color(0xFF63E0B1).withValues(alpha: .7)
                : failed
                ? Colors.white.withValues(alpha: .35)
                : (dark ? Colors.white : Colors.black).withValues(alpha: .14),
            width: connected || failed ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (connected
                          ? const Color(0xFF168D6A)
                          : failed
                          ? AppTheme.errorColor
                          : Colors.black)
                      .withValues(alpha: dark ? .24 : .12),
              blurRadius: connected ? 20 : 13,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: busy ? null : () => ref.read(vpnProvider.notifier).toggle(),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Row(
                  key: ValueKey(state),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: foreground.withValues(alpha: .12),
                        border: Border.all(
                          color: foreground.withValues(alpha: .12),
                        ),
                      ),
                      child: Center(
                        child: busy
                            ? SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: foreground,
                                ),
                              )
                            : Icon(icon, size: 17, color: foreground),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
