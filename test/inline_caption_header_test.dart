import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/inline_feedback.dart';
import 'package:oculve/features/settings/presentation/connection_settings_widgets.dart';

const _message = 'Could not reach the service securely. Check your connection.';

void main() {
  testWidgets('a group failure replaces its heading without moving anything', (
    tester,
  ) async {
    final errors = InlineErrorController();
    addTearDown(errors.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ListView(
            children: [
              SettingsCaption('DNS', errors: errors),
              const SettingRow(key: ValueKey('row'), title: 'Provider'),
            ],
          ),
        ),
      ),
    );
    final rowBefore = tester.getTopLeft(find.byKey(const ValueKey('row')));
    expect(find.text('DNS'), findsOneWidget);

    errors.show(_message);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getTopLeft(find.byKey(const ValueKey('row'))), rowBefore);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(_message), findsOneWidget);
    expect(find.text('DNS'), findsNothing);
    expect(tester.getTopLeft(find.byKey(const ValueKey('row'))), rowBefore);

    // After long enough to read it, the heading fades back in.
    await tester.pump(const Duration(seconds: 9));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(_message), findsNothing);
    expect(find.text('DNS'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('row'))), rowBefore);
  });

  testWidgets('a page message replaces the header title, body stays put', (
    tester,
  ) async {
    final feedback = InlineErrorController();
    addTearDown(feedback.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: AppPage(
          title: 'Account',
          feedback: feedback,
          child: const Align(
            alignment: Alignment.topLeft,
            child: Text('body', key: ValueKey('body')),
          ),
        ),
      ),
    );
    final bodyBefore = tester.getTopLeft(find.byKey(const ValueKey('body')));
    expect(find.text('Account'), findsOneWidget);

    feedback.showMessage('Access code copied.');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid cross-fade: neither jumped nor popped.
    expect(tester.getTopLeft(find.byKey(const ValueKey('body'))), bodyBefore);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Access code copied.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.text('Account'), findsNothing);

    await tester.pump(const Duration(seconds: 9));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Access code copied.'), findsNothing);

    feedback.show(_message);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('body'))), bodyBefore);
    feedback.clear();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Account'), findsOneWidget);
  });

  test('the rollback switch is on', () => expect(kInlineFeedback, isTrue));
}
