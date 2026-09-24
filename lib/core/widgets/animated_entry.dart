import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedEntry extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration delay;

  const AnimatedEntry({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = const Duration(milliseconds: 45),
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    return child
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 180),
          delay: delay * index,
          curve: const Cubic(0.2, 0.8, 0.2, 1),
        )
        .slideY(
          begin: 0.018,
          end: 0,
          duration: const Duration(milliseconds: 180),
          delay: delay * index,
          curve: const Cubic(0.2, 0.8, 0.2, 1),
        );
  }
}
