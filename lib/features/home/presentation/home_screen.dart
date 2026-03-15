import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import 'widgets/connect_button.dart';
import 'widgets/mode_selector.dart';
import 'widgets/server_card.dart';
import 'package:mobile_flutter/features/settings/presentation/settings_screen.dart';
import 'package:mobile_flutter/features/settings/presentation/account_screen.dart';
import '../../../../core/widgets/animated_entry.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final fgSub = isDark
        ? AppTheme.foregroundSubtle
        : AppTheme.lightForegroundSubtle;
    final bgColor = isDark
        ? AppTheme.backgroundColor
        : AppTheme.lightBackground;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              AnimatedEntry(
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 32,
                    bottom: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: fg,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(Icons.lock, size: 15, color: bgColor),
                          ),
                          const SizedBox(width: 10),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'SECURE',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: fg,
                                  ),
                                ),
                                TextSpan(
                                  text: 'VPN',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                    color: fgSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Account Button
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withAlpha(13)
                              : Colors.black.withAlpha(13),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.person_outline, size: 20, color: fg),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AccountScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Settings Button
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withAlpha(13)
                              : Colors.black.withAlpha(13),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.settings, size: 20, color: fg),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── Connect Button (center) ──
              const AnimatedEntry(
                index: 1,
                child: Center(child: ConnectButton()),
              ),

              const SizedBox(height: 32),
              // ── Server card (compact, below connect button) ──
              const AnimatedEntry(
                index: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 60),
                  child: ServerCard(),
                ),
              ),

              const Spacer(),

              // ── Mode selector (bottom) ──
              const AnimatedEntry(
                index: 3,
                child: Padding(
                  padding: EdgeInsets.only(left: 24, right: 24, bottom: 8),
                  child: ModeSelector(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
