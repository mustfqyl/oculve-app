import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/features/settings/presentation/connection_settings_widgets.dart';

void main() {
  testWidgets('restore requires a second press within three seconds', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsRestoreButton(
            onRestore: () async {
              calls++;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Restore defaults'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, 0);
    expect(find.byKey(const ValueKey('confirm')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('confirm')), findsNothing);
    expect(calls, 0);
    await tester.tap(find.text('Restore defaults'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Restore defaults'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, 1);
    expect(find.byKey(const ValueKey(true)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey(true)), findsNothing);
  });
  testWidgets('failed restore never shows success', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsRestoreButton(onRestore: () async => false),
        ),
      ),
    );
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Restore defaults'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey(true)), findsNothing);
    expect(find.byKey(const ValueKey('confirm')), findsNothing);
  });
}
