import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/theme/app_theme.dart';

class _PaintCounter extends CustomPainter {
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
  }

  @override
  bool shouldRepaint(covariant _PaintCounter oldDelegate) => false;
}

void main() {
  testWidgets('reduced motion background settles without continuous frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const PremiumBackground(child: SizedBox()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background drift does not repaint unchanged page content', (
    tester,
  ) async {
    final counter = _PaintCounter();
    await tester.pumpWidget(
      MaterialApp(
        home: PremiumBackground(
          child: CustomPaint(painter: counter, child: const SizedBox.expand()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final settledPaints = counter.paints;
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(counter.paints, settledPaints);
    await tester.pumpWidget(const SizedBox());
  });
}
