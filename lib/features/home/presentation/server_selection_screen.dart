import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen> {
  final List<Map<String, dynamic>> _servers = [
    {'name': 'Optimal Location', 'ping': 'Auto', 'isOptimal': true},
    {'name': 'United States', 'ping': '45ms', 'flag': 'us'},
    {'name': 'United Kingdom', 'ping': '112ms', 'flag': 'gb'},
    {'name': 'Germany', 'ping': '140ms', 'flag': 'de'},
    {'name': 'France', 'ping': '145ms', 'flag': 'fr'},
    {'name': 'Japan', 'ping': '190ms', 'flag': 'jp'},
    {'name': 'Singapore', 'ping': '210ms', 'flag': 'sg'},
  ];

  String _selectedServer = 'Optimal Location';

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
          icon: Icon(Icons.close, color: fg, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Server',
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
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: FrostedCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  borderRadius: 14,
                  child: TextField(
                    style: TextStyle(color: fg),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search locations...',
                      hintStyle: TextStyle(color: fgMuted, fontSize: 15),
                      icon: Icon(Icons.search, color: fgMuted, size: 20),
                    ),
                  ),
                ),
              ),

              // Server List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 24,
                  ),
                  itemCount: _servers.length,
                  itemBuilder: (context, index) {
                    final server = _servers[index];
                    final isOptimal = server['isOptimal'] == true;
                    final isSelected = _selectedServer == server['name'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(
                            () => _selectedServer = server['name'] as String,
                          );
                          Navigator.pop(context, {
                            'name': server['name'] as String,
                            'flag': server['flag'] as String?,
                            'ping': server['ping'] as String?,
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.08))
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.03)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.successColor.withValues(alpha: 0.5)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isOptimal
                                      ? AppTheme.successColor.withValues(
                                          alpha: 0.2,
                                        )
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: isOptimal
                                    ? const Icon(
                                        Icons.flash_on,
                                        color: AppTheme.successColor,
                                        size: 16,
                                      )
                                    : Center(
                                        child: Text(
                                          _getFlagEmoji(
                                            server['flag'] as String? ?? '',
                                          ),
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      server['name'] as String,
                                      style: TextStyle(
                                        color: fg,
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isOptimal
                                          ? 'Fastest available server'
                                          : '${server['ping']} ping',
                                      style: TextStyle(
                                        color: isOptimal
                                            ? AppTheme.successColor
                                            : fgMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.successColor,
                                  size: 24,
                                )
                              else
                                Icon(
                                  Icons.circle_outlined,
                                  color: fgMuted.withValues(alpha: 0.5),
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFlagEmoji(String countryCode) {
    if (countryCode.isEmpty) return '🌍';
    final int firstLetter =
        countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter =
        countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }
}
