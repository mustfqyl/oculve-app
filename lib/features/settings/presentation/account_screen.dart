import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

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
          'Account',
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
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.accentColor.withValues(
                        alpha: 0.2,
                      ),
                      child: Text(
                        'M',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mustafa',
                      style: TextStyle(
                        color: fg,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'mustafa@example.com',
                      style: TextStyle(color: fgMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'SUBSCRIPTION',
                style: TextStyle(
                  color: fgMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              FrostedCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Premium Plan',
                          style: TextStyle(
                            color: fg,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: AppTheme.successColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Renews on: Oct 24, 2026',
                      style: TextStyle(color: fgMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'ACCOUNT ACTIONS',
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
                    ListTile(
                      leading: Icon(Icons.password, color: fg),
                      title: Text(
                        'Change Password',
                        style: TextStyle(color: fg),
                      ),
                      trailing: Icon(Icons.chevron_right, color: fgMuted),
                      onTap: () {},
                    ),
                    _Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: AppTheme.dangerColor,
                      ),
                      title: const Text(
                        'Log Out',
                        style: TextStyle(color: AppTheme.dangerColor),
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Logged out successfully'),
                          ),
                        );
                        Navigator.pop(context);
                      },
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
