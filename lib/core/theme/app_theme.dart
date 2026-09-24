import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _driftCtrl;
  late AnimationController _nodeCtrl;

  @override
  void initState() {
    super.initState();
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 44),
    )..repeat(reverse: true);
    _nodeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    _nodeCtrl.dispose();
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

          // Website BackgroundEffects' dark neon and light studio orbs.
          AnimatedBuilder(
            animation: Listenable.merge([_driftCtrl, _nodeCtrl]),
            builder: (context, _) {
              final t = _driftCtrl.value;
              final nodeOne = (_nodeCtrl.value * 1.5) % 1;
              final nodeTwo = 1 - _nodeCtrl.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isDark) ...[
                    Positioned.fill(
                      child: CustomPaint(painter: _WebsiteMeshPainter()),
                    ),
                    // Same base geometry as .neon-1 and .neon-2 on the site.
                    Positioned(
                      top: -200 + math.cos(t * math.pi) * 30,
                      right: -100 + math.sin(t * math.pi) * 40,
                      child: _BlurredOrb(
                        size: 600,
                        color: Colors.white,
                        opacity: 0.15,
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
                    Positioned(
                      top: sz.height * .2 - 100 * nodeOne,
                      left: sz.width * .15 + 20 * nodeOne,
                      child: _FloatingNode(
                        opacity: math.sin(math.pi * nodeOne) * .3,
                      ),
                    ),
                    Positioned(
                      bottom: sz.height * .3 + 100 * nodeTwo,
                      right: sz.width * .1 - 20 * nodeTwo,
                      child: _FloatingNode(
                        opacity: math.sin(math.pi * nodeTwo) * .3,
                      ),
                    ),
                  ] else ...[
                    // Website .studio-1, .studio-2 and .studio-3.
                    Positioned(
                      top: sz.height * 0.1,
                      left: -100 + math.sin(t * math.pi) * 30,
                      child: _BlurredOrb(
                        size: 500,
                        color: const Color(0xFF6366F1), // Indigo
                        opacity: 0.12,
                        blur: 80,
                      ),
                    ),
                    Positioned(
                      bottom: sz.height * 0.2,
                      right: -50 - math.cos(t * math.pi) * 30,
                      child: _BlurredOrb(
                        size: 400,
                        color: const Color(0xFF8B5CF6), // Violet
                        opacity: 0.12,
                        blur: 80,
                      ),
                    ),
                    Positioned(
                      top: sz.height * 0.4,
                      left: sz.width * 0.3 + math.sin(t * math.pi * 0.5) * 40,
                      child: _BlurredOrb(
                        size: 300,
                        color: const Color(0xFF06B6D4), // Cyan
                        opacity: 0.12,
                        blur: 80,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          // Content
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
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _FloatingNode extends StatelessWidget {
  const _FloatingNode({required this.opacity});
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity.clamp(0, 1),
    child: Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.white, blurRadius: 15)],
      ),
    ),
  );
}

class _WebsiteMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = const RadialGradient(
        colors: [Color(0x02FFFFFF), Colors.transparent],
        stops: [0.3, 0.7],
      ).createShader(bounds);
    for (double x = 0; x < size.width; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WebsiteMeshPainter oldDelegate) => false;
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
