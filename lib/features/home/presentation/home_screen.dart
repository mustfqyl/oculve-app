import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'widgets/connect_button.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'widgets/server_card.dart';
import 'package:oculve/features/settings/presentation/settings_screen.dart';
import 'package:oculve/features/settings/presentation/account_screen.dart';
import 'package:oculve/core/widgets/animated_entry.dart';
import 'package:oculve/core/widgets/app_route.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final error = ref.watch(vpnErrorProvider);
    final desktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: PremiumBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
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
                                tooltip: context.tr('Account'),
                                onTap: () => Navigator.push(
                                  context,
                                  appRoute(const AccountScreen()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _HeaderAction(
                                icon: Icons.settings_outlined,
                                tooltip: context.tr('Settings'),
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
              if (error != null)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(11, 6, 4, 6),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: .10),
                      border: Border.all(
                        color: AppTheme.errorColor.withValues(alpha: .20),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppTheme.errorColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr(error),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr('Dismiss'),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 30,
                            height: 30,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: ref
                              .read(vpnProvider.notifier)
                              .dismissError,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ],
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

class OculveWordmark extends StatelessWidget {
  const OculveWordmark({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 108,
    height: 24,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'oculve',
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontFamily: Platform.isMacOS || Platform.isIOS
              ? '.AppleSystemUIFont'
              : Platform.isWindows
              ? 'Segoe UI'
              : 'sans-serif',
          fontSize: 22.8,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          height: 1,
        ),
      ),
    ),
  );
}

class _HeaderAction extends StatefulWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
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
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
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
    );
  }
}
