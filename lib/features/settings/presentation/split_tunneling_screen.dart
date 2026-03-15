import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class SplitTunnelingScreen extends StatefulWidget {
  const SplitTunnelingScreen({super.key});

  @override
  State<SplitTunnelingScreen> createState() => _SplitTunnelingScreenState();
}

class _SplitTunnelingScreenState extends State<SplitTunnelingScreen> {
  bool _isEnabled = false;
  final Map<String, bool> _apps = {
    'Chrome': true,
    'Spotify': false,
    'Netflix': true,
    'Banking App': false,
    'WhatsApp': true,
  };

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
          'Split Tunneling',
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
              FrostedCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                borderRadius: 14,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Enable Split Tunneling',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'Select which apps bypass the VPN connection',
                    style: TextStyle(color: fgMuted, fontSize: 12),
                  ),
                  value: _isEnabled,
                  activeColor: AppTheme.successColor,
                  onChanged: (val) => setState(() => _isEnabled = val),
                ),
              ),
              const SizedBox(height: 32),

              if (_isEnabled) ...[
                Text(
                  'INSTALLED APPS',
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
                    children: _apps.entries.map((entry) {
                      return Column(
                        children: [
                          _buildAppTile(entry.key, entry.value, fg, fgMuted),
                          if (entry.key != _apps.keys.last) _Divider(),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Text(
                      'Enable Split Tunneling to manage app routing.',
                      style: TextStyle(color: fgMuted),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppTile(String title, bool isRouted, Color fg, Color fgMuted) {
    return CheckboxListTile(
      title: Text(
        title,
        style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(
        isRouted ? 'Routed through VPN' : 'Bypasses VPN',
        style: TextStyle(color: fgMuted, fontSize: 12),
      ),
      value: isRouted,
      activeColor: AppTheme.successColor,
      onChanged: (val) {
        if (val != null) setState(() => _apps[title] = val);
      },
      secondary: Icon(Icons.android, color: fgMuted, size: 24),
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
