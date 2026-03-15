import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../server_selection_screen.dart';

class ServerCard extends StatefulWidget {
  const ServerCard({super.key});

  @override
  State<ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<ServerCard> {
  String _selectedServer = 'Optimal Location';
  String? _selectedFlag; // null = optimal/auto
  String? _selectedPing;

  String _getFlagEmoji(String countryCode) {
    if (countryCode.isEmpty) return '🌍';
    final int firstLetter =
        countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter =
        countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final fgMuted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    final fgSub = isDark
        ? AppTheme.foregroundSubtle
        : AppTheme.lightForegroundSubtle;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServerSelectionScreen()),
        );
        if (result != null && result is Map) {
          setState(() {
            _selectedServer = result['name'] ?? 'Optimal Location';
            _selectedFlag = result['flag'];
            _selectedPing = result['ping'];
          });
        }
      },
      child: FrostedCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        blurAmount: 30,
        borderRadius: 14,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostedCircle(
              size: 34,
              blurAmount: 15,
              child: _selectedFlag != null
                  ? Center(
                      child: Text(
                        _getFlagEmoji(_selectedFlag!),
                        style: const TextStyle(fontSize: 16),
                      ),
                    )
                  : Icon(
                      Icons.flash_on,
                      color: AppTheme.successColor,
                      size: 16,
                    ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedServer,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _selectedFlag != null
                      ? (_selectedPing ?? 'Selected')
                      : 'Automatic',
                  style: TextStyle(
                    color: fgMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: fgSub, size: 18),
          ],
        ),
      ),
    );
  }
}
