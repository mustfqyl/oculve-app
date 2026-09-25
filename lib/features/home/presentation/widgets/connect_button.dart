import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';

/// A sleek, minimalist capsule connection control.
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
    final fg = dark ? AppTheme.foreground : AppTheme.lightForeground;
    final accent = connected
        ? AppTheme.successColor
        : failed
        ? AppTheme.errorColor
        : dark
        ? const Color(0xFF9BAAC0)
        : const Color(0xFF58677E);

    final title = switch (state) {
      VpnState.connected => context.tr('DISCONNECT'),
      VpnState.connecting => context.tr('CONNECTING'),
      VpnState.disconnecting => context.tr('STOPPING'),
      VpnState.error => context.tr('TRY AGAIN'),
      VpnState.disconnected => context.tr('CONNECT'),
    };

    final statusBadge = switch (state) {
      VpnState.connected => context.tr('PROTECTED'),
      VpnState.connecting => context.tr('CONNECTING…'),
      VpnState.disconnecting => context.tr('STOPPING…'),
      VpnState.error => context.tr('UNPROTECTED'),
      VpnState.disconnected => context.tr('UNPROTECTED'),
    };

    final semanticsLabel = connected
        ? context.tr('Connected. Tap to disconnect.')
        : busy
        ? context.tr('VPN connection in progress')
        : failed
        ? context.tr('Connection failed. Tap to retry.')
        : context.tr('Tap to connect to the VPN');

    final bgColor = connected
        ? (dark ? const Color(0xFF0F261D) : const Color(0xFFE8F7EE))
        : failed
        ? (dark ? const Color(0xFF261216) : const Color(0xFFFFF0F2))
        : (dark ? const Color(0xFF131720) : const Color(0xFFF3F5F8));

    final borderColor = connected
        ? AppTheme.successColor.withValues(alpha: dark ? 0.45 : 0.60)
        : failed
        ? AppTheme.errorColor.withValues(alpha: dark ? 0.45 : 0.50)
        : dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Semantics(
      button: true,
      enabled: !busy,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('vpn-connect-control'),
          borderRadius: BorderRadius.circular(20),
          onTap: busy ? null : () => ref.read(vpnProvider.notifier).toggle(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 232,
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                if (connected)
                  BoxShadow(
                    color: AppTheme.successColor.withValues(
                      alpha: dark ? 0.18 : 0.12,
                    ),
                    blurRadius: 24,
                    spreadRadius: 0,
                  )
                else if (failed)
                  BoxShadow(
                    color: AppTheme.errorColor.withValues(
                      alpha: dark ? 0.14 : 0.08,
                    ),
                    blurRadius: 20,
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.20 : 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Minimalist State Icon Pill
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    key: ValueKey('icon-box-$state'),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: accent.withValues(
                        alpha: connected
                            ? (dark ? 0.18 : 0.14)
                            : failed
                            ? 0.12
                            : (dark ? 0.06 : 0.05),
                      ),
                      border: Border.all(
                        color: accent.withValues(
                          alpha: connected ? 0.35 : 0.12,
                        ),
                      ),
                    ),
                    child: Center(
                      child: busy
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation(accent),
                              ),
                            )
                          : Icon(
                              connected
                                  ? Icons.shield_rounded
                                  : failed
                                  ? Icons.refresh_rounded
                                  : Icons.power_settings_new_rounded,
                              size: 21,
                              color: accent,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Center State & Action Labels
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          title,
                          key: ValueKey('title-$state'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: connected
                                ? AppTheme.successColor
                                : failed
                                ? AppTheme.errorColor
                                : fg,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          statusBadge,
                          key: ValueKey('badge-$state'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Glowing Status Beacon
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    boxShadow: connected
                        ? [
                            BoxShadow(
                              color: AppTheme.successColor.withValues(
                                alpha: 0.7,
                              ),
                              blurRadius: 8,
                              spreadRadius: 1.5,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
