import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/inline_feedback.dart';

void main() {
  inlineErrorOfTests();
  Widget host(String? message, {bool reduceMotion = false}) => MaterialApp(
    theme: AppTheme.darkTheme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Column(
          children: [
            const Text('field', key: ValueKey('field')),
            InlineErrorSlot(message: message),
            const Text('button', key: ValueKey('button')),
          ],
        ),
      ),
    ),
  );

  testWidgets('the slot keeps its height with and without a message', (
    tester,
  ) async {
    await tester.pumpWidget(host(null));
    final buttonBefore = tester
        .getTopLeft(find.byKey(const ValueKey('button')))
        .dy;
    await tester.pumpWidget(host('Could not reach the service securely.'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('button'))).dy,
      buttonBefore,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('button'))).dy,
      buttonBefore,
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('the message fades out through intermediate opacity', (
    tester,
  ) async {
    await tester.pumpWidget(host('Could not reach the service securely.'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(host(null));
    await tester.pump(const Duration(milliseconds: 100));
    final opacities = tester
        .widgetList<FadeTransition>(
          find.descendant(
            of: find.byType(InlineErrorSlot),
            matching: find.byType(FadeTransition),
          ),
        )
        .map((f) => f.opacity.value);
    expect(opacities.any((o) => o > 0 && o < 1), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
  });

  testWidgets('reduced motion swaps without a transition', (tester) async {
    await tester.pumpWidget(host(null, reduceMotion: true));
    await tester.pumpWidget(
      host('Could not reach the service securely.', reduceMotion: true),
    );
    await tester.pump();
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    await tester.pumpWidget(host(null, reduceMotion: true));
    await tester.pump();
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
  });
}

void inlineErrorOfTests() {
  testWidgets('a controller failure appears and fades out on its own', (
    tester,
  ) async {
    final controller = InlineErrorController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Column(
            children: [
              InlineErrorOf(controller),
              const Text('below', key: ValueKey('below')),
            ],
          ),
        ),
      ),
    );
    final before = tester.getTopLeft(find.byKey(const ValueKey('below'))).dy;

    // No setState anywhere: the widget listens to the controller itself.
    controller.show(
      'Could not reach the service securely. Check your connection.',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('below'))).dy, before);

    // The message clears itself after long enough to read, then fades away.
    await tester.pump(const Duration(seconds: 9));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    expect(tester.getTopLeft(find.byKey(const ValueKey('below'))).dy, before);
  });
}
