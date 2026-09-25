import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';

/// A clear, compact primary action that reads like a connection control.
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
    final muted = dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    final idle = !connected && !busy && !failed;
    final buttonForeground = idle
        ? (dark ? const Color(0xFF111318) : Colors.white)
        : foreground;
    final detailForeground = idle
        ? buttonForeground.withValues(alpha: .66)
        : failed
        ? AppTheme.errorColor
        : muted;
    final accent = connected
        ? AppTheme.successColor
        : failed
        ? AppTheme.errorColor
        : idle
        ? buttonForeground
        : muted;
    final title = switch (state) {
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
    final semanticsLabel = connected
        ? context.tr('Connected. Tap to disconnect.')
        : busy
        ? context.tr('VPN connection in progress')
        : failed
        ? context.tr('Connection failed. Tap to retry.')
        : context.tr('Tap to connect to the VPN');

    return Semantics(
      button: true,
      enabled: !busy,
      label: semanticsLabel,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 256),
          child: SizedBox(
            width: 240,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('vpn-connect-control'),
                borderRadius: BorderRadius.circular(20),
                onTap: busy
                    ? null
                    : () => ref.read(vpnProvider.notifier).toggle(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: idle
                        ? dark
                              ? const Color(0xFFF4F5F7)
                              : const Color(0xFF17191D)
                        : connected
                        ? (dark
                              ? const Color(0xFF182A25)
                              : const Color(0xFFEAF8F3))
                        : failed
                        ? (dark
                              ? const Color(0xFF321F22)
                              : const Color(0xFFFFF0F0))
                        : (dark
                              ? const Color(0xFF252A31)
                              : Colors.white.withValues(alpha: .9)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accent.withValues(
                        alpha: connected || failed
                            ? .34
                            : idle
                            ? .08
                            : .12,
                      ),
                    ),
                    boxShadow: idle
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .12),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (connected || failed ? accent : buttonForeground)
                                  .withValues(alpha: idle ? .08 : .13),
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: busy
                                ? SizedBox(
                                    key: ValueKey('busy-$state'),
                                    width: 18,
                                    height: 18,
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
                                title,
                                key: ValueKey('connect-title-$state'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: buttonForeground,
                                  fontSize: 14,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              child: Text(
                                detail,
                                key: ValueKey(
                                  'connection-detail-$state-$errorMessage',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: detailForeground,
                                  fontSize: 10,
                                  height: 1.15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Icon(
                        connected
                            ? Icons.stop_rounded
                            : failed
                            ? Icons.refresh_rounded
                            : Icons.arrow_forward_rounded,
                        size: 16,
                        color: accent.withValues(alpha: .8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
