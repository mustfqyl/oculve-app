import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('home header actions expose 48px semantic touch targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: HomeScreen(),
          ),
        ),
      ),
    );
    final targets = find.byWidgetPredicate(
      (widget) =>
          widget is InkWell &&
          widget.onTap != null &&
          widget.child is SizedBox &&
          (widget.child as SizedBox).width == 48 &&
          (widget.child as SizedBox).height == 48,
    );
    expect(targets, findsNWidgets(2));

    for (final label in ['Account', 'Settings']) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.rect.width, greaterThanOrEqualTo(48));
      expect(node.rect.height, greaterThanOrEqualTo(48));
    }
    expect(tester.getSize(targets.first), const Size(48, 48));
    expect(tester.getSize(targets.last), const Size(48, 48));
    final accountAction = tester.widget<InkWell>(targets.first);
    expect(accountAction.mouseCursor, SystemMouseCursors.click);
    expect(
      accountAction.overlayColor!.resolve({WidgetState.hovered}),
      isNot(Colors.transparent),
    );
    final serverSelector = find.byWidgetPredicate(
      (widget) =>
          widget is InkWell &&
          widget.onTap != null &&
          widget.child is! SizedBox,
    );
    expect(serverSelector, findsOneWidget);
    expect(tester.getSize(serverSelector).height, greaterThanOrEqualTo(48));
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    testWidgets(
      'home header actions support keyboard on $platform',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme.copyWith(platform: platform),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 568),
                  textScaler: TextScaler.noScaling,
                  disableAnimations: true,
                ),
                child: HomeScreen(),
              ),
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
          isTrue,
        );
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
