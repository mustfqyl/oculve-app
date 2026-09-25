import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';

/// The main action is a single, unmistakable power control.
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
    final muted = dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
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
    final faceColor = connected
        ? dark
              ? const Color(0xFF172820)
              : const Color(0xFFEDF8F2)
        : failed
        ? dark
              ? const Color(0xFF2B2023)
              : const Color(0xFFFFF1F1)
        : dark
        ? const Color(0xFF1B2029)
        : const Color(0xFFF9FAFC);

    return Semantics(
      button: true,
      enabled: !busy,
      label: semanticsLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('vpn-connect-control'),
              customBorder: const CircleBorder(),
              onTap: busy
                  ? null
                  : () => ref.read(vpnProvider.notifier).toggle(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: 164,
                height: 164,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(
                    alpha: connected || failed ? .075 : .025,
                  ),
                  border: Border.all(
                    color: accent.withValues(
                      alpha: connected || failed ? .48 : .14,
                    ),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(
                        alpha: connected || failed ? .12 : .035,
                      ),
                      blurRadius: 28,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: faceColor,
                    border: Border.all(
                      color: accent.withValues(
                        alpha: connected || failed ? .2 : .08,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: dark ? .16 : .035,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: busy
                            ? SizedBox(
                                key: ValueKey('busy-$state'),
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation(accent),
                                ),
                              )
                            : Icon(
                                key: ValueKey('power-$state'),
                                failed
                                    ? Icons.refresh_rounded
                                    : Icons.power_settings_new_rounded,
                                size: 37,
                                color: accent,
                              ),
                      ),
                      const SizedBox(height: 9),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          title,
                          key: ValueKey('connect-title-$state'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: 248,
            height: 30,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  detail,
                  key: ValueKey('connection-detail-$state-$errorMessage'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: failed ? AppTheme.errorColor : muted,
                    fontSize: 10,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
