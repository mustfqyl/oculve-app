import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A quiet, animated interpretation of Oculve's name: a veil opening onto a
/// private space. The artwork is decorative; the setup action stays in the
/// page footer so the onboarding remains easy to understand.
class OculveVeilArtwork extends StatelessWidget {
  const OculveVeilArtwork({
    super.key,
    required this.progress,
    required this.dark,
  });

  final Animation<double> progress;
  final bool dark;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'A veil slowly opening onto a private connection',
    image: true,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => CustomPaint(
          painter: _VeilPainter(progress.value, dark),
          size: Size.infinite,
        ),
      ),
    ),
  );
}

class _VeilPainter extends CustomPainter {
  const _VeilPainter(this.progress, this.dark);

  final double progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = math.min(size.width / 280, size.height / 188);
    final center = Offset(size.width / 2, size.height * .51);
    final drift = math.sin(progress * math.pi * 2);
    final ink = dark ? Colors.white : const Color(0xFF09090B);
    final glow = dark ? const Color(0xFFDCE8F2) : const Color(0xFF64748B);
    final portalWidth = 52 * scale;
    final portalHeight = 116 * scale;

    final haze = Paint()
      ..shader = RadialGradient(
        colors: [
          glow.withValues(alpha: dark ? .14 : .09),
          glow.withValues(alpha: dark ? .045 : .025),
          Colors.transparent,
        ],
        stops: const [0, .45, 1],
      ).createShader(Rect.fromCircle(center: center, radius: 112 * scale));
    canvas.drawCircle(center, 112 * scale, haze);

    // Fine orbital lines create depth without turning the mark into an eye icon.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(drift * .035);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale
      ..color = ink.withValues(alpha: dark ? .13 : .12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: 168 * scale,
        height: 145 * scale,
      ),
      orbitPaint,
    );
    final outerOrbit = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 216 * scale,
          height: 154 * scale,
        ),
      );
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale
      ..color = ink.withValues(alpha: dark ? .21 : .17);
    for (final metric in outerOrbit.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 17 * scale) {
        canvas.drawPath(
          metric.extractPath(
            offset,
            math.min(offset + 3 * scale, metric.length),
          ),
          dashPaint,
        );
      }
    }
    canvas.restore();

    // The dark opening is a narrow portal, with a light that breathes behind it.
    final portalRect = Rect.fromCenter(
      center: center.translate(0, drift * 1.8 * scale),
      width: portalWidth + drift * 2 * scale,
      height: portalHeight,
    );
    final portalRRect = RRect.fromRectAndRadius(
      portalRect,
      Radius.circular(portalWidth),
    );
    canvas.drawRRect(
      portalRRect,
      Paint()
        ..color = (dark ? const Color(0xFF050607) : const Color(0xFF191C20))
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF161A1F), Color(0xFF030405), Color(0xFF11161A)]
              : const [Color(0xFF737D87), Color(0xFF454D56), Color(0xFF626C76)],
        ).createShader(portalRect),
    );
    canvas.drawRRect(
      portalRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15 * scale
        ..color = ink.withValues(alpha: dark ? .75 : .52),
    );

    canvas.save();
    canvas.clipRRect(portalRRect);
    final innerGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -.15),
        radius: .9,
        colors: [
          glow.withValues(alpha: .2 + progress * .06),
          Colors.transparent,
        ],
      ).createShader(portalRect);
    canvas.drawRect(portalRect, innerGlow);
    final seam = Paint()
      ..shader =
          LinearGradient(
            colors: [
              Colors.transparent,
              ink.withValues(alpha: dark ? .7 : .52),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCenter(
              center: center,
              width: 2.4 * scale,
              height: portalHeight * .78,
            ),
          );
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: 2.4 * scale,
        height: portalHeight * .78,
      ),
      seam,
    );
    for (var i = 0; i < 5; i++) {
      final y = portalRect.top + portalHeight * (.19 + i * .14);
      final xShift = math.sin(progress * math.pi * 2 + i * 1.7) * 5 * scale;
      canvas.drawCircle(
        Offset(center.dx + xShift, y),
        (i.isEven ? 1.2 : .75) * scale,
        Paint()..color = ink.withValues(alpha: dark ? .75 : .64),
      );
    }
    canvas.restore();

    // Two soft, folded panels part around the opening like a moving veil.
    final halfGap =
        portalWidth * (.66 + .035 * math.sin(progress * math.pi * 2));
    final top = center.dy - portalHeight * .52;
    final bottom = center.dy + portalHeight * .52;
    final leftCurtain = Path()
      ..moveTo(center.dx - 127 * scale, top - 10 * scale)
      ..lineTo(center.dx - halfGap, top)
      ..cubicTo(
        center.dx - halfGap - 13 * scale,
        center.dy - 15 * scale,
        center.dx - halfGap - 3 * scale,
        center.dy + 33 * scale,
        center.dx - halfGap,
        bottom,
      )
      ..lineTo(center.dx - 127 * scale, bottom + 10 * scale)
      ..cubicTo(
        center.dx - 105 * scale,
        center.dy + 17 * scale,
        center.dx - 110 * scale,
        center.dy - 24 * scale,
        center.dx - 127 * scale,
        top - 10 * scale,
      )
      ..close();
    final rightCurtain = Path()
      ..moveTo(center.dx + 127 * scale, top - 10 * scale)
      ..lineTo(center.dx + halfGap, top)
      ..cubicTo(
        center.dx + halfGap + 13 * scale,
        center.dy - 15 * scale,
        center.dx + halfGap + 3 * scale,
        center.dy + 33 * scale,
        center.dx + halfGap,
        bottom,
      )
      ..lineTo(center.dx + 127 * scale, bottom + 10 * scale)
      ..cubicTo(
        center.dx + 105 * scale,
        center.dy + 17 * scale,
        center.dx + 110 * scale,
        center.dy - 24 * scale,
        center.dx + 127 * scale,
        top - 10 * scale,
      )
      ..close();
    final curtainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? [
                Colors.white.withValues(alpha: .13),
                Colors.white.withValues(alpha: .035),
                Colors.white.withValues(alpha: .09),
              ]
            : [
                Colors.black.withValues(alpha: .11),
                Colors.black.withValues(alpha: .025),
                Colors.black.withValues(alpha: .075),
              ],
      ).createShader(Rect.fromLTRB(0, top, size.width, bottom));
    canvas.drawPath(leftCurtain, curtainPaint);
    canvas.drawPath(rightCurtain, curtainPaint);

    final foldPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8 * scale
      ..color = ink.withValues(alpha: dark ? .2 : .14);
    canvas.save();
    canvas.clipPath(leftCurtain);
    for (var i = 0; i < 5; i++) {
      final x = center.dx - (115 - i * 21) * scale;
      final path = Path()
        ..moveTo(x, top - 4 * scale)
        ..cubicTo(
          x + 8 * scale,
          center.dy - 20 * scale,
          x - 8 * scale,
          center.dy + 25 * scale,
          x + 2 * scale,
          bottom + 4 * scale,
        );
      canvas.drawPath(path, foldPaint);
    }
    canvas.restore();
    canvas.save();
    canvas.clipPath(rightCurtain);
    for (var i = 0; i < 5; i++) {
      final x = center.dx + (115 - i * 21) * scale;
      final path = Path()
        ..moveTo(x, top - 4 * scale)
        ..cubicTo(
          x - 8 * scale,
          center.dy - 20 * scale,
          x + 8 * scale,
          center.dy + 25 * scale,
          x - 2 * scale,
          bottom + 4 * scale,
        );
      canvas.drawPath(path, foldPaint);
    }
    canvas.restore();

    // A restrained horizon makes the portal feel suspended rather than floating.
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, portalHeight * .64),
        width: 145 * scale,
        height: 10 * scale,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                ink.withValues(alpha: dark ? .16 : .1),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCenter(
                center: center.translate(0, portalHeight * .64),
                width: 145 * scale,
                height: 10 * scale,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant _VeilPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dark != dark;
}
