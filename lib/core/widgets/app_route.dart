import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Route<T> appRoute<T>(Widget child) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return _AppCupertinoPageRoute<T>(builder: (_) => child);
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    return MaterialPageRoute<T>(builder: (_) => child);
  }

  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 235),
    pageBuilder: (_, _, _) => child,
    transitionsBuilder: (context, animation, _, page) {
      if (MediaQuery.disableAnimationsOf(context)) return page;
      final eased = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 0.9, end: 1).animate(eased),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.012, 0),
            end: Offset.zero,
          ).animate(eased),
          child: page,
        ),
      );
    },
  );
}

class _AppCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _AppCupertinoPageRoute({required super.builder});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 360);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 320);
}
