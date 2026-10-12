import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/providers/animation_provider.dart';
import 'package:oculve/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('page animation preference can be turned off and is saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final toggle = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Page animations'),
    );
    expect(toggle.value, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(
      find.byWidgetPredicate((widget) {
        return widget is SwitchListTile && !widget.value;
      }),
      findsOneWidget,
    );
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'app_page_animations_enabled',
      ),
      isFalse,
    );
  });

  test('stored page animation preference is restored', () async {
    SharedPreferences.setMockInitialValues({
      'app_page_animations_enabled': false,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(pageAnimationsProvider), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pageAnimationsProvider), isFalse);
  });
}
