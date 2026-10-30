import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Fade-through motion shared by every page route.
///
/// Pages no longer paint a backdrop of their own (see `AppBackdrop`), so the
/// page underneath would stay fully opaque and its text would show through the
/// transparent gaps of the page sliding in. Here the page coming in fades in
/// over the first half of its slide, while the page being covered fades out
/// quickly, so the two contents are never fully opaque at the same time.
class AppFadeThroughTransition extends StatelessWidget {
  const AppFadeThroughTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  /// Animation of the route this transition belongs to.
  final Animation<double> animation;

  /// Animation of the route covering this one.
  final Animation<double> secondaryAnimation;

  final Widget child;

  /// Opacity of a page coming in, for route progress [t] (0 → 1).
  static double incomingOpacity(double t) =>
      Curves.easeIn.transform(const Interval(0, .5).transform(t));

  /// Opacity of a page being covered, for the covering route's progress [t].
  static double outgoingOpacity(double t) =>
      1 - Curves.easeIn.transform(const Interval(0, .4).transform(t));

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: animation.drive(
        Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: const Interval(0, .5, curve: Curves.easeIn))),
      ),
      child: FadeTransition(
        opacity: secondaryAnimation.drive(
          Tween<double>(begin: 1, end: 0).chain(
            CurveTween(curve: const Interval(0, .4, curve: Curves.easeIn)),
          ),
        ),
        child: child,
      ),
    );
  }
}

Route<T> appRoute<T>(Widget child) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return _AppCupertinoPageRoute<T>(builder: (_) => child);
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    // The fade-through comes from the theme's page transitions builder.
    return MaterialPageRoute<T>(builder: (_) => child);
  }

  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 235),
    pageBuilder: (_, _, _) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, page) {
      if (MediaQuery.disableAnimationsOf(context)) return page;
      final eased = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      );
      return AppFadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
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

/// The iOS slide, kept as-is, wrapped in the shared fade-through.
///
/// [CupertinoRouteTransitionMixin.buildPageTransitions] is used rather than a
/// hand-written slide because it also installs the left-edge back-swipe
/// detector. With reduced motion the slide is pinned to its end state so the
/// transition is instant while the gesture keeps working.
Widget _cupertinoFadeThrough<T>(
  PageRoute<T> route,
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      route,
      context,
      const AlwaysStoppedAnimation<double>(1),
      const AlwaysStoppedAnimation<double>(0),
      child,
    );
  }
  return AppFadeThroughTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    child: CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    ),
  );
}

class _AppCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _AppCupertinoPageRoute({required super.builder});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 360);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 320);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _cupertinoFadeThrough<T>(
    this,
    context,
    animation,
    secondaryAnimation,
    child,
  );
}

/// iOS transition for routes the app does not create itself (the initial page).
class AppCupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppCupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _cupertinoFadeThrough<T>(
    route,
    context,
    animation,
    secondaryAnimation,
    child,
  );
}

/// Android/desktop transition: the content cross-fades through the shared
/// backdrop, without moving the backdrop itself.
class AppFadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppFadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => AppFadeThroughTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    child: child,
  );
}
