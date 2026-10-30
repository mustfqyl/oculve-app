import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_feedback.dart';

const _message = 'VPN permission was not granted.';
const _notice = ValueKey('feedback-card');

void main() {
  tearDown(AppFeedback.dismiss);

  test('unknown payloads never become visible error codes or raw exceptions', () {
    for (final error in <Object>[
      'request failed: auth_error_52',
      'HttpException: 400 POST /api/private',
      const ApiFailure('Unexpected upstream message: INTERNAL_FAULT_55'),
      Exception('PlatformException(FATAL, /Users/private, token=secret)'),
      PlatformException(code: 'native_code_001'),
    ]) {
      expect(
        AppFeedback.errorMessage(error),
        'Something went wrong. Please try again.',
      );
    }
    expect(
      AppFeedback.errorMessage(const ApiFailure('bad_code', 400)),
      'The service rejected this request. Check your details and try again.',
    );
    expect(AppFeedback.errorMessage(StateError(_message)), _message);
    expect(
      AppFeedback.errorMessage(const FormatException('Invalid domain: secret')),
      'Enter valid website domains, such as example.com.',
    );
    expect(
      AppFeedback.errorMessage(TimeoutException('secret')),
      'Could not connect to the service. Check your internet connection and try again.',
    );
  });

  test('new recovery messages have Turkish and Spanish translations', () {
    for (final message in [
      AppFeedback.errorMessage(const ApiFailure('bad_code', 400)),
      AppFeedback.errorMessage(const ApiFailure('bad_code', 401)),
      AppFeedback.errorMessage(const ApiFailure('bad_code', 403)),
      AppFeedback.errorMessage(const FormatException('Invalid domain: secret')),
      'Statistics unavailable',
    ]) {
      for (final language in ['tr', 'es']) {
        expect(
          AppStrings.hasTranslation(message, language),
          isTrue,
          reason: '$language: $message',
        );
      }
    }
  });

  testWidgets(
    'all screens share an anchor and swipe dismissal keeps controls still',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late BuildContext owner;
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          navigatorObservers: [AppFeedbackNavigatorObserver()],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                owner = context;
                return Center(
                  child: TextButton(
                    key: const ValueKey('unchanged-action'),
                    onPressed: () => taps++,
                    child: const Text('Continue'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      final original = tester.getRect(
        find.byKey(const ValueKey('unchanged-action')),
      );
      Rect? anchor;
      for (final placement in AppFeedbackPlacement.values) {
        AppFeedback.showError(owner, _message, placement: placement);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final rect = tester.getRect(find.byKey(_notice));
        expect(rect.left, 16);
        expect(rect.right, 304);
        expect(rect.top, 76);
        expect(rect, anchor ?? rect);
        anchor = rect;
        expect(
          tester.getRect(find.byKey(const ValueKey('unchanged-action'))),
          original,
        );
        await tester.tap(find.byKey(const ValueKey('unchanged-action')));
        await tester.drag(
          find.byKey(const ValueKey('feedback-card')),
          const Offset(-500, 0),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byKey(_notice), findsNothing);
      }
      expect(taps, 4); // The overlay does not intercept taps outside its card.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('repeated failures expire without extending their lifetime', (
    tester,
  ) async {
    late BuildContext owner;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              owner = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    AppFeedback.showError(owner, _message);
    await tester.pump();
    // The visible time scales with the message (4.5-8 s), then it fades out
    // over 380 ms. A repeat must not restart that clock.
    await tester.pump(const Duration(seconds: 4));
    AppFeedback.showError(owner, _message);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(_notice), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'navigation clears errors and rejects late results from a covered screen',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      late BuildContext owner;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [AppFeedbackNavigatorObserver()],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                owner = context;
                return const Text('First screen');
              },
            ),
          ),
        ),
      );
      AppFeedback.showError(owner, _message);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_notice), findsOneWidget);
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Second screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_notice), findsNothing);
      AppFeedback.showError(owner, _message);
      await tester.pump();
      expect(find.byKey(_notice), findsNothing);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_notice), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dialog feedback closes with the dialog and never returns behind it',
    (tester) async {
      late BuildContext owner;
      late BuildContext dialogOwner;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [AppFeedbackNavigatorObserver()],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                owner = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      AppFeedback.showError(owner, _message);
      await tester.pump();
      unawaited(
        showDialog<void>(
          context: owner,
          builder: (context) {
            dialogOwner = context;
            return const AlertDialog(title: Text('Confirm'));
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_notice), findsNothing);
      AppFeedback.showMessage(dialogOwner, 'Setup key copied.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Setup key copied.'), findsOneWidget);
      Navigator.of(dialogOwner).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_notice), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replacing a notice while it dismisses cannot remove the new notice',
    (tester) async {
      late BuildContext owner;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                owner = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      AppFeedback.showError(owner, _message);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.drag(
        find.byKey(const ValueKey('feedback-card')),
        const Offset(-500, 0),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      AppFeedback.showError(owner, 'Your subscription is not active.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your subscription is not active.'), findsOneWidget);
      expect(find.text(_message), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('removing the originating widget cleans up its notice', (
    tester,
  ) async {
    late BuildContext owner;
    late StateSetter rebuild;
    var visible = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return visible
                  ? Builder(
                      builder: (context) {
                        owner = context;
                        return const Text('Owner');
                      },
                    )
                  : const Text('Replacement');
            },
          ),
        ),
      ),
    );
    AppFeedback.showError(owner, _message);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    rebuild(() => visible = false);
    await tester.pumpAndSettle();
    expect(find.byKey(_notice), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final language in ['en', 'tr', 'es']) {
      testWidgets(
        'notice fits keyboard and large text in $language, dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          late BuildContext owner;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 260),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: Localizations.override(
                  context: context,
                  locale: Locale(language),
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    owner = context;
                    return const Center(child: Text('Form'));
                  },
                ),
              ),
            ),
          );
          const message =
              'Could not establish the VPN. Check your account, VPN permission and server availability.';
          AppFeedback.showError(owner, message);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          final rect = tester.getRect(find.byKey(_notice));
          expect(rect.left, greaterThanOrEqualTo(16));
          expect(rect.right, lessThanOrEqualTo(304));
          expect(rect.top, greaterThanOrEqualTo(24));
          expect(rect.bottom, lessThanOrEqualTo(292));
          expect(
            find.text(AppStrings.translate(message, language)),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.close_rounded), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byKey(const ValueKey('feedback-card')),
            const Offset(-500, 0),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.byKey(_notice), findsNothing);
        },
      );
    }
  }
}
