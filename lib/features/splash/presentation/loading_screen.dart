import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/auth/presentation/widgets/oculve_veil_artwork.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _artworkAnimation;

  @override
  void initState() {
    super.initState();
    _artworkAnimation = AnimationController(
      vsync: this,
      value: .5,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _artworkAnimation.stop();
      _artworkAnimation.value = .5;
    } else if (!_artworkAnimation.isAnimating) {
      _artworkAnimation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _artworkAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundColor
          : AppTheme.lightBackground,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF252525),
                    Color(0xFF101419),
                    Color(0xFF081426),
                  ]
                : const [
                    Color(0xFFFFFFFF),
                    Color(0xFFF3F4F6),
                    Color(0xFFE8EDF5),
                  ],
          ),
        ),
        child: Center(
          child: Semantics(
            label: context.tr('Loading'),
            liveRegion: true,
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.min(
                    constraints.maxWidth * .92,
                    math.min(
                      400.0,
                      math.max(0.0, constraints.maxHeight - 40) * 280 / 188,
                    ),
                  );
                  final artworkHeight = width * 188 / 280;
                  return SizedBox.expand(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: width,
                          height: artworkHeight,
                          child: FadeTransition(
                            opacity: reduceMotion
                                ? const AlwaysStoppedAnimation<double>(1)
                                : Tween<double>(begin: .94, end: 1).animate(
                                    CurvedAnimation(
                                      parent: _artworkAnimation,
                                      curve: Curves.easeInOut,
                                    ),
                                  ),
                            child: OculveVeilArtwork(
                              progress: reduceMotion
                                  ? const AlwaysStoppedAnimation<double>(.5)
                                  : _artworkAnimation,
                              dark: isDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
