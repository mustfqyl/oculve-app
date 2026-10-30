import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/splash/presentation/loading_screen.dart';

/// The native launch screen follows the phone's appearance. The loading screen
/// must start in that same look, then ease over to the app's own theme.
void main() {
  Widget host({
    required ThemeData theme,
    required Brightness system,
    bool reduceMotion = false,
  }) => MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        platformBrightness: system,
        disableAnimations: reduceMotion,
      ),
      child: const LoadingScreen(),
    ),
  );

  Color topColor(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    return ((box.decoration! as BoxDecoration).gradient! as LinearGradient)
        .colors
        .first;
  }

  const darkTop = Color(0xFF252525);
  const lightTop = Color(0xFFFFFFFF);

  testWidgets('a light app on a dark phone starts dark, then eases to light', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(theme: AppTheme.lightTheme, system: Brightness.dark),
    );
    expect(topColor(tester), darkTop, reason: 'matches the dark launch screen');

    await tester.pump(const Duration(milliseconds: 100));
    expect(topColor(tester), darkTop);

    await tester.pump(const Duration(milliseconds: 400));
    expect(topColor(tester), lightTop);
    // Halfway through the fade it is neither: it blends, it does not jump.
    await tester.pump(const Duration(milliseconds: 200));
    final blended = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.gradient)
        .whereType<LinearGradient>()
        .map((g) => g.colors.first)
        .toList();
    expect(blended.any((c) => c != darkTop && c != lightTop), isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('when the phone and the app agree nothing changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(theme: AppTheme.darkTheme, system: Brightness.dark),
    );
    expect(topColor(tester), darkTop);
    await tester.pump(const Duration(seconds: 2));
    expect(topColor(tester), darkTop);

    await tester.pumpWidget(
      host(theme: AppTheme.lightTheme, system: Brightness.light),
    );
    await tester.pump(const Duration(milliseconds: 400)); // theme animation
    expect(topColor(tester), lightTop);
    await tester.pump(const Duration(seconds: 2));
    expect(topColor(tester), lightTop);
  });

  testWidgets('reduced motion switches at once, without a fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        theme: AppTheme.lightTheme,
        system: Brightness.dark,
        reduceMotion: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(topColor(tester), lightTop);
    final animated = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(animated.duration, Duration.zero);
  });
}
