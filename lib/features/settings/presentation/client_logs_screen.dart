import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class ClientLogsScreen extends StatelessWidget {
  const ClientLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final fgMuted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;

    final mockLogs = [
      '[10:45:12] Initializing VPN Engine connection...',
      '[10:45:12] Loading configuration for Optimal Location...',
      '[10:45:13] Resolving host address (us-east.securevpn.cx)...',
      '[10:45:14] Establishing TLS connection...',
      '[10:45:15] Authentication successful. Negotiating ciphers...',
      '[10:45:15] Cipher CHACHA20-POLY1305 negotiated.',
      '[10:45:16] Assigning virtual IP 10.8.0.42...',
      '[10:45:16] Route established. Connection active.',
      '[10:46:00] Keepalive signal sent.',
      '[10:47:00] Keepalive signal sent.',
    ];

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
          'Client Logs',
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.copy, color: fg, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: mockLogs.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: PremiumBackground(
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: mockLogs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  mockLogs[index],
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color:
                        index == mockLogs.length - 1 ||
                            index == mockLogs.length - 2
                        ? fgMuted
                        : (mockLogs[index].contains('successful') ||
                                  mockLogs[index].contains('active')
                              ? AppTheme.successColor
                              : fg),
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
