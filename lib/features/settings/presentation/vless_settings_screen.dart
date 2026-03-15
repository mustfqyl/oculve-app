import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class VlessSettingsScreen extends StatefulWidget {
  const VlessSettingsScreen({super.key});

  @override
  State<VlessSettingsScreen> createState() => _VlessSettingsScreenState();
}

class _VlessSettingsScreenState extends State<VlessSettingsScreen> {
  String _networkType = 'TCP';
  bool _tlsEnabled = true;
  String _alpn = 'h2,http/1.1';
  String _sni = '';
  final _sniController = TextEditingController();
  final _alpnController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _alpnController.text = _alpn;
  }

  @override
  void dispose() {
    _sniController.dispose();
    _alpnController.dispose();
    super.dispose();
  }

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
          'VLESS Settings',
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
              // Network Type
              _SectionLabel(text: 'NETWORK TYPE', color: fgMuted),
              const SizedBox(height: 12),
              FrostedCard(
                padding: EdgeInsets.zero,
                borderRadius: 14,
                child: Column(
                  children: [
                    _buildRadioTile(
                      'TCP',
                      'Standard TCP connection',
                      fg,
                      fgMuted,
                    ),
                    _Divider(),
                    _buildRadioTile(
                      'WebSocket',
                      'WebSocket transport',
                      fg,
                      fgMuted,
                    ),
                    _Divider(),
                    _buildRadioTile('gRPC', 'gRPC transport', fg, fgMuted),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // TLS
              _SectionLabel(text: 'SECURITY', color: fgMuted),
              const SizedBox(height: 12),
              FrostedCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                borderRadius: 14,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Enable TLS',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'Transport Layer Security encryption',
                    style: TextStyle(color: fgMuted, fontSize: 12),
                  ),
                  value: _tlsEnabled,
                  activeColor: AppTheme.successColor,
                  onChanged: (val) => setState(() => _tlsEnabled = val),
                ),
              ),
              const SizedBox(height: 24),

              // ALPN
              _SectionLabel(text: 'ALPN', color: fgMuted),
              const SizedBox(height: 12),
              FrostedCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                borderRadius: 14,
                child: TextField(
                  controller: _alpnController,
                  style: TextStyle(color: fg),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'h2,http/1.1',
                    hintStyle: TextStyle(color: fgMuted, fontSize: 15),
                  ),
                  onChanged: (val) => setState(() => _alpn = val),
                ),
              ),
              const SizedBox(height: 24),

              // SNI
              _SectionLabel(text: 'SERVER NAME (SNI)', color: fgMuted),
              const SizedBox(height: 12),
              FrostedCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                borderRadius: 14,
                child: TextField(
                  controller: _sniController,
                  style: TextStyle(color: fg),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'example.com',
                    hintStyle: TextStyle(color: fgMuted, fontSize: 15),
                  ),
                  onChanged: (val) => setState(() => _sni = val),
                ),
              ),
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
      groupValue: _networkType,
      activeColor: AppTheme.successColor,
      onChanged: (val) {
        if (val != null) setState(() => _networkType = val);
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

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
