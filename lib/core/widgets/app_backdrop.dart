import 'package:flutter/material.dart';

import 'package:oculve/core/theme/app_theme.dart';

/// The single backdrop of the app, mounted once behind the navigator.
///
/// [PremiumBackground] owns the base colour, the top glow and the drifting
/// orbs. Pages draw only their content, so a route transition slides content
/// over a still backdrop instead of dragging a second backdrop (with a second
/// set of bright orbs) along with it.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  /// The app's navigator (or any content that should sit above the backdrop).
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const PremiumBackground(child: SizedBox.expand()),
      child,
    ],
  );
}
