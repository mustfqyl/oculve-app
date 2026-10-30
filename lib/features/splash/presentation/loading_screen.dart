import 'dart:async';
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

  /// The native launch screen follows the phone's appearance, not the theme
  /// chosen in the app. The first frames follow the phone too, so nothing jumps
  /// when Flutter takes over; then the screen eases over to the app's theme.
  bool _followsApp = false;
  bool _artworkFollowsApp = false;
  Timer? _settle, _settleArtwork;

  @override
  void initState() {
    super.initState();
    _artworkAnimation = AnimationController(
      vsync: this,
      value: .5,
      duration: const Duration(seconds: 8),
    );
    _settle = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _followsApp = true);
      // The artwork switches halfway through the background's fade, when the
      // backdrop is mid-tone and the change reads as part of the same move.
      _settleArtwork = Timer(const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _artworkFollowsApp = true);
      });
    });
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
    _settle?.cancel();
    _settleArtwork?.cancel();
    _artworkAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appDark = Theme.of(context).brightness == Brightness.dark;
    final systemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = _followsApp ? appDark : systemDark;
    final artworkDark = _artworkFollowsApp ? appDark : systemDark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final fade = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 520);

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundColor
          : AppTheme.lightBackground,
      body: AnimatedContainer(
        duration: fade,
        curve: Curves.easeInOut,
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
                              dark: artworkDark,
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
