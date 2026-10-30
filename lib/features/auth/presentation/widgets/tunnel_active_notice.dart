import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';

/// Shown on the sign-in screens while a tunnel is still up without a session.
///
/// Signing out never stops the tunnel, so the state has to stay visible here
/// together with the one action that makes sense without an account.
class TunnelActiveNotice extends ConsumerWidget {
  const TunnelActiveNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vpnProvider);
    if (state != VpnState.connected && state != VpnState.connecting) {
      return const SizedBox.shrink();
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? const Color(0xFF94A3B8)
        : AppTheme.lightForegroundMuted;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 13, color: muted),
          const SizedBox(width: 6),
          Text(
            'VPN is on',
            style: TextStyle(
              color: muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            onPressed: () => ref.read(vpnProvider.notifier).disconnect(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              'Turn off',
              style: TextStyle(
                color: muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
