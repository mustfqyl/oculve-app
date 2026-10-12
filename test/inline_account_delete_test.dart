import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/settings/presentation/inline_account_delete.dart';

void main() {
  testWidgets(
    'exact phrase waits ten seconds and only final tap deletes once',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: InlineAccountDelete(
              onDelete: () async {
                calls++;
                await pending.future;
              },
            ),
          ),
        ),
      );
      final originalHeight = tester
          .getSize(find.byType(InlineAccountDelete))
          .height;
      final idlePaintHeight = tester
          .getSize(
            find
                .descendant(
                  of: find.byKey(const ValueKey('account-delete-start')),
                  matching: find.byType(Material),
                )
                .first,
          )
          .height;
      expect(idlePaintHeight, 40);
      await tester.tap(find.byKey(const ValueKey('account-delete-start')));
      await tester.pump();
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      await tester.enterText(field, 'delete my account');
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(field, 'DELETE MY ACCOUNT');
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byType(Dialog), findsNothing);
      final confirm = find.byKey(const ValueKey('account-delete-confirm'));
      expect(tester.widget<OutlinedButton>(confirm).onPressed, isNull);
      expect(
        tester
            .getSize(
              find
                  .descendant(of: confirm, matching: find.byType(Material))
                  .first,
            )
            .height,
        idlePaintHeight,
      );
      await tester.pump(const Duration(seconds: 9));
      expect(tester.widget<OutlinedButton>(confirm).onPressed, isNull);
      expect(calls, 0);
      await tester.pump(const Duration(milliseconds: 1020));
      await tester.pump();
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(
        tester.getSize(find.byType(InlineAccountDelete)).height,
        originalHeight,
      );
      await tester.tap(confirm);
      await tester.tap(confirm);
      await tester.pump();
      expect(calls, 1);
      pending.complete();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('account-delete-start')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('outside tap cancels input and backgrounding cancels countdown', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: InlineAccountDelete(
                onDelete: () async {
                  calls++;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('account-delete-start')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('account-delete-start')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'DELETE MY ACCOUNT');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 20));
    expect(find.byKey(const ValueKey('account-delete-start')), findsOneWidget);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
