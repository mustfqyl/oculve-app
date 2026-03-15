import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class DnsSettingsScreen extends StatefulWidget {
  const DnsSettingsScreen({super.key});

  @override
  State<DnsSettingsScreen> createState() => _DnsSettingsScreenState();
}

class _DnsSettingsScreenState extends State<DnsSettingsScreen> {
  String _selectedDns = 'Automatic';

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
          'DNS Settings',
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
                'SELECT DNS SERVER',
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
                      'Automatic',
                      'Recommended for best performance',
                      fg,
                      fgMuted,
                    ),
                    _Divider(),
                    _buildRadioTile('Cloudflare', '1.1.1.1', fg, fgMuted),
                    _Divider(),
                    _buildRadioTile(
                      'Google Public DNS',
                      '8.8.8.8',
                      fg,
                      fgMuted,
                    ),
                    _Divider(),
                    _buildRadioTile(
                      'Custom',
                      'Configure custom DNS providers',
                      fg,
                      fgMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_selectedDns == 'Custom') ...[
                FrostedCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  borderRadius: 14,
                  child: TextField(
                    style: TextStyle(color: fg),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter custom DNS IP...',
                      hintStyle: TextStyle(color: fgMuted, fontSize: 15),
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

  Widget _buildRadioTile(
    String title,
    String subtitle,
    Color fg,
    Color fgMuted,
  ) {
    return RadioListTile<String>(
      title: Text(
        title,
        style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: fgMuted, fontSize: 12)),
      value: title,
      groupValue: _selectedDns,
      activeColor: AppTheme.successColor,
      onChanged: (val) {
        if (val != null) setState(() => _selectedDns = val);
      },
      secondary: Icon(
        title == 'Cloudflare'
            ? Icons.cloud
            : title == 'Google Public DNS'
            ? Icons.search
            : title == 'Custom'
            ? Icons.edit
            : Icons.auto_awesome,
        color: fgMuted,
        size: 20,
      ),
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
