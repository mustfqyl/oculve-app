import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/protocol_provider.dart';

class VpnProtocolSettingsScreen extends ConsumerStatefulWidget {
  const VpnProtocolSettingsScreen({super.key});

  @override
  ConsumerState<VpnProtocolSettingsScreen> createState() =>
      _VpnProtocolSettingsScreenState();
}

class _VpnProtocolSettingsScreenState
    extends ConsumerState<VpnProtocolSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final fgMuted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: fg, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'VPN Protocol',
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: PremiumBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'PROTOCOL SELECTION',
                style: TextStyle(
                  color: fgMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              FrostedCard(
                padding: EdgeInsets.zero,
                borderRadius: 14,
                child: Column(
                  children: [
                    _buildRadioTile(
                      VpnProtocol.wireguard,
                      'WireGuard',
                      'Speed Mode - High speed, modern protocol',
                      fg,
                      fgMuted,
                    ),
                    _Divider(),
                    _buildRadioTile(
                      VpnProtocol.vless,
                      'VLESS',
                      'Security Mode - Excellent encryption & privacy',
                      fg,
                      fgMuted,
                    ),
                    _Divider(),
                    _buildRadioTile(
                      VpnProtocol.byedpi,
                      'ByeDPI',
                      'Bypass Mode - Circumvent deep packet inspection',
                      fg,
                      fgMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioTile(
    VpnProtocol protocolValue,
    String title,
    String subtitle,
    Color fg,
    Color fgMuted,
  ) {
    final currentProtocol = ref.watch(protocolProvider);
    return RadioListTile<VpnProtocol>(
      title: Text(
        title,
        style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: fgMuted, fontSize: 12)),
      value: protocolValue,
      groupValue: currentProtocol,
      activeColor: AppTheme.successColor,
      onChanged: (val) {
        if (val != null) {
          ref.read(protocolProvider.notifier).state = val;
        }
      },
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05),
    );
  }
}
