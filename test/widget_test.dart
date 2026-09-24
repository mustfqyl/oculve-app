import 'dart:convert';

import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
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
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'profile_test.dart' show testLink;

extension _WidgetTesterXrayScrolling on WidgetTester {
  Future<void> scrollXrayUntilVisible(
    Finder target,
    double delta, {
    required Finder scrollable,
    int maxScrolls = 100,
  }) async {
    final list = scrollable;
    final viewportFinder = find
        .descendant(of: list, matching: find.byType(Viewport))
        .first;
    final position = Scrollable.of(element(viewportFinder)).position;
    final viewport = getRect(viewportFinder);
    for (var attempt = 0; attempt < maxScrolls; attempt++) {
      if (target.evaluate().isEmpty) {
        position.jumpTo(
          (position.pixels + delta)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble(),
        );
        await pump(const Duration(milliseconds: 16));
        continue;
      }
      final rect = getRect(target);
      if (rect.top >= viewport.top + 8 && rect.bottom <= viewport.bottom - 8) {
        return;
      }
      final correction = rect.center.dy - viewport.center.dy;
      final next = (position.pixels + correction).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((next - position.pixels).abs() < 1) break;
      position.jumpTo(next.toDouble());
      await pump(const Duration(milliseconds: 16));
    }
    expect(target, findsOneWidget);
    final targetRect = getRect(target);
    expect(
      targetRect.top >= viewport.top && targetRect.bottom <= viewport.bottom,
      isTrue,
      reason:
          'Xray setting is outside the viewport: target=$targetRect, '
          'viewport=$viewport, offset=${position.pixels}/${position.maxScrollExtent}',
    );
  }
}

Future<void> _expandXraySettings(
  WidgetTester tester, [
  List<String> sections = const [
    'Connection setup',
    'Performance',
    'Diagnostics',
    'DNS & name resolution',
    'Routing & privacy',
    'Advanced core options',
  ],
]) async {
  await tester.pump(const Duration(seconds: 1));
  final list = find.byKey(const ValueKey('xray-core-settings-list'));
  final viewportFinder = find
      .descendant(of: list, matching: find.byType(Viewport))
      .first;
  final position = Scrollable.of(tester.element(viewportFinder)).position;
  final viewport = tester.getRect(viewportFinder);
  for (final title in sections) {
    final section = find.byKey(ValueKey('xray-section-$title'));
    var scrolls = 0;
    bool fullyVisible() {
      if (section.evaluate().isEmpty) return false;
      final rect = tester.getRect(section);
      return rect.top >= viewport.top + 8 && rect.bottom <= viewport.bottom - 8;
    }

    while (!fullyVisible() && scrolls < 50) {
      if (section.evaluate().isEmpty) {
        position.jumpTo(
          (position.pixels + 240)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble(),
        );
      } else {
        final rect = tester.getRect(section);
        position.jumpTo(
          (position.pixels + rect.center.dy - viewport.center.dy)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble(),
        );
      }
      await tester.pump(const Duration(milliseconds: 16));
      scrolls++;
    }
    expect(
      section,
      findsOneWidget,
      reason: 'Could not find Xray section $title',
    );
    expect(fullyVisible(), isTrue, reason: 'Xray section $title is offscreen');
    await tester.tap(section);
    await tester.pump(const Duration(milliseconds: 400));
  }
}

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
      expect(tester.widget<TweenAnimationBuilder<double>>(blur).tween.end, 6.5);
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('SUBSCRIPTION LINK'), findsNothing);
      expect(find.textContaining('d remaining'), findsOneWidget);
      expect(find.byType(Scrollable), findsNothing);
      expect(
        tester.getCenter(find.text('Delete account')).dy,
        lessThan(tester.getCenter(find.text('Log out')).dy),
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
        greaterThanOrEqualTo(44),
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
    'account deletion needs the exact phrase and a second confirmation',
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
      final confirmation = find.byType(cupertino.CupertinoTextField);
      await tester.enterText(confirmation, 'DELETE MY ACCOUNT');
      await tester.pump();
      await tester.tap(find.text('Delete account').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Permanently delete?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    },
  );
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
    expect(focused.boxShadow!.single.spreadRadius, 4);
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
      expect(find.text('CONNECTED'), findsNothing);
      expect(find.text('Choose location'), findsOneWidget);
    }
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

  testWidgets('Xray site routing saves validated domains', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await _expandXraySettings(tester, ['Routing & privacy']);
    await tester.scrollXrayUntilVisible(
      find.byKey(const ValueKey('bypass-domain-field')),
      160,
      scrollable: find.byKey(const ValueKey('xray-core-settings-list')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('bypass-domain-field')),
      'EXAMPLE.com\nsub.example.com',
    );
    await tester.scrollXrayUntilVisible(
      find.byKey(const ValueKey('save-bypass-domains')),
      160,
      scrollable: find.byKey(const ValueKey('xray-core-settings-list')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('save-bypass-domains')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await XrayPreferences.bypassDomains(), [
      'example.com',
      'sub.example.com',
    ]);
  });

  testWidgets('advanced Xray route editor saves working match criteria', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await _expandXraySettings(tester, ['Routing & privacy']);
    final addRule = find.byKey(const ValueKey('add-xray-routing-rule'));
    await tester.scrollXrayUntilVisible(
      addRule,
      160,
      scrollable: find.byKey(const ValueKey('xray-core-settings-list')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(addRule);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey('xray-route-domains')),
      'example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('xray-route-ips')),
      '10.0.0.0/8',
    );
    await tester.enterText(
      find.byKey(const ValueKey('xray-route-ports')),
      '443, 8000-8100',
    );
    final advancedMatchers = find.byKey(
      const ValueKey('xray-route-advanced-matchers'),
    );
    await tester.ensureVisible(advancedMatchers);
    await tester.tap(advancedMatchers);
    await tester.pump(const Duration(milliseconds: 300));
    final sourcePorts = find.byKey(const ValueKey('xray-route-source-ports'));
    await tester.ensureVisible(sourcePorts);
    await tester.enterText(sourcePorts, '50000-60000');
    final attributes = find.byKey(const ValueKey('xray-route-http-attributes'));
    await tester.ensureVisible(attributes);
    await tester.enterText(attributes, ':method=GET\n:path=/api.*');
    final webhookUrl = find.byKey(const ValueKey('xray-route-webhook-url'));
    await tester.ensureVisible(webhookUrl);
    await tester.enterText(webhookUrl, 'https://hooks.example.com/route');
    final webhookHeaders = find.byKey(
      const ValueKey('xray-route-webhook-headers'),
    );
    await tester.ensureVisible(webhookHeaders);
    await tester.enterText(webhookHeaders, '{"X-API-Key":"test-key"}');
    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 300));
    final save = find.byKey(const ValueKey('save-bypass-domains'));
    await tester.scrollXrayUntilVisible(
      save,
      160,
      scrollable: find.byKey(const ValueKey('xray-core-settings-list')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 300));

    final rules = await XrayPreferences.routingRules();
    expect(rules, hasLength(1));
    expect(rules.single.action, XrayRoutingAction.direct);
    expect(rules.single.domains, ['domain:example.com']);
    expect(rules.single.ips, ['10.0.0.0/8']);
    expect(rules.single.ports, ['443', '8000-8100']);
    expect(rules.single.sourcePorts, ['50000-60000']);
    expect(rules.single.attributes, {':method': 'GET', ':path': '/api.*'});
    expect(rules.single.webhook?.url, 'https://hooks.example.com/route');
    expect(rules.single.webhook?.headers, {'X-API-Key': 'test-key'});
  });

  testWidgets('Xray sniffing controls save real domain and IP exclusions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await _expandXraySettings(tester, ['Routing & privacy']);

    final routeOnly = find.byKey(const ValueKey('xray-sniffing-route-only'));
    await tester.scrollXrayUntilVisible(
      routeOnly,
      150,
      scrollable: find.byKey(const ValueKey('xray-core-settings-list')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(routeOnly);
    await tester.pump(const Duration(milliseconds: 100));

    final domains = find.byKey(
      const ValueKey('xray-sniffing-excluded-domains'),
    );
    await tester.scrollXrayUntilVisible(
      domains,
      150,
      scrollable: find.byKey(const ValueKey('xray-core-settings-list')),
    );
    await tester.enterText(domains, 'push.example.com\nfull:api.example.com');
    await tester.enterText(
      find.byKey(const ValueKey('xray-sniffing-excluded-ips')),
      '192.168.1.0/24',
    );
    final save = find.byKey(const ValueKey('save-xray-sniffing'));
    await tester.scrollXrayUntilVisible(
      save,
      120,
      scrollable: find.byKey(const ValueKey('xray-core-settings-list')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 300));

    final saved = await XrayPreferences.sniffingSettings();
    expect(saved.routeOnly, false);
    expect(saved.domainsExcluded, [
      'domain:push.example.com',
      'full:api.example.com',
    ]);
    expect(saved.ipsExcluded, ['192.168.1.0/24']);
  });

  testWidgets('FakeDNS sniffing chip toggles the real Xray DNS mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await _expandXraySettings(tester, ['Routing & privacy']);

    final fakeDnsChip = find.byKey(const ValueKey('xray-sniffing-fakedns'));
    await tester.scrollXrayUntilVisible(
      fakeDnsChip,
      150,
      scrollable: find.byKey(const ValueKey('xray-core-settings-list')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(fakeDnsChip);
    await tester.pump(const Duration(milliseconds: 300));

    final dns = await XrayPreferences.dnsSettings();
    final sniffing = await XrayPreferences.sniffingSettings();
    expect(dns.fakeDns, isTrue);
    expect(sniffing.destOverride, isNot(contains('fakedns')));

    final configured =
        jsonDecode(
              XrayPreferences.configure(
                VpnProfile.parseSubscription(testLink).single.config,
                RealityFingerprint.chrome,
                dnsSettings: dns,
                sniffingSettings: sniffing,
              ),
            )
            as Map<String, dynamic>;
    final inbound = (configured['inbounds'] as List).single as Map;
    expect(inbound['sniffing']['enabled'], isTrue);
    expect(inbound['sniffing']['destOverride'], contains('fakedns'));

    await tester.tap(fakeDnsChip);
    await tester.pump(const Duration(milliseconds: 300));
    expect((await XrayPreferences.dnsSettings()).fakeDns, isFalse);
  });

  testWidgets(
    'Xray Mux controls persist settings used by the next connection',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const XrayCoreSettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await _expandXraySettings(tester, ['Performance']);
      final settingsList = find.byKey(
        const ValueKey('xray-core-settings-list'),
      );
      final muxTitle = find.text('Mux and XUDP');
      var scrolls = 0;
      while (muxTitle.evaluate().isEmpty && scrolls < 40) {
        await tester.drag(settingsList, const Offset(0, -180));
        await tester.pump(const Duration(milliseconds: 50));
        scrolls++;
      }
      await tester.ensureVisible(muxTitle);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Enable Mux'));
      await tester.pump(const Duration(milliseconds: 100));
      expect((await XrayPreferences.muxSettings()).enabled, isTrue);
      expect(find.text('TCP concurrency'), findsOneWidget);
      expect(find.text('XUDP concurrency'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Xray DNS screen saves real resolver and query settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await _expandXraySettings(tester, ['DNS & name resolution']);
    await tester.scrollXrayUntilVisible(
      find.byKey(const ValueKey('dns-servers-field')),
      140,
      scrollable: find.byKey(const ValueKey('xray-core-settings-list')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('dns-servers-field')),
      'https://dns.google/dns-query\ntcp://9.9.9.10',
    );
    await tester.enterText(
      find.byKey(const ValueKey('dns-hosts-field')),
      'example.test=192.0.2.15',
    );
    await tester.scrollXrayUntilVisible(
      find.text('Save DNS'),
      120,
      scrollable: find.byKey(const ValueKey('xray-core-settings-list')),
    );
    await tester.tap(
      find.ancestor(
        of: find.text('Save DNS'),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final saved = await XrayPreferences.dnsSettings();
    expect(saved.servers, ['https://dns.google/dns-query', 'tcp://9.9.9.10']);
    expect(saved.hosts, {'example.test': '192.0.2.15'});

    final queryStrategy = find.byKey(
      const ValueKey('xray-dropdown-Address family'),
    );
    await tester.ensureVisible(queryStrategy);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(queryStrategy);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('UseSystem').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      (await XrayPreferences.dnsSettings()).queryStrategy,
      DnsQueryStrategy.useSystem,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Xray TLS controls persist actual core settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await _expandXraySettings(tester, ['Connection setup']);
    final settingsScroll = find.byKey(
      const ValueKey('xray-core-settings-list'),
    );
    await tester.scrollXrayUntilVisible(
      find.byKey(const ValueKey('tls-server-name-field')),
      140,
      scrollable: settingsScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('tls-server-name-field')),
      'front.example',
    );
    await tester.scrollXrayUntilVisible(
      find.text('Advanced TLS'),
      120,
      scrollable: settingsScroll,
    );
    await tester.tap(
      find.ancestor(
        of: find.text('Advanced TLS'),
        matching: find.byType(ListTile),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.scrollXrayUntilVisible(
      find.byKey(const ValueKey('tls-native-fingerprint-field')),
      120,
      scrollable: settingsScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('tls-native-fingerprint-field')),
      'HelloChrome_120',
    );
    await tester.scrollXrayUntilVisible(
      find.byKey(const ValueKey('tls-alpn-field')),
      120,
      scrollable: settingsScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('tls-alpn-field')),
      'h2,http/1.1',
    );
    await tester.tap(find.byKey(const ValueKey('save-transport-settings')));
    await tester.pump(const Duration(milliseconds: 300));
    final saved = await XrayPreferences.tlsSettings();
    expect(saved.serverName, 'front.example');
    expect(saved.clientHelloFingerprint, 'HelloChrome_120');
    expect(saved.alpn, 'h2,http/1.1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('XHTTP controls persist from the transport settings page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await _expandXraySettings(tester, ['Connection setup']);
    final settingsScroll = find.byKey(
      const ValueKey('xray-core-settings-list'),
    );
    await tester.scrollXrayUntilVisible(
      find.byKey(const ValueKey('xhttp-host-field')),
      160,
      scrollable: settingsScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('xhttp-host-field')),
      'edge.example',
    );
    await tester.enterText(
      find.byKey(const ValueKey('xhttp-path-field')),
      '/tunnel',
    );
    await tester.tap(find.byKey(const ValueKey('save-transport-settings')));
    await tester.pump(const Duration(milliseconds: 300));
    final saved = await XrayPreferences.xhttpSettings();
    expect(saved.host, 'edge.example');
    expect(saved.path, '/tunnel');
    expect(tester.takeException(), isNull);
  });

  testWidgets('TCP Fast Open selection is persisted for the next tunnel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await _expandXraySettings(tester, ['Performance']);
    final fastOpenField = find.byKey(
      const ValueKey('xray-dropdown-TCP Fast Open'),
    );
    await tester.scrollXrayUntilVisible(
      fastOpenField,
      240,
      scrollable: find.byKey(const ValueKey('xray-core-settings-list')),
    );
    expect(fastOpenField, findsOneWidget);
    await tester.ensureVisible(fastOpenField);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(fastOpenField);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Enabled').last);
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      (await XrayPreferences.tcpSettings()).fastOpenMode,
      TcpFastOpenMode.enabled,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('VLESS Encryption controls save only the selected location', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final profile = VpnProfile.parseSubscription(testLink).single;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _VlessSession(profile)),
          selectedServerProvider.overrideWith((ref) => profile.id),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 180));
    await _expandXraySettings(tester, ['Connection setup']);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('VLESS Encryption'), findsOneWidget);
    final enabled = find.byKey(const ValueKey('vless-encryption-enabled'));
    await tester.ensureVisible(enabled);
    await tester.tap(enabled);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const ValueKey('vless-encryption-auth-field')),
      'profile_specific_client_parameter',
    );
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 200));
    final save = find.byKey(const ValueKey('save-vless-encryption'));
    await tester.ensureVisible(save);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 250));

    final settings = await XrayPreferences.vlessEncryptionSettingsFor(
      profile.id,
    );
    expect(settings?.serverAuthentication, 'profile_specific_client_parameter');
    final configured =
        jsonDecode(
              XrayPreferences.configure(
                profile.config,
                RealityFingerprint.serverDefault,
                vlessEncryptionSettings: settings,
              ),
            )
            as Map<String, dynamic>;
    expect(
      configured['outbounds'][0]['settings']['vnext'][0]['users'][0]['encryption'],
      contains('profile_specific_client_parameter'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Xray policy and user statistics persist from settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await _expandXraySettings(tester, ['Diagnostics']);
    final settingsScroll = find.byKey(
      const ValueKey('xray-core-settings-list'),
    );
    await tester.scrollXrayUntilVisible(
      find.byKey(const ValueKey('policy-handshake-field')),
      180,
      scrollable: settingsScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('policy-handshake-field')),
      '47',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    for (final key in [
      'policy-user-upload-switch',
      'policy-user-download-switch',
      'policy-user-online-switch',
      'policy-system-inbound-upload-switch',
      'policy-system-inbound-download-switch',
      'policy-system-outbound-upload-switch',
      'policy-system-outbound-download-switch',
    ]) {
      final switchFinder = find.byKey(ValueKey(key));
      await tester.scrollXrayUntilVisible(
        switchFinder,
        140,
        scrollable: settingsScroll,
      );
      await tester.tap(switchFinder);
      await tester.pump();
    }
    await tester.scrollXrayUntilVisible(
      find.byKey(const ValueKey('save-policy-settings')),
      140,
      scrollable: settingsScroll,
    );
    await tester.tap(find.byKey(const ValueKey('save-policy-settings')));
    await tester.pump(const Duration(milliseconds: 300));
    final saved = await XrayPreferences.policySettings();
    expect(saved.handshakeSeconds, 47);
    expect(saved.statsUserUplink, isTrue);
    expect(saved.statsUserDownlink, isTrue);
    expect(saved.statsUserOnline, isTrue);
    expect(saved.statsInboundUplink, isFalse);
    expect(saved.statsInboundDownlink, isFalse);
    expect(saved.statsOutboundUplink, isFalse);
    expect(saved.statsOutboundDownlink, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom Xray JSON editor saves a real runtime overlay', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await _expandXraySettings(tester, ['Advanced core options']);
    final settingsScroll = find.byKey(
      const ValueKey('xray-core-settings-list'),
    );
    await tester.scrollXrayUntilVisible(
      find.byKey(const ValueKey('xray-custom-config-field')),
      180,
      scrollable: settingsScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('xray-custom-config-field')),
      '{"routing":{"domainStrategy":"IPIfNonMatch"}}',
    );
    await tester.scrollXrayUntilVisible(
      find.byKey(const ValueKey('save-custom-xray-config')),
      120,
      scrollable: settingsScroll,
    );
    await tester.tap(find.byKey(const ValueKey('save-custom-xray-config')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await XrayPreferences.customConfigOverrides(), {
      'routing': {'domainStrategy': 'IPIfNonMatch'},
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('Xray version guard controls save the core range', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await _expandXraySettings(tester, ['Advanced core options']);
    final settingsScroll = find.byKey(
      const ValueKey('xray-core-settings-list'),
    );
    final minimum = find.byKey(const ValueKey('xray-version-minimum'));
    await tester.scrollXrayUntilVisible(
      minimum,
      180,
      scrollable: settingsScroll,
    );
    await tester.enterText(minimum, '25.8.3');
    await tester.enterText(
      find.byKey(const ValueKey('xray-version-maximum')),
      '26.9.9',
    );
    final save = find.byKey(const ValueKey('save-xray-version-guard'));
    await tester.scrollXrayUntilVisible(save, 120, scrollable: settingsScroll);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 300));

    final saved = await XrayPreferences.versionRequirement();
    expect(saved?.minimum, '25.8.3');
    expect(saved?.maximum, '26.9.9');
    expect(tester.takeException(), isNull);
  });

  testWidgets('FinalMask controls save the core mask settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await _expandXraySettings(tester, ['Advanced core options']);
    final settingsScroll = find.byKey(
      const ValueKey('xray-core-settings-list'),
    );
    final field = find.byKey(const ValueKey('xray-finalmask-field'));
    await tester.scrollXrayUntilVisible(field, 180, scrollable: settingsScroll);
    await tester.enterText(
      field,
      '{"tcp":[{"type":"fragment","settings":{"packets":"tlshello","lengths":["100-200"]}}]}',
    );
    final save = find.byKey(const ValueKey('save-xray-finalmask'));
    await tester.scrollXrayUntilVisible(save, 120, scrollable: settingsScroll);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 300));

    expect((await XrayPreferences.finalMaskSettings()).toXrayJson(), {
      'tcp': [
        {
          'type': 'fragment',
          'settings': {
            'packets': 'tlshello',
            'lengths': ['100-200'],
          },
        },
      ],
    });
    expect(tester.takeException(), isNull);
  });
}
