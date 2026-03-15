import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
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
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);

  static const Color primaryColor = accent;
  static const Color secondaryColor = successColor;
  static const Color surfaceColor = backgroundSecondary;
  static const Color accentColor = Color(0xFF3B82F6); // Assuming a nice blue
  static const Color dangerColor = errorColor;

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
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: foreground,
          displayColor: foreground,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: foreground),
      ),
      iconTheme: const IconThemeData(color: foreground),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightAccent,
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        secondary: successColor,
        surface: lightBackgroundSecondary,
        error: errorColor,
        onPrimary: lightBackground,
        onSecondary: lightBackground,
        onSurface: lightForeground,
        onError: lightBackground,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.light().textTheme.apply(
          bodyColor: lightForeground,
          displayColor: lightForeground,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lightForeground),
      ),
      iconTheme: const IconThemeData(color: lightForeground),
    );
  }
}

// ============================================================
// PREMIUM BACKGROUND – Exact Website Replica
// Dark: Cyber Neon | Light: Premium Studio
// ============================================================
class PremiumBackground extends StatefulWidget {
  final Widget child;
  const PremiumBackground({super.key, required this.child});

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground>
    with TickerProviderStateMixin {
  late AnimationController _driftCtrl;
  late AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    // For Orbs drifting
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    // For Nodes floating
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    _floatCtrl.dispose();
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
          // ── Layer 1: Background Image (bg-neon-white.png) ──
          // Dark: Contrast 1.05, Brightness 0.8
          // Light: Saturate 0.2, Brightness 1.4, Opacity 0.08
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 1.0 : 0.08,
              child: ColorFiltered(
                colorFilter: isDark
                    ? const ColorFilter.matrix([
                        // Contrast 1.05 & Brightness 0.8 (approx)
                        1.05, 0, 0, 0, -20,
                        0, 1.05, 0, 0, -20,
                        0, 0, 1.05, 0, -20,
                        0, 0, 0, 1, 0,
                      ])
                    : const ColorFilter.matrix([
                        // Saturate 0.2 & Brightness 1.4
                        0.3, 0.6, 0.1, 0, 40,
                        0.3, 0.6, 0.1, 0, 40,
                        0.3, 0.6, 0.1, 0, 40,
                        0, 0, 0, 1, 0,
                      ]),
                child: Image.asset(
                  'assets/bg-neon-white.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ),

          // ── Layer 2: Radial Gradient Overlay ──
          // Dark: Center black(0.3) -> bg
          // Light: Center white(0.1) -> bg
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: isDark
                      ? [
                          const Color(0xFF020202).withValues(alpha: 0.3),
                          AppTheme.backgroundColor,
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.1),
                          AppTheme.lightBackground.withValues(alpha: 0.9),
                        ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // ── Layer 4: Animated Orbs ──
          AnimatedBuilder(
            animation: _driftCtrl,
            builder: (context, _) {
              final t = _driftCtrl.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isDark) ...[
                    // Dark Mode: Neon Orbs (White & Blue)
                    Positioned(
                      top: -sz.height * 0.1 + math.cos(t * math.pi) * 30,
                      right: -sz.width * 0.1 + math.sin(t * math.pi) * 40,
                      child: _BlurredOrb(
                        size: 500,
                        color: Colors.white,
                        opacity: 0.10, // slightly more visible
                        blur: 100,
                      ),
                    ),
                    Positioned(
                      bottom: -50 - math.sin(t * math.pi) * 40,
                      left: -100 + math.cos(t * math.pi) * 30,
                      child: _BlurredOrb(
                        size: 400,
                        color: const Color(0xFF3B82F6),
                        opacity: 0.15,
                        blur: 100,
                      ),
                    ),
                  ] else ...[
                    // Light Mode: Studio Orbs (Indigo, Violet, Cyan)
                    Positioned(
                      top: sz.height * 0.1,
                      left: -sz.width * 0.2 + math.sin(t * math.pi) * 30,
                      child: _BlurredOrb(
                        size: 500,
                        color: const Color(0xFF6366F1), // Indigo
                        opacity: 0.08,
                        blur: 80,
                      ),
                    ),
                    Positioned(
                      bottom: sz.height * 0.1,
                      right: -sz.width * 0.1 - math.cos(t * math.pi) * 30,
                      child: _BlurredOrb(
                        size: 400,
                        color: const Color(0xFF8B5CF6), // Violet
                        opacity: 0.08,
                        blur: 80,
                      ),
                    ),
                    Positioned(
                      top: sz.height * 0.4,
                      left: sz.width * 0.3 + math.sin(t * math.pi * 0.5) * 40,
                      child: _BlurredOrb(
                        size: 300,
                        color: const Color(0xFF06B6D4), // Cyan
                        opacity: 0.08,
                        blur: 80,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          // ── Layer 5: Floating Pulse Nodes (Dark Only) ──
          if (isDark)
            AnimatedBuilder(
              animation: _floatCtrl,
              builder: (context, _) {
                final t = _floatCtrl.value;
                return Stack(
                  children: [
                    // Node 1
                    Positioned(
                      top: sz.height * 0.2 - (t * 100) % 200, // Move Up
                      left: sz.width * 0.15 + math.sin(t * math.pi * 2) * 20,
                      child: _PulseNode(
                        opacity: (math.sin(t * math.pi * 4) + 1) / 2 * 0.3,
                      ),
                    ),
                    // Node 2
                    Positioned(
                      bottom: sz.height * 0.3 + (t * 80) % 200, // Move Down
                      right: sz.width * 0.1 + math.cos(t * math.pi * 2) * 20,
                      child: _PulseNode(
                        opacity: (math.cos(t * math.pi * 4) + 1) / 2 * 0.3,
                      ),
                    ),
                  ],
                );
              },
            ),

          // ── Layer 6: Content ──
          widget.child,
        ],
      ),
    );
  }
}

// ── Helper Widgets ──

class _BlurredOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  final double blur;

  const _BlurredOrb({
    required this.size,
    required this.color,
    required this.opacity,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

class _PulseNode extends StatelessWidget {
  final double opacity;
  const _PulseNode({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: opacity),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FROSTED GLASS CARD – heavy blur like Betternet
// ============================================================
class FrostedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blurAmount;
  final Color? color;

  const FrostedCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.blurAmount = 30,
    this.color,
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
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: child,
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
