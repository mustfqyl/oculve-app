import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_flutter/core/theme/app_theme.dart';
import 'package:mobile_flutter/core/providers/vpn_provider.dart';
import 'package:mobile_flutter/core/models/vpn_state.dart';

class ConnectButton extends ConsumerWidget {
  const ConnectButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpnState = ref.watch(vpnProvider);
    final isConnected = vpnState == VpnState.connected;
    final isConnecting = vpnState == VpnState.connecting;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Connected = white glow/text (not green)
    final activeColor = isDark ? Colors.white : AppTheme.lightAccent;
    final mutedColor = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;

    return GestureDetector(
      onTap: () {
        if (!isConnecting) {
          ref.read(vpnProvider.notifier).toggle();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Outer ring
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            width: 170, // Reverted slightly from 150
            height: 170, // Reverted slightly from 150
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isConnected
                    ? activeColor.withValues(alpha: 0.25)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06)),
                width: 1,
              ),
            ),
            child: Center(
              child: FrostedCircle(
                size: 130, // Reduced from 150
                blurAmount: 40,
                color: isConnected
                    ? activeColor.withValues(alpha: isDark ? 0.12 : 0.08)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04)),
                boxShadow: [
                  BoxShadow(
                    color: isConnected
                        ? activeColor.withValues(alpha: 0.20)
                        : Colors.transparent,
                    blurRadius: isConnected ? 60 : 0,
                    spreadRadius: isConnected ? 5 : 0,
                  ),
                ],
                child: Center(
                  child: isConnecting
                      ? SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            color: isDark
                                ? AppTheme.foreground
                                : AppTheme.lightForeground,
                            strokeWidth: 2,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.power_settings_new,
                              size: 48,
                              color: isConnected ? activeColor : mutedColor,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isConnected ? 'CONNECTED' : 'CONNECT',
                              style: TextStyle(
                                color: isConnected ? activeColor : mutedColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.5,
                                fontSize: 11,
                              ),
                            ),
                          ],
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
