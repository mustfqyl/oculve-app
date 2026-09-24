import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';

/// A shared page frame keeps headers and scrollable content aligned at every
/// window size used by the client.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? AppTheme.foreground : AppTheme.lightForeground;

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: IconButton(
                          tooltip: context.tr('Back'),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          color: foreground,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        title,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (action != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: action,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Center(
                    child: SizedBox(
                      width: math.min(constraints.maxWidth, 515),
                      height: constraints.maxHeight,
                      child: child,
                    ),
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
