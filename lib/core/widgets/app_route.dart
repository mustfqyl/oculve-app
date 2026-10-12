import 'package:flutter/material.dart';

Route<T> appRoute<T>(Widget child) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 230),
  reverseTransitionDuration: const Duration(milliseconds: 195),
  pageBuilder: (_, _, _) => child,
  transitionsBuilder: (context, animation, _, page) {
    if (MediaQuery.disableAnimationsOf(context)) return page;
    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0.84, end: 1).animate(eased),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.02, 0),
          end: Offset.zero,
        ).animate(eased),
        child: page,
      ),
    );
  },
);
