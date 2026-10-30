import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:oculve/core/widgets/inline_feedback.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/auth/presentation/login_screen.dart';
import 'package:oculve/features/auth/presentation/signup_screen.dart';
import 'package:oculve/features/home/presentation/home_screen.dart';
import 'package:oculve/features/settings/presentation/settings_screen.dart';
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

  // Screens converted to in-place errors reserve their slot up front, so a
  // failure can appear without shifting anything. Account and the connection
  // settings still use the banner.
  for (final (name, screenBuilder) in <(String, Widget Function())>[
    ('login', () => const LoginScreen()),
    ('signup', () => const SignUpScreen()),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('$name reserves inline error slot, dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            apiProvider.overrideWithValue(_OfflineApi()),
            sessionProvider.overrideWith((ref) => _ScreenSession()),
          ],
        );
        addTearDown(container.dispose);
        final screenWidget = screenBuilder();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
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
              home: screenWidget,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Verify the screen contains an InlineErrorSlot (reserved space for errors).
        final inlineErrorSlot = find.byType(InlineErrorSlot);
        expect(inlineErrorSlot, findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      });
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
      // With inline feedback, the connect button's error slot is on Home,
      // not on Settings. The Settings screen should show no feedback.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is InlineErrorSlot &&
              widget.message?.contains('VPN permission was not granted') ==
                  true,
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
