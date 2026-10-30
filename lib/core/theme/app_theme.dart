import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:oculve/core/widgets/app_route.dart';

class AppTheme {
  // === Typography scale tokens ===
  static const double fontSizeMicro = 10.0;
  static const double fontSizeCaption = 11.0;
  static const double fontSizeBody = 13.0;
  static const double fontSizeSubtitle = 15.0;
  static const double fontSizeHeader = 22.0;

  // === Website dark theme tokens ===
  static const Color backgroundColor = Color(0xFF020202);
  static const Color backgroundSecondary = Color(0xFF080808);

  static const Color foreground = Color(0xFFFCFCFC);
  static const Color foregroundMuted = Color(0xFF94A3B8);
  static const Color foregroundSubtle = Color(0xFF475569);

  static const Color accent = Color(0xFFFFFFFF);
  static const Color accentSoft = Color(0x0AFFFFFF);

  // Glassmorphism card colors – more transparent for blur effect
  static const Color cardBg = Color(0x1AFFFFFF); // ~10% white
  static const Color cardBorder = Color(0x14FFFFFF); // ~8% white
  static const Color cardHoverBorder = Color(0x33FFFFFF);

  static const Color successColor = Color(0xFF10B981);
  static const Color lightSuccessColor = Color(0xFF065F46);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);

  static const Color primaryColor = accent;
  static const Color secondaryColor = successColor;
  static const Color surfaceColor = backgroundSecondary;
  static const Color accentColor = Color(0xFF3B82F6); // Assuming a nice blue
  static const Color dangerColor = errorColor;

  static Color successForeground({required bool isDark}) =>
      isDark ? successColor : lightSuccessColor;

  static WidgetStateProperty<Color?> interactionOverlay({
    required bool isDark,
  }) => WidgetStateProperty.resolveWith((states) {
    final ink = isDark ? Colors.white : Colors.black;
    if (states.contains(WidgetState.focused)) {
      return ink.withValues(alpha: .09);
    }
    if (states.contains(WidgetState.hovered)) {
      return ink.withValues(alpha: .055);
    }
    return Colors.transparent;
  });

  // === Website LIGHT theme tokens ===
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightBackgroundSecondary = Color(0xFFF3F4F6);
  static const Color lightForeground = Color(0xFF09090B);
  static const Color lightForegroundMuted = Color(0xFF52525B);
  static const Color lightForegroundSubtle = Color(0xFFA1A1AA);
  static const Color lightAccent = Color(0xFF09090B);
  static const Color lightCardBg = Color(0xB3FFFFFF); // ~70% white
  static const Color lightCardBorder = Color(0x1209090B); // ~7% black

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      // Pages are transparent so the one shared backdrop (AppBackdrop) shows
      // through; routes cross-fade over it instead of stacking backdrops.
      pageTransitionsTheme: _pageTransitions,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: successColor,
        surface: backgroundSecondary,
        error: errorColor,
        onPrimary: backgroundColor,
        onSecondary: backgroundColor,
        onSurface: foreground,
        onError: foreground,
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Colors.transparent),
        trackColor: WidgetStatePropertyAll(Colors.transparent),
        thickness: WidgetStatePropertyAll(0),
        thumbVisibility: WidgetStatePropertyAll(false),
        trackVisibility: WidgetStatePropertyAll(false),
        interactive: false,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'Outfit',
        bodyColor: foreground,
        displayColor: foreground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: foreground),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF15191F),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black54,
        elevation: 16,
        menuPadding: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: cardBorder),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          color: foreground,
          fontSize: 14,
        ),
      ),
      iconTheme: const IconThemeData(color: foreground),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      pageTransitionsTheme: _pageTransitions,
      primaryColor: lightAccent,
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        secondary: lightSuccessColor,
        surface: lightBackgroundSecondary,
        error: errorColor,
        onPrimary: lightBackground,
        onSecondary: lightBackground,
        onSurface: lightForeground,
        onError: lightBackground,
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Colors.transparent),
        trackColor: WidgetStatePropertyAll(Colors.transparent),
        thickness: WidgetStatePropertyAll(0),
        thumbVisibility: WidgetStatePropertyAll(false),
        trackVisibility: WidgetStatePropertyAll(false),
        interactive: false,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: 'Outfit',
        bodyColor: lightForeground,
        displayColor: lightForeground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lightForeground),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black26,
        elevation: 12,
        menuPadding: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: lightCardBorder),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          color: lightForeground,
          fontSize: 14,
        ),
      ),
      iconTheme: const IconThemeData(color: lightForeground),
    );
  }
}

/// One transition policy for every platform: content cross-fades over the
/// single shared backdrop (see [AppFadeThroughTransition]).
const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: AppFadeThroughPageTransitionsBuilder(),
    TargetPlatform.iOS: AppCupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: AppFadeThroughPageTransitionsBuilder(),
    TargetPlatform.windows: AppFadeThroughPageTransitionsBuilder(),
    TargetPlatform.linux: AppFadeThroughPageTransitionsBuilder(),
  },
);

// ============================================================
// ORB DRIFT PHASE – one clock shared by the app backdrop
// ============================================================
/// Phase of the animated background orbs.
///
/// The single app backdrop ([PremiumBackground] behind the navigator) keeps a
/// controller only to receive frames. The phase itself comes from this one
/// clock, started when the backdrop was built, so the motion is continuous
/// across route changes instead of restarting at `t = 0`.
class OrbDriftPhase {
  OrbDriftPhase._();

  /// One sweep, matching the controller's `repeat(reverse: true)`.
  static const Duration period = Duration(seconds: 44);

  static Duration? _epoch;
  static Duration? _lastElapsed;

  /// Time since the first background was built.
  ///
  /// Outside a frame this returns the value last seen inside one, which keeps
  /// callers free of the scheduler's frame-only time stamp assertion.
  static Duration elapsed() {
    final now = _frameTime();
    if (now == null) return _lastElapsed ?? Duration.zero;
    var epoch = _epoch;
    if (epoch == null || now < epoch) {
      // First use, or the scheduler restarted its epoch (hot reload, a
      // timeDilation change): the shared clock restarts with it.
      epoch = now;
      _epoch = epoch;
    }
    final sinceEpoch = now - epoch;
    _lastElapsed = sinceEpoch;
    return sinceEpoch;
  }

  /// The value the old per-page controller reported: a triangle wave over two
  /// [period]s, i.e. `repeat(reverse: true)`.
  static double wave(Duration elapsed, {Duration period = period}) {
    final half = period.inMicroseconds;
    final x = (elapsed.inMicroseconds % (half * 2)) / half;
    return x <= 1 ? x : 2 - x;
  }

  static Duration? _frameTime() {
    final binding = SchedulerBinding.instance;
    final phase = binding.schedulerPhase;
    final inFrame =
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.persistentCallbacks;
    return inFrame ? binding.currentFrameTimeStamp : null;
  }

  /// Restarts the shared clock; tests call this to stay deterministic.
  @visibleForTesting
  static void reset() {
    _epoch = null;
    _lastElapsed = null;
  }
}

// ============================================================
// PREMIUM BACKGROUND – Website background geometry and colors
// Dark: Cyber Neon | Light: Premium Studio
// ============================================================
class PremiumBackground extends StatefulWidget {
  final Widget child;
  const PremiumBackground({super.key, required this.child});

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground>
    with SingleTickerProviderStateMixin {
  /// Keeps frames coming; the phase itself comes from [OrbDriftPhase].
  late final AnimationController _driftCtrl = AnimationController(
    vsync: this,
    duration: OrbDriftPhase.period,
  );

  /// Phase held still while reduced motion is on, as the stopped controller
  /// used to be.
  double? _frozenT;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _frozenT ??= _driftCtrl.value;
      _driftCtrl.stop();
    } else {
      _frozenT = null;
      if (!_driftCtrl.isAnimating) {
        _driftCtrl.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppTheme.backgroundColor
        : AppTheme.lightBackground;

    return Container(
      color: bgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Website .bg-glow layer, above the page background.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1.4),
                  radius: 1.25,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: 0.048),
                          Colors.transparent,
                        ]
                      : [
                          Colors.black.withValues(alpha: 0.024),
                          Colors.transparent,
                        ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Orb layer. Its phase comes from the shared clock, so every page
          // draws the same frame; the boundary keeps orb repaints away from
          // the page content.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _driftCtrl,
              builder: (context, _) {
                final t =
                    _frozenT ?? OrbDriftPhase.wave(OrbDriftPhase.elapsed());
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (isDark) ...[
                      // Same base geometry as .neon-1 and .neon-2 on the site.
                      Positioned(
                        top: -200 + math.cos(t * math.pi) * 30,
                        right: -100 + math.sin(t * math.pi) * 40,
                        child: const _SoftOrb(
                          size: 600,
                          color: Colors.white,
                          opacity: 0.15,
                          profile: _whiteOrbProfile,
                          halo: 200,
                        ),
                      ),
                      Positioned(
                        bottom: -50 - math.sin(t * math.pi) * 40,
                        left: -100 + math.cos(t * math.pi) * 30,
                        child: const _SoftOrb(
                          size: 400,
                          color: Color(0xFF3B82F6),
                          opacity: 0.15,
                          profile: _blueOrbProfile,
                          halo: 200,
                        ),
                      ),
                    ] else ...[
                      // Website .studio-1, .studio-2 and .studio-3.
                      Positioned(
                        top: sz.height * 0.1,
                        left: -100 + math.sin(t * math.pi) * 30,
                        child: const _SoftOrb(
                          size: 500,
                          color: Color(0xFF6366F1), // Indigo
                          opacity: 0.12,
                        ),
                      ),
                      Positioned(
                        bottom: sz.height * 0.2,
                        right: -50 - math.cos(t * math.pi) * 30,
                        child: const _SoftOrb(
                          size: 400,
                          color: Color(0xFF8B5CF6), // Violet
                          opacity: 0.12,
                        ),
                      ),
                      Positioned(
                        top: sz.height * 0.4,
                        left: sz.width * 0.3 + math.sin(t * math.pi * 0.5) * 40,
                        child: const _SoftOrb(
                          size: 300,
                          color: Color(0xFF06B6D4), // Cyan
                          opacity: 0.12,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          // Content
          // Background motion must not repaint unchanged text and controls.
          RepaintBoundary(child: widget.child),
        ],
      ),
    );
  }
}

// ── Helper Widgets ──

/// A soft, unclipped glow. Painting it as a gradient instead of a blurred
/// circle avoids the square blur box and the per-frame blur cost.
///
/// The dark orbs pass a [profile] sampled from the Gaussian feather the old
/// blurred disc had (a disc of radius `size / 2` blurred with sigma 100) plus
/// a [halo] of two sigma, so the glow keeps its original brightness, softness
/// and spread. The glow is painted outside the widget's [size] box, which
/// keeps every orb position unchanged.
class _SoftOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  /// Alpha multipliers from the centre (stop 0) to the edge of the glow.
  final List<(double, double)> profile;

  /// How far the glow reaches past the disc, in pixels.
  final double halo;

  const _SoftOrb({
    required this.size,
    required this.color,
    required this.opacity,
    this.profile = const [(0, 1), (.45, .45), (1, 0)],
    this.halo = 0,
  });

  @override
  Widget build(BuildContext context) {
    final extent = size + 2 * halo;
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: OverflowBox(
          maxWidth: extent,
          maxHeight: extent,
          child: Container(
            width: extent,
            height: extent,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                stops: [for (final (stop, _) in profile) stop],
                colors: [
                  for (final (_, alpha) in profile)
                    color.withValues(alpha: opacity * alpha),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gaussian feather of the white neon orb: a disc of radius 300 blurred with
/// sigma 100, sampled into nine stops up to two sigma past the disc.
const List<(double, double)> _whiteOrbProfile = [
  (0, .989),
  (.125, .978),
  (.25, .932),
  (.375, .818),
  (.5, .623),
  (.625, .385),
  (.75, .184),
  (.875, .065),
  (1, .017),
];

/// Same feather for the blue neon orb (radius 200, sigma 100).
const List<(double, double)> _blueOrbProfile = [
  (0, .865),
  (.125, .831),
  (.25, .731),
  (.375, .576),
  (.5, .396),
  (.625, .232),
  (.75, .113),
  (.875, .045),
  (1, .015),
];

// ============================================================
// FROSTED GLASS CARD – heavy blur like Betternet
// ============================================================
class FrostedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blurAmount;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;

  const FrostedCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.blurAmount = 30,
    this.color,
    this.borderColor,
    this.borderWidth = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppTheme.cardBg : AppTheme.lightCardBg;
    final borderColor = isDark ? AppTheme.cardBorder : AppTheme.lightCardBorder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? defaultBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: this.borderColor ?? borderColor,
              width: borderWidth,
            ),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

// ============================================================
// FROSTED CIRCLE – for connect button style
// ============================================================
class FrostedCircle extends StatelessWidget {
  final Widget child;
  final double size;
  final double blurAmount;
  final Color? color;
  final List<BoxShadow>? boxShadow;

  const FrostedCircle({
    super.key,
    required this.child,
    required this.size,
    this.blurAmount = 40,
    this.color,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark ? AppTheme.cardBorder : AppTheme.lightCardBorder;

    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          alignment: Alignment.center,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color ?? defaultColor,
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
