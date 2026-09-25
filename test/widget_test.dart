import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/features/auth/presentation/login_screen.dart';
import 'package:oculve/features/auth/presentation/signup_screen.dart';
import 'package:oculve/features/home/presentation/home_screen.dart';
import 'package:oculve/features/home/presentation/server_selection_screen.dart';
import 'package:oculve/features/settings/presentation/account_screen.dart';
import 'package:oculve/features/settings/presentation/client_logs_screen.dart';
import 'package:oculve/features/settings/presentation/settings_screen.dart';
import 'package:oculve/features/settings/presentation/usage_statistics_screen.dart';
import 'package:oculve/features/settings/presentation/xray_core_settings_screen.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/theme/app_scroll_behavior.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/navigation/app_navigator.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'profile_test.dart' show testLink;

class _AccountSession extends SessionController {
  int refreshCount = 0;
  _AccountSession() : super(OculveApi()) {
    state = AsyncValue.data(
      Account({
        'authCode': 'ABCD-EFGH-IJKL',
        'status': 'active',
        'plan': 'Premium',
        'createdAt': '2026-09-22T12:00:00.000Z',
        'expiresAt': '2026-10-22T12:00:00.000Z',
        'usage': {'usedGB': 2.5, 'limitGB': 50},
        'security': {
          'totpEnabled': true,
          'totpConfigured': true,
          'passkeys': [
            {
              'credentialId': 'test-id',
              'label': 'My laptop',
              'enabled': true,
              'createdAt': '2026-09-22T12:00:00.000Z',
            },
          ],
        },
      }, const []),
    );
  }

  @override
  Future<void> refreshAccount() async {
    refreshCount++;
  }
}

class _TotpSetupApi extends OculveApi {
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async {
    if (path == '/api/user/security/totp/setup') {
      return {
        'manualEntryKey': 'JBSWY3DPEHPK3PXP',
        'setupToken': 'test-setup-token',
        'qrDataUrl': '',
      };
    }
    return {};
  }
}

class _UnconfiguredTotpSession extends _AccountSession {
  _UnconfiguredTotpSession() {
    final data = Map<String, dynamic>.from(state.valueOrNull!.data)
      ..['security'] = <String, dynamic>{};
    state = AsyncValue.data(Account(data, const []));
  }
}

class _SignupSession extends SessionController {
  _SignupSession() : super(OculveApi());

  @override
  Future<String> generateRegistrationCode() async => 'ABCD-EFGH-IJKL';
}

class _VlessSession extends SessionController {
  _VlessSession(VpnProfile profile) : super(OculveApi()) {
    state = AsyncValue.data(Account({'status': 'active'}, [profile]));
  }
}

void main() {
  testWidgets('desktop popup overlays never show scrollbars', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        scrollBehavior: const AppScrollBehavior().copyWith(scrollbars: false),
        home: Scaffold(
          body: Center(
            child: PopupMenuButton<int>(
              itemBuilder: (context) => List.generate(
                30,
                (index) =>
                    PopupMenuItem(value: index, child: Text('Item $index')),
              ),
              child: const Text('Open menu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((widget) => widget is RawScrollbar),
      findsNothing,
    );
    expect(find.byType(Scrollbar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings place theme options above language', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('System')).dy,
      lessThan(tester.getTopLeft(find.text('Language')).dy),
    );
  });

  testWidgets('home wordmark uses the website system type at header size', (
    tester,
  ) async {
    for (final (theme, color) in [
      (AppTheme.darkTheme, AppTheme.foreground),
      (AppTheme.lightTheme, AppTheme.lightForeground),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: OculveWordmark(color: color)),
        ),
      );
      final mark = find.byType(OculveWordmark);
      expect(tester.getSize(mark), const Size(108, 24));
      final wordmark = tester.widget<Text>(find.text('oculve'));
      expect(wordmark.style?.color, color);
      expect(wordmark.style?.fontSize, 22.8);
    }
  });

  testWidgets(
    'account shows real fields in a compact window and keeps access code hidden',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = _AccountSession();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copiedCode;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedCode = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWith((ref) => session)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AccountScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(session.refreshCount, 1);
      expect(tester.takeException(), isNull);
      expect(find.text('ABCD-EFGH-IJKL'), findsOneWidget);
      expect(find.text('••••-••••-••••'), findsNothing);
      expect(find.byTooltip('Show code'), findsNothing);
      expect(find.text('Export'), findsNothing);
      final blur = find.byType(TweenAnimationBuilder<double>);
      expect(tester.widget<TweenAnimationBuilder<double>>(blur).tween.end, 5);
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('SUBSCRIPTION LINK'), findsNothing);
      expect(find.textContaining('d remaining'), findsOneWidget);
      expect(find.byType(Scrollable), findsNothing);
      expect(
        tester.getCenter(find.text('Log out')).dy,
        lessThan(tester.getCenter(find.text('Delete account')).dy),
      );
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('Delete account'),
                matching: find.byType(OutlinedButton),
              ),
            )
            .height,
        greaterThanOrEqualTo(50),
      );
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('Log out'),
                matching: find.byType(FilledButton),
              ),
            )
            .height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.text('ABCD-EFGH-IJKL'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.widget<TweenAnimationBuilder<double>>(blur).tween.end, 0);
      expect(copiedCode, isNull);
      await tester.tap(find.text('ABCD-EFGH-IJKL'));
      await tester.pump();
      expect(copiedCode, 'ABCD-EFGH-IJKL');
      await tester.tap(find.text('Security'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('2FA / TOTP'), findsOneWidget);
      expect(find.text('Passkeys'), findsOneWidget);
      expect(find.text('Add passkey on website'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(session.refreshCount, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 30));
      expect(session.refreshCount, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(session.refreshCount, 3);
    },
  );
  testWidgets(
    'account deletion needs the exact phrase in a single confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWith((ref) => _AccountSession())],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AccountScreen(),
          ),
        ),
      );
      await tester.tap(find.text('Delete account'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.textContaining('Type the phrase below to confirm.'),
        findsOneWidget,
      );
      final deleteAction = find.byType(FilledButton).last;
      expect(tester.widget<FilledButton>(deleteAction).onPressed, isNull);
      final confirmation = find.byType(TextField);
      await tester.enterText(confirmation, 'DELETE MY ACCOUNT');
      await tester.pump();
      expect(tester.widget<FilledButton>(deleteAction).onPressed, isNotNull);
      await tester.tap(find.text('Cancel').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('account deletion follows native iOS and macOS dialog patterns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWith((ref) => _AccountSession())],
          child: MaterialApp(
            theme: AppTheme.darkTheme.copyWith(platform: platform),
            home: const AccountScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.ensureVisible(find.text('Delete account'));
      await tester.tap(find.text('Delete account').first);
      await tester.pump(const Duration(milliseconds: 350));

      final field = find.byKey(
        const ValueKey('delete-account-confirmation-field'),
      );
      expect(field, findsOneWidget);
      expect(find.byType(cupertino.CupertinoAlertDialog), findsOneWidget);
      final action = find
          .descendant(
            of: find.byType(cupertino.CupertinoAlertDialog),
            matching: find.byType(cupertino.CupertinoDialogAction),
          )
          .last;
      expect(
        tester.widget<cupertino.CupertinoDialogAction>(action).onPressed,
        isNull,
      );
      await tester.enterText(field, 'DELETE MY ACCOUNT');
      await tester.pump();
      expect(
        tester.widget<cupertino.CupertinoDialogAction>(action).onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Cancel').last);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: '$platform dialog');
    }
  });
  testWidgets('TOTP setup fits the compact app window in the app theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _UnconfiguredTotpSession()),
          apiProvider.overrideWithValue(_TotpSetupApi()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Security'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('2FA / TOTP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Set up authenticator'), findsOneWidget);
    expect(find.text('MANUAL SETUP KEY'), findsOneWidget);
    expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
    expect(tester.getSize(find.byType(Dialog)).width, lessThanOrEqualTo(320));
    expect(tester.getSize(find.byType(Dialog)).width, greaterThan(280));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });
  testWidgets('sign-in asks for existing account code, not subscription URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: const LoginScreen(), theme: ThemeData.light()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ACCESS CODE'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('CONNECTED'), findsNothing);
  });
  testWidgets('sign-up follows the website account setup layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => _SignupSession())],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SignUpScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Account Setup'), findsOneWidget);
    expect(find.text('YOUR UNIQUE ACCESS CODE'), findsOneWidget);
    expect(find.text('ABCD-EFGH-IJKL'), findsOneWidget);
    expect(find.text('GO TO DASHBOARD'), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('access-code field gets the website focus halo', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    final container = find
        .ancestor(
          of: find.byType(TextField),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final before =
        tester.widget<AnimatedContainer>(container).decoration as BoxDecoration;
    expect(before.boxShadow, isNull);
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 200));
    final focused =
        tester.widget<AnimatedContainer>(container).decoration as BoxDecoration;
    expect(focused.boxShadow, isNotEmpty);
    expect(focused.boxShadow!.single.blurRadius, 16);
    expect(focused.boxShadow!.single.spreadRadius, 0.5);
    final focusLift = find
        .ancestor(
          of: find.byType(TextField),
          matching: find.byType(AnimatedSlide),
        )
        .first;
    expect(tester.widget<AnimatedSlide>(focusLift).offset.dy, -1 / 52);
  });
  testWidgets('home fits narrow mobile viewport in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: theme, home: const HomeScreen()),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('CONNECT'), findsOneWidget);
      final connectControl = find.byKey(const ValueKey('vpn-connect-control'));
      expect(tester.getSize(connectControl).width, 240);
      expect(tester.getSize(connectControl).height, 68);
      expect(find.text('CONNECTED'), findsNothing);
      expect(find.text('Choose location'), findsOneWidget);
    }
  });

  testWidgets('tray choose-server action opens the location picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _LocationPickerSession()),
        ],
        child: MaterialApp(
          navigatorKey: appNavigatorKey,
          theme: AppTheme.darkTheme,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    unawaited(openServerPicker());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isTrue,
    );
    expect(find.byType(ServerSelectionScreen), findsOneWidget);
    expect(find.text('Locations'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'every page fits the Mullvad-sized desktop window and a narrow phone',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final screens = <Widget>[
        const LoginScreen(),
        const HomeScreen(),
        const ServerSelectionScreen(),
        const AccountScreen(),
        const SettingsScreen(),
        const UsageStatisticsScreen(),
        const ClientLogsScreen(),
        const XrayCoreSettingsScreen(),
      ];
      for (final size in [const Size(320, 568), const Size(360, 640)]) {
        tester.view.physicalSize = size;
        for (final screen in screens) {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(theme: AppTheme.darkTheme, home: screen),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull, reason: '$screen at $size');
        }
      }
    },
  );

  testWidgets('Xray settings expose supported user controls only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profile = VpnProfile.parseSubscription(testLink).single;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _VlessSession(profile)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Connection settings'), findsOneWidget);
    expect(
      find.text('Most users can leave these settings as they are.'),
      findsOneWidget,
    );
    expect(find.text('DNS & IP'), findsOneWidget);
    expect(find.text('Split tunneling'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
    for (final removed in [
      'XHTTP transport',
      'Mux and XUDP',
      'Custom Xray JSON',
      'Core version guard',
      'TCP Fast Open',
      'Per-user upload statistics',
      'VLESS Encryption',
    ]) {
      expect(find.text(removed), findsNothing);
    }

    await tester.tap(find.byKey(const ValueKey('xray-section-DNS & IP')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(
      find.byKey(const ValueKey('xray-choice-DNS provider-Google')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(Scrollbar), findsNothing);
    expect((await XrayPreferences.userDnsSettings()).servers, [
      'https://dns.google/dns-query',
    ]);

    await tester.tap(
      find.byKey(const ValueKey('xray-choice-DNS address family-IPv6 only')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      (await XrayPreferences.userDnsSettings()).queryStrategy,
      DnsQueryStrategy.useIPv6,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('xray-section-Split tunneling')),
    );
    await tester.tap(
      find.byKey(const ValueKey('xray-section-Split tunneling')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    final domains = find.byKey(const ValueKey('bypass-domains-field'));
    await tester.ensureVisible(domains);
    await tester.enterText(domains, 'example.com\nnews.example.org');
    await tester.tap(find.byKey(const ValueKey('save-bypass-domains')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(await XrayPreferences.bypassDomains(), [
      'example.com',
      'news.example.org',
    ]);

    await tester.ensureVisible(
      find.byKey(const ValueKey('xray-section-Advanced')),
    );
    await tester.tap(find.byKey(const ValueKey('xray-section-Advanced')));
    await tester.pump(const Duration(milliseconds: 250));
    final fragmentation = find.byKey(
      const ValueKey('xray-fragmentation-switch'),
    );
    await tester.ensureVisible(fragmentation);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(fragmentation);
    await tester.pump(const Duration(milliseconds: 250));
    expect(await XrayPreferences.tlsHelloFragmentationEnabled(), isTrue);
    final config = XrayPreferences.configure(
      profile.config,
      RealityFingerprint.serverDefault,
      dnsSettings: await XrayPreferences.userDnsSettings(),
      finalMaskSettings: await XrayPreferences.userFinalMaskSettings(),
    );
    expect(config, contains('"maxSplit":"3-6"'));
    expect(tester.takeException(), isNull);
  });
}

class _LocationPickerSession extends SessionController {
  _LocationPickerSession() : super(OculveApi()) {
    state = AsyncValue.data(Account({}, const []));
  }

  @override
  Future<void> refresh() async {}
}
