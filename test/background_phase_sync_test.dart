import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_route.dart';

/// Orb placement as the background lays it out, in page coordinates.
typedef _OrbOffset = ({
  double? top,
  double? bottom,
  double? left,
  double? right,
});

/// The value the old per-page controller reported for `repeat(reverse: true)`:
/// a triangle wave with an 88 s cycle, written independently of
/// [OrbDriftPhase.wave].
double _oldControllerValue(Duration elapsed) {
  const cycleUs = 88000 * 1000;
  final us = elapsed.inMicroseconds % cycleUs;
  return 1 - (1 - 2 * us / cycleUs).abs();
}

List<_OrbOffset> _orbOffsets(WidgetTester tester, Finder background) {
  // Only the animated orb layer, not the static bg-glow Positioned.fill.
  final orbLayer = find.descendant(
    of: background,
    matching: find.byType(AnimatedBuilder),
  );
  final offsets = <_OrbOffset>[];
  for (final element
      in find
          .descendant(of: orbLayer, matching: find.byType(Positioned))
          .evaluate()) {
    final positioned = element.widget as Positioned;
    if (positioned.left == null &&
        positioned.top == null &&
        positioned.right == null &&
        positioned.bottom == null) {
      continue;
    }
    offsets.add((
      top: positioned.top,
      bottom: positioned.bottom,
      left: positioned.left,
      right: positioned.right,
    ));
  }
  return offsets;
}

/// Dark theme orbs as [PremiumBackground] places them for phase [t].
List<_OrbOffset> _darkOrbs(double t) => [
  (
    top: -200 + math.cos(t * math.pi) * 30,
    bottom: null,
    left: null,
    right: -100 + math.sin(t * math.pi) * 40,
  ),
  (
    top: null,
    bottom: -50 - math.sin(t * math.pi) * 40,
    left: -100 + math.cos(t * math.pi) * 30,
    right: null,
  ),
];

/// Light theme orbs as [PremiumBackground] places them for phase [t].
List<_OrbOffset> _lightOrbs(double t, Size size) => [
  (
    top: size.height * 0.1,
    bottom: null,
    left: -100 + math.sin(t * math.pi) * 30,
    right: null,
  ),
  (
    top: null,
    bottom: size.height * 0.2,
    left: null,
    right: -50 - math.cos(t * math.pi) * 30,
  ),
  (
    top: size.height * 0.4,
    bottom: null,
    left: size.width * 0.3 + math.sin(t * math.pi * 0.5) * 40,
    right: null,
  ),
];

Widget _host({required bool dark, required Widget child}) => MaterialApp(
  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  home: child,
);

/// Two full-screen backgrounds, the second one added later.
Widget _stackedHost({
  required bool dark,
  required ValueListenable<bool> showSecond,
}) => _host(
  dark: dark,
  child: ValueListenableBuilder<bool>(
    valueListenable: showSecond,
    builder: (context, show, _) => Stack(
      fit: StackFit.expand,
      children: [
        const PremiumBackground(child: SizedBox.expand()),
        if (show) const PremiumBackground(child: SizedBox.expand()),
      ],
    ),
  ),
);

void _expectOffsets(
  List<_OrbOffset> actual,
  List<_OrbOffset> expected, {
  double tolerance = 0.01,
}) {
  expect(actual, hasLength(expected.length));
  for (var i = 0; i < expected.length; i++) {
    final a = actual[i];
    final e = expected[i];
    for (final (label, got, want) in [
      ('top', a.top, e.top),
      ('bottom', a.bottom, e.bottom),
      ('left', a.left, e.left),
      ('right', a.right, e.right),
    ]) {
      if (want == null) {
        expect(got, isNull, reason: 'orb $i $label');
      } else {
        expect(got, closeTo(want, tolerance), reason: 'orb $i $label');
      }
    }
  }
}

void main() {
  setUp(OrbDriftPhase.reset);

  test('shared phase matches the old controller curve', () {
    const probes = [
      Duration.zero,
      Duration(milliseconds: 1),
      Duration(seconds: 5),
      Duration(seconds: 22),
      Duration(seconds: 43),
      Duration(seconds: 44),
      Duration(seconds: 66),
      Duration(seconds: 88),
      Duration(seconds: 100),
      Duration(minutes: 7, seconds: 13),
      Duration(hours: 3),
    ];
    for (final elapsed in probes) {
      expect(
        OrbDriftPhase.wave(elapsed),
        closeTo(_oldControllerValue(elapsed), 1e-12),
        reason: 'phase at $elapsed',
      );
    }
    expect(OrbDriftPhase.wave(Duration.zero), 0);
    expect(OrbDriftPhase.wave(const Duration(seconds: 44)), 1);
    expect(OrbDriftPhase.wave(const Duration(seconds: 88)), 0);
    expect(OrbDriftPhase.wave(const Duration(seconds: 22)), 0.5);
  });

  testWidgets('a background built later joins the same frame', (tester) async {
    final showSecond = ValueNotifier(false);
    addTearDown(showSecond.dispose);

    await tester.pumpWidget(_stackedHost(dark: true, showSecond: showSecond));
    await tester.pump(const Duration(seconds: 7));
    showSecond.value = true;
    await tester.pump();

    final first = _orbOffsets(tester, find.byType(PremiumBackground).at(0));
    final second = _orbOffsets(tester, find.byType(PremiumBackground).at(1));
    expect(first, hasLength(2));
    expect(second, first);
    // Not the old per-page behaviour: a fresh background starts at t = 0.
    expect(
      first,
      isNot(_darkOrbs(0)),
      reason: 'a late background must not restart the drift',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'iOS push keeps both pages on the same orb frame',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.darkTheme,
          home: const PremiumBackground(child: SizedBox.expand()),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      final beforePush = _orbOffsets(tester, find.byType(PremiumBackground));

      navigatorKey.currentState!.push(
        appRoute(const PremiumBackground(child: SizedBox.expand())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(PremiumBackground), findsNWidgets(2));

      var previous = beforePush;
      var samples = 0;
      // The route underneath goes offstage once the 360 ms push settles, so
      // sample only the frames where both pages are on screen.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final backgrounds = find.byType(PremiumBackground);
        if (backgrounds.evaluate().length != 2) break;
        final under = _orbOffsets(tester, backgrounds.at(0));
        final over = _orbOffsets(tester, backgrounds.at(1));
        expect(over, under, reason: 'frame $i during the push');
        for (var orb = 0; orb < under.length; orb++) {
          for (final (label, got, want) in [
            ('top', under[orb].top, previous[orb].top),
            ('bottom', under[orb].bottom, previous[orb].bottom),
            ('left', under[orb].left, previous[orb].left),
            ('right', under[orb].right, previous[orb].right),
          ]) {
            if (got == null || want == null) continue;
            expect(
              (got - want).abs(),
              lessThanOrEqualTo(2),
              reason: 'orb $orb $label jumped at frame $i',
            );
          }
        }
        previous = under;
        samples++;
      }
      expect(samples, greaterThanOrEqualTo(6));

      // Pop: the page underneath is revealed without a phase jump, and once the
      // transition ends the phase follows the shared clock.
      navigatorKey.currentState!.pop();
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final backgrounds = find.byType(PremiumBackground);
        if (backgrounds.evaluate().length == 2) {
          expect(
            _orbOffsets(tester, backgrounds.at(1)),
            _orbOffsets(tester, backgrounds.at(0)),
            reason: 'frame $i during the pop',
          );
        }
      }
      await tester.pump(const Duration(milliseconds: 100));

      final remaining = find.byType(PremiumBackground);
      expect(remaining, findsOneWidget);
      final t = OrbDriftPhase.wave(OrbDriftPhase.elapsed());
      expect(t, greaterThan(0), reason: 'the shared clock keeps running');
      _expectOffsets(
        _orbOffsets(tester, remaining),
        _darkOrbs(t),
        tolerance: 0.5,
      );
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('reduced motion holds one fixed phase', (tester) async {
    await tester.pumpWidget(
      _host(
        dark: true,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const PremiumBackground(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final settled = _orbOffsets(tester, find.byType(PremiumBackground));
    _expectOffsets(settled, _darkOrbs(0));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    expect(_orbOffsets(tester, find.byType(PremiumBackground)), settled);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  for (final dark in [true, false]) {
    for (final seconds in [0, 22]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} theme at ${seconds}s matches the old formula',
        (tester) async {
          await tester.pumpWidget(
            _host(
              dark: dark,
              child: const PremiumBackground(child: SizedBox.expand()),
            ),
          );
          await tester.pump(Duration(seconds: seconds));

          final size = tester.getSize(find.byType(PremiumBackground));
          final t = _oldControllerValue(Duration(seconds: seconds));
          _expectOffsets(
            _orbOffsets(tester, find.byType(PremiumBackground)),
            dark ? _darkOrbs(t) : _lightOrbs(t, size),
          );
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
