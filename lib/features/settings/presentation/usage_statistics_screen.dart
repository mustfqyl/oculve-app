import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class UsageStatisticsScreen extends StatelessWidget {
  const UsageStatisticsScreen({super.key});

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
          'Usage Statistics',
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
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'DATA UP',
                      value: '4.2',
                      unit: ' GB',
                      icon: Icons.arrow_upward,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'DATA DOWN',
                      value: '18.7',
                      unit: ' GB',
                      icon: Icons.arrow_downward,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatCard(
                title: 'TOTAL CONNECTION TIME',
                value: '42h 18m',
                unit: '',
                icon: Icons.timer,
                color: Colors.purpleAccent,
                isFullWidth: true,
              ),
              const SizedBox(height: 32),
              Text(
                'RECENT SESSIONS',
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
                    _buildSessionTile(
                      'United States (New York)',
                      '2h 15m',
                      '1.2 GB',
                      fg,
                      fgMuted,
                    ),
                    _Divider(),
                    _buildSessionTile(
                      'Optimal Location (Auto)',
                      '45m',
                      '300 MB',
                      fg,
                      fgMuted,
                    ),
                    _Divider(),
                    _buildSessionTile(
                      'Germany (Frankfurt)',
                      '5h 30m',
                      '4.5 GB',
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

  Widget _buildSessionTile(
    String location,
    String time,
    String data,
    Color fg,
    Color fgMuted,
  ) {
    return ListTile(
      leading: Icon(Icons.public, color: fg, size: 24),
      title: Text(
        location,
        style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Text(
        'Connected for $time',
        style: TextStyle(color: fgMuted, fontSize: 12),
      ),
      trailing: Text(
        data,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool isFullWidth;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final fgMuted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;

    return FrostedCard(
      padding: const EdgeInsets.all(20),
      blurAmount: 20,
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: fgMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: fg,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: TextStyle(
                    color: fgMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
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
