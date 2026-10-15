import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('interaction overlay stays subtle in both color modes', () {
    final darkOverlay = AppTheme.interactionOverlay(isDark: true);
    final lightOverlay = AppTheme.interactionOverlay(isDark: false);

    expect(
      darkOverlay.resolve({WidgetState.hovered}),
      Colors.white.withValues(alpha: .055),
    );
    expect(
      darkOverlay.resolve({WidgetState.focused}),
      Colors.white.withValues(alpha: .09),
    );
    expect(
      lightOverlay.resolve({WidgetState.hovered}),
      Colors.black.withValues(alpha: .055),
    );
    expect(lightOverlay.resolve({WidgetState.pressed}), Colors.transparent);
  });

  testWidgets('language pill matches the compact committed design', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 568),
              textScaler: TextScaler.noScaling,
            ),
            child: SettingsScreen(),
          ),
        ),
      ),
    );

    final englishPillSize = tester.getSize(
      find.descendant(
        of: find.byKey(const ValueKey('language-en')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(englishPillSize, const Size(32.5, 24));
    expect(
      tester.getSize(find.byKey(const ValueKey('language-options'))).width,
      105.5,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'language options expose selected semantics and scale with text',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: SettingsScreen(),
            ),
          ),
        ),
      );

      final english = tester.getSemantics(
        find.byKey(const ValueKey('language-en')),
      );
      expect(
        english.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(english.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(english.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      final englishPillSize = tester.getSize(
        find.descendant(
          of: find.byKey(const ValueKey('language-en')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(englishPillSize.width, greaterThan(28));
      expect(englishPillSize.height, greaterThan(24));

      await tester.tap(find.byKey(const ValueKey('language-es')));
      await tester.pump();
      final spanish = tester.getSemantics(
        find.byKey(const ValueKey('language-es')),
      );
      expect(
        spanish.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );

      final systemTheme = tester.getSemantics(find.bySemanticsLabel('System'));
      expect(
        systemTheme.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(systemTheme.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(systemTheme.rect.width, greaterThanOrEqualTo(48));
      expect(systemTheme.rect.height, greaterThanOrEqualTo(48));

      await tester.tap(find.bySemanticsLabel('Light'));
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Light'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    testWidgets(
      'theme options support hover and keyboard on $platform',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme.copyWith(platform: platform),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 568),
                  disableAnimations: true,
                ),
                child: SettingsScreen(),
              ),
            ),
          ),
        );

        final systemOption = find.descendant(
          of: find.bySemanticsLabel('System'),
          matching: find.byType(InkWell),
        );
        final systemInkWell = tester.widget<InkWell>(systemOption);
        expect(systemInkWell.mouseCursor, SystemMouseCursors.click);
        expect(
          systemInkWell.overlayColor!.resolve({WidgetState.hovered}),
          isNot(Colors.transparent),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Light'))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
