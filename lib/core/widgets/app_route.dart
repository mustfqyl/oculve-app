import 'package:flutter/material.dart';

Route<T> appRoute<T>(Widget child) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 170),
  reverseTransitionDuration: const Duration(milliseconds: 140),
  pageBuilder: (_, _, _) => child,
  transitionsBuilder: (context, animation, _, page) {
    if (MediaQuery.disableAnimationsOf(context)) return page;
    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.025, 0),
          end: Offset.zero,
        ).animate(eased),
        child: page,
      ),
    );
  },
);
