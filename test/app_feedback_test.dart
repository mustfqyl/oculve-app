import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_feedback.dart';

void main() {
  tearDown(AppFeedback.dismiss);
  test('technical and server errors become readable user messages', () {
    expect(
      AppFeedback.errorMessage(const ApiFailure('TOO_MANY_ATTEMPTS', 429)),
      'Too many attempts. Please wait and try again.',
    );
    expect(
      AppFeedback.errorMessage(const ApiFailure('UPSTREAM_FAILURE', 503)),
      'The service is temporarily unavailable. Please try again.',
    );
    expect(
      AppFeedback.errorMessage(StateError('INTERNAL_STATE_42')),
      'Something went wrong. Please try again.',
    );
  });

  testWidgets('floating errors do not move the page or expose error codes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const actionKey = ValueKey('feedback-test-action');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => FilledButton(
                key: actionKey,
                onPressed: () => AppFeedback.showError(
                  context,
                  const ApiFailure('AUTH_ERROR_52', 401),
                ),
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ),
    );
    final before = tester.getRect(find.byKey(actionKey));

    await tester.tap(find.byKey(actionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text(
        'Your access code or session is invalid. Please sign in again.',
      ),
      findsOneWidget,
    );
    expect(find.text('AUTH_ERROR_52'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.byKey(const ValueKey('feedback-progress')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final initialProgress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    await tester.pump(const Duration(seconds: 1));
    final updatedProgress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(updatedProgress.value, lessThan(initialProgress.value!));
    expect(tester.getRect(find.byKey(actionKey)), before);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(Dismissible), const Offset(-400, 0));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text(
        'Your access code or session is invalid. Please sign in again.',
      ),
      findsNothing,
    );
    expect(tester.getRect(find.byKey(actionKey)), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home errors use the shared header anchor without moving the connection art',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => AppFeedback.showError(
                    context,
                    'Could not establish the VPN. Check your account, VPN permission and server availability.',
                    placement: AppFeedbackPlacement.home,
                  ),
                  child: const Text('Try again'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final notification = tester.getRect(find.byType(Dismissible));
      expect(notification.top, 76);
      expect(notification.bottom, lessThan(220));
      expect(
        tester.getRect(find.text('Try again')).center.dy,
        greaterThan(300),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('full-page error actions fit a short desktop window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AppErrorState(
            title: 'Unable to load your account',
            message: List.filled(80, 'A long service message').join(' '),
            primaryLabel: 'Retry',
            onPrimary: () {},
            secondaryLabel: 'Sign in again',
            onSecondary: () {},
          ),
        ),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Sign in again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
