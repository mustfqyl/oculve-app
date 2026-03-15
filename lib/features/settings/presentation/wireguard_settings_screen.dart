import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class WireguardSettingsScreen extends StatefulWidget {
  const WireguardSettingsScreen({super.key});

  @override
  State<WireguardSettingsScreen> createState() =>
      _WireguardSettingsScreenState();
}

class _WireguardSettingsScreenState extends State<WireguardSettingsScreen> {
  int _persistentKeepalive = 25;
  String _endpoint = '';
  final _endpointController = TextEditingController();

  @override
  void dispose() {
    _endpointController.dispose();
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
          'WireGuard Settings',
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
              // Endpoint
              _SectionLabel(text: 'ENDPOINT', color: fgMuted),
              const SizedBox(height: 12),
              FrostedCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                borderRadius: 14,
                child: TextField(
                  controller: _endpointController,
                  style: TextStyle(color: fg),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. vpn.example.com:51820',
                    hintStyle: TextStyle(color: fgMuted, fontSize: 15),
                  ),
                  onChanged: (val) => setState(() => _endpoint = val),
                ),
              ),
              const SizedBox(height: 24),

              // Persistent Keepalive
              _SectionLabel(text: 'PERSISTENT KEEPALIVE', color: fgMuted),
              const SizedBox(height: 12),
              FrostedCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                borderRadius: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Interval (seconds)',
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$_persistentKeepalive',
                          style: TextStyle(color: fgMuted, fontSize: 13),
                        ),
                      ],
                    ),
                    Slider(
                      value: _persistentKeepalive.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 24,
                      activeColor: AppTheme.successColor,
                      onChanged: (val) =>
                          setState(() => _persistentKeepalive = val.toInt()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Reserved IP
              _SectionLabel(text: 'ALLOWED IPS', color: fgMuted),
              const SizedBox(height: 12),
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
                    hintText: '0.0.0.0/0, ::/0',
                    hintStyle: TextStyle(color: fgMuted, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
