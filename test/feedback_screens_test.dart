import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_scroll_behavior.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/auth/presentation/login_screen.dart';
import 'package:oculve/features/auth/presentation/signup_screen.dart';
import 'package:oculve/features/home/presentation/home_screen.dart';
import 'package:oculve/features/settings/presentation/account_screen.dart';
import 'package:oculve/features/settings/presentation/settings_screen.dart';
import 'package:oculve/features/settings/presentation/usage_statistics_screen.dart';
import 'package:oculve/features/settings/presentation/xray_core_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineApi extends OculveApi {
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async => throw const ApiFailure('UPSTREAM_ERROR_503', 503);
}

class _ScreenSession extends SessionController {
  _ScreenSession() : super(_OfflineApi()) {
    state = AsyncValue.data(
      Account({
        'status': 'active',
        'plan': 'Premium',
        'authCode': 'ABCD-EFGH-IJKL',
        'createdAt': '2026-10-11T12:00:00Z',
        'expiresAt': '2026-11-11T12:00:00Z',
        'devices': [
          {'id': 'preview-device'},
        ],
        'usage': Platform.environment['OCULVE_ACCOUNT_REFERENCE'] == '1'
            ? {'usedGB': 0.0}
            : {'usedGB': 2.5, 'limitGB': 50},
      }, const []),
    );
  }
  @override
  Future<void> refreshAccount() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AppFeedback.dismiss);
  setUpAll(() async {
    for (final family in [
      'Outfit',
      'Ahem',
      'Roboto',
      '.AppleSystemUIFont',
      'monospace',
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/Outfit.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  const pages = <(String, Widget)>[
    ('home', HomeScreen()),
    ('login', LoginScreen()),
    ('signup', SignUpScreen()),
    ('settings', SettingsScreen()),
    ('account', AccountScreen()),
    ('connection-settings', XrayCoreSettingsScreen()),
    ('statistics', UsageStatisticsScreen()),
  ];
  for (final (name, screen) in pages) {
    for (final dark in [false, true]) {
      testWidgets(
        '$name handles readable errors without layout changes, dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                apiProvider.overrideWithValue(_OfflineApi()),
                sessionProvider.overrideWith((ref) => _ScreenSession()),
              ],
              child: RepaintBoundary(
                key: boundaryKey,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                  locale: Locale(
                    Platform.environment['OCULVE_ACCOUNT_REFERENCE'] == '1'
                        ? 'en'
                        : 'tr',
                  ),
                  supportedLocales: const [
                    Locale('en'),
                    Locale('tr'),
                    Locale('es'),
                  ],
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  navigatorObservers: [AppFeedbackNavigatorObserver()],
                  scrollBehavior: const AppScrollBehavior().copyWith(
                    scrollbars: false,
                  ),
                  home: screen,
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          final pageFinder = find.byWidget(screen);
          final owner = tester.element(pageFinder);
          final controls = find.descendant(
            of: pageFinder,
            matching: find.byType(IconButton),
          );
          final positions = [
            for (final element in controls.evaluate())
              tester.getRect(find.byWidget(element.widget)),
          ];
          final cleanDirectory = Platform.environment['OCULVE_ACCOUNT_PREVIEW'];
          if ((name == 'account' || name == 'connection-settings') &&
              cleanDirectory != null) {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              Directory(cleanDirectory).createSync(recursive: true);
              await File(
                '$cleanDirectory/$name-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          AppFeedback.showError(
            owner,
            const ApiFailure('UPSTREAM_ERROR_503', 503),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          final notice = tester.getRect(
            find.byKey(const ValueKey('feedback-card')),
          );
          expect(notice.left, 16);
          expect(notice.right, 304);
          expect(notice.top, 76);
          expect(notice.bottom, lessThan(260));
          expect(find.text('UPSTREAM_ERROR_503'), findsNothing);
          expect([
            for (final element in controls.evaluate())
              tester.getRect(find.byWidget(element.widget)),
          ], positions);
          expect(tester.takeException(), isNull);

          // Optional visual QA output; normal test runs write no screenshots.
          final screenshotDirectory =
              Platform.environment['OCULVE_FEEDBACK_SCREENSHOTS'];
          if (screenshotDirectory != null) {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final directory = Directory(screenshotDirectory)
                  ..createSync(recursive: true);
                await File(
                  '${directory.path}/$name-${dark ? 'dark' : 'light'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
          await tester.drag(
            find.byKey(const ValueKey('feedback-card')),
            const Offset(-500, 0),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.byKey(const ValueKey('feedback-card')), findsNothing);
          expect(tester.takeException(), isNull);
          // Explicitly dispose page timers and looping artwork animations.
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }

  testWidgets(
    'an error reported from a hidden Home screen does not cover Settings',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final container = ProviderContainer(
        overrides: [sessionProvider.overrideWith((ref) => _ScreenSession())],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [AppFeedbackNavigatorObserver()],
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      container.read(vpnProvider.notifier).state = VpnState.error;
      container.read(vpnErrorProvider.notifier).state =
          'VPN permission was not granted.';
      await tester.pump();
      expect(find.byKey(const ValueKey('feedback-card')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
