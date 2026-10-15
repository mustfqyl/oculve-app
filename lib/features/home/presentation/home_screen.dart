import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'widgets/connect_button.dart';
import 'widgets/server_card.dart';
import 'package:oculve/features/settings/presentation/settings_screen.dart';
import 'package:oculve/features/settings/presentation/account_screen.dart';
import 'package:oculve/core/widgets/animated_entry.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/core/widgets/oculve_wordmark.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.listen<String?>(vpnErrorProvider, (previous, next) {
      if (next != null && next != previous) {
        AppFeedback.showError(
          context,
          next,
          fallback: 'Could not establish the VPN. Please try again.',
          placement: AppFeedbackPlacement.home,
        );
      }
    });
    final desktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              AnimatedEntry(
                index: 0,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: desktop ? 24 : 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OculveWordmark(
                        color: isDark
                            ? AppTheme.foreground
                            : AppTheme.lightForeground,
                      ),
                      Row(
                        children: [
                          _HeaderAction(
                            icon: Icons.person_outline,
                            semanticLabel: context.tr('Account'),
                            onTap: () => Navigator.push(
                              context,
                              appRoute(const AccountScreen()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _HeaderAction(
                            icon: Icons.settings_outlined,
                            semanticLabel: context.tr('Settings'),
                            onTap: () => Navigator.push(
                              context,
                              appRoute(const SettingsScreen()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              const AnimatedEntry(index: 1, child: ConnectButton()),
              const SizedBox(height: 18),
              AnimatedEntry(index: 2, child: const ServerCard()),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatefulWidget {
  const _HeaderAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  @override
  State<_HeaderAction> createState() => _HeaderActionState();
}

class _HeaderActionState extends State<_HeaderAction> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? AppTheme.foreground : AppTheme.lightForeground;
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            mouseCursor: SystemMouseCursors.click,
            splashFactory: NoSplash.splashFactory,
            overlayColor: AppTheme.interactionOverlay(isDark: dark),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: AnimatedScale(
                  scale: _pressed ? .975 : 1,
                  duration: const Duration(milliseconds: 120),
                  curve: const Cubic(.34, 1.56, .64, 1),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark
                          ? Colors.white.withValues(alpha: .04)
                          : Colors.black.withValues(alpha: .03),
                      border: Border.all(
                        color: dark
                            ? Colors.white.withValues(alpha: .08)
                            : Colors.black.withValues(alpha: .07),
                      ),
                    ),
                    child: Icon(widget.icon, size: 19, color: foreground),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
