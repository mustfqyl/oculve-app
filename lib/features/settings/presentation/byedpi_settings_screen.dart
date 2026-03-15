import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class ByedpiSettingsScreen extends StatefulWidget {
  const ByedpiSettingsScreen({super.key});

  @override
  State<ByedpiSettingsScreen> createState() => _ByedpiSettingsScreenState();
}

class _ByedpiSettingsScreenState extends State<ByedpiSettingsScreen> {
  String _desyncMethod = 'Split';
  int _ttl = 5;
  int _splitPosition = 2;
  bool _fakePacket = true;
  bool _disorder = false;

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
          'ByeDPI Settings',
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
              // Desync Method
              _SectionLabel(text: 'DESYNC METHOD', color: fgMuted),
              const SizedBox(height: 12),
              FrostedCard(
                padding: EdgeInsets.zero,
                borderRadius: 14,
                child: Column(
                  children: [
                    _buildRadioTile(
                      'Split',
                      'Split TCP packets to bypass DPI',
                      fg,
                      fgMuted,
                    ),
                    _Divider(),
                    _buildRadioTile(
                      'Disorder',
                      'Send packets out of order',
                      fg,
                      fgMuted,
                    ),
                    _Divider(),
                    _buildRadioTile(
                      'Fake',
                      'Send fake packets before real data',
                      fg,
                      fgMuted,
                    ),
                    _Divider(),
                    _buildRadioTile('OOB', 'Use out-of-band data', fg, fgMuted),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // TTL
              _SectionLabel(text: 'TTL VALUE', color: fgMuted),
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
                          'TTL',
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$_ttl',
                          style: TextStyle(color: fgMuted, fontSize: 13),
                        ),
                      ],
                    ),
                    Slider(
                      value: _ttl.toDouble(),
                      min: 1,
                      max: 255,
                      divisions: 254,
                      activeColor: AppTheme.successColor,
                      onChanged: (val) => setState(() => _ttl = val.toInt()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Split Position
              _SectionLabel(text: 'SPLIT POSITION', color: fgMuted),
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
                          'Position',
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$_splitPosition',
                          style: TextStyle(color: fgMuted, fontSize: 13),
                        ),
                      ],
                    ),
                    Slider(
                      value: _splitPosition.toDouble(),
                      min: 1,
                      max: 100,
                      divisions: 99,
                      activeColor: AppTheme.successColor,
                      onChanged: (val) =>
                          setState(() => _splitPosition = val.toInt()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Toggles
              _SectionLabel(text: 'OPTIONS', color: fgMuted),
              const SizedBox(height: 12),
              FrostedCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                borderRadius: 14,
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Fake Packet',
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'Send fake packets to confuse DPI',
                        style: TextStyle(color: fgMuted, fontSize: 12),
                      ),
                      value: _fakePacket,
                      activeColor: AppTheme.successColor,
                      onChanged: (val) => setState(() => _fakePacket = val),
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Disorder',
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'Send packets in random order',
                        style: TextStyle(color: fgMuted, fontSize: 12),
                      ),
                      value: _disorder,
                      activeColor: AppTheme.successColor,
                      onChanged: (val) => setState(() => _disorder = val),
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
      groupValue: _desyncMethod,
      activeColor: AppTheme.successColor,
      onChanged: (val) {
        if (val != null) setState(() => _desyncMethod = val);
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
