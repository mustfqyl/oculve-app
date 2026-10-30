import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/widgets/inline_feedback.dart';

/// A shared page frame keeps headers and scrollable content aligned at every
/// window size used by the client.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.headerHeight = 64,
    this.feedback,
  });

  final String title;
  final Widget child;
  final Widget? action;
  final double headerHeight;

  /// When given, failures and confirmations of this page are shown in the
  /// header in place of the title, then the title comes back.
  final InlineErrorController? feedback;

  Widget _title(Color foreground) => Text(
    title,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: foreground,
      fontSize: 17,
      height: 1.12,
      fontWeight: FontWeight.w600,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? AppTheme.foreground : AppTheme.lightForeground;

    return Scaffold(
      // The one app backdrop (AppBackdrop) paints behind the navigator, so a
      // page stays clear and only its content moves during a transition.
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          semanticLabel: context.tr('Back'),
                        ),
                        color: foreground,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 66),
                    child: Center(
                      child: feedback == null
                          ? _title(foreground)
                          : InlineHeaderMessage(
                              controller: feedback!,
                              title: _title(foreground),
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
    );
  }
}
