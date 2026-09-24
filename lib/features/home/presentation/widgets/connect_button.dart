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
    final foreground = connected
        ? Colors.white
        : dark
        ? AppTheme.backgroundColor
        : Colors.white;
    final fill = connected
        ? const Color(0xFF168D6A)
        : dark
        ? Colors.white
        : AppTheme.lightForeground;
    final label = switch (state) {
      VpnState.connected => context.tr('DISCONNECT'),
      VpnState.connecting => context.tr('CONNECTING'),
      VpnState.disconnecting => context.tr('STOPPING'),
      _ => context.tr('CONNECT'),
    };
    final icon = state == VpnState.error
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 206,
        height: 58,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: connected
                ? const Color(0xFF42C99C).withValues(alpha: .42)
                : (dark ? Colors.white : Colors.black).withValues(alpha: .1),
          ),
          boxShadow: [
            BoxShadow(
              color: (connected ? const Color(0xFF168D6A) : Colors.black)
                  .withValues(alpha: dark ? .18 : .10),
              blurRadius: connected ? 18 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
            onTap: busy ? null : () => ref.read(vpnProvider.notifier).toggle(),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Row(
                  key: ValueKey(state),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    else
                      Icon(icon, size: 19, color: foreground),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.15,
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
