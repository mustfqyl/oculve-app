import 'package:flutter/material.dart';

/// Keeps desktop-style scrollbars out of the compact app, including routes and
/// popup overlays that inherit MaterialApp's ScrollBehavior.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
