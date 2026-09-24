import 'dart:convert';

import 'package:flutter/material.dart';
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
  testWidgets(
    'home wordmark uses the website system type at header size',
    (tester) async {
      for (final (theme, color) in [
        (AppTheme.darkTheme, AppTheme.foreground),
        (AppTheme.lightTheme, AppTheme.lightForeground),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: OculveWordmark(color: color),
            ),
          ),
        );
        final mark = find.byType(OculveWordmark);
        expect(tester.getSize(mark), const Size(108, 24));
        final wordmark = tester.widget<Text>(find.text('oculve'));
        expect(wordmark.style?.color, color);
        expect(wordmark.style?.fontSize, 22.8);
      }
    },
  );

  testWidgets(
    'account shows real fields in a compact window and keeps access code hidden',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = _AccountSession();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      expect(find.text('ABCD-EFGH-IJKL'), findsNothing);
      expect(find.text('••••-••••-••••'), findsOneWidget);
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('SUBSCRIPTION LINK'), findsNothing);
      expect(find.textContaining('days remaining'), findsOneWidget);
      await tester.tap(find.byTooltip('Show code'));
      await tester.pump();
      expect(find.text('ABCD-EFGH-IJKL'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Security methods'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Security methods'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('2FA / TOTP'), findsOneWidget);
      expect(find.text('Passkeys'), findsOneWidget);
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
      await tester.scrollUntilVisible(
        find.text('Delete account'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete account'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Type DELETE MY ACCOUNT'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Permanently delete?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
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
      expect(find.text('Choose location'), findsNothing);
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('bypass-domain-field')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('bypass-domain-field')),
      'EXAMPLE.com\nsub.example.com',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('save-bypass-domains')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('save-bypass-domains'))),
      alignment: 0.5,
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
    final addRule = find.byKey(const ValueKey('add-xray-routing-rule'));
    await tester.scrollUntilVisible(
      addRule,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(addRule), alignment: 0.5);
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
    await tester.scrollUntilVisible(
      save,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(save), alignment: 0.5);
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

    final routeOnly = find.byKey(const ValueKey('xray-sniffing-route-only'));
    await tester.scrollUntilVisible(
      routeOnly,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(routeOnly), alignment: 0.4);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(routeOnly);
    await tester.pump(const Duration(milliseconds: 100));

    final domains = find.byKey(
      const ValueKey('xray-sniffing-excluded-domains'),
    );
    await tester.scrollUntilVisible(
      domains,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(domains, 'push.example.com\nfull:api.example.com');
    await tester.enterText(
      find.byKey(const ValueKey('xray-sniffing-excluded-ips')),
      '192.168.1.0/24',
    );
    final save = find.byKey(const ValueKey('save-xray-sniffing'));
    await tester.scrollUntilVisible(
      save,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(save), alignment: 0.5);
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

    final fakeDnsChip = find.byKey(const ValueKey('xray-sniffing-fakedns'));
    await tester.scrollUntilVisible(
      fakeDnsChip,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(fakeDnsChip), alignment: 0.4);
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dns-servers-field')),
      140,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('dns-servers-field')),
      'https://dns.google/dns-query\ntcp://9.9.9.10',
    );
    await tester.enterText(
      find.byKey(const ValueKey('dns-hosts-field')),
      'example.test=192.0.2.15',
    );
    await tester.scrollUntilVisible(
      find.text('Save DNS'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save DNS'));
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
    final settingsScroll = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tls-server-name-field')),
      140,
      scrollable: settingsScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('tls-server-name-field')),
      'front.example',
    );
    await tester.ensureVisible(find.text('Advanced TLS'));
    await tester.tap(find.text('Advanced TLS'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tls-native-fingerprint-field')),
      120,
      scrollable: settingsScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('tls-native-fingerprint-field')),
      'HelloChrome_120',
    );
    await tester.scrollUntilVisible(
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
    final settingsScroll = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
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
    final fastOpenField = find.byKey(
      const ValueKey('xray-dropdown-TCP Fast Open'),
    );
    await tester.scrollUntilVisible(
      fastOpenField,
      240,
      scrollable: find.byType(Scrollable).first,
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
    tester.view.physicalSize = const Size(360, 1400);
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
    final settingsScroll = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('policy-handshake-field')),
      180,
      scrollable: settingsScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('policy-handshake-field')),
      '47',
    );
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
      await tester.scrollUntilVisible(
        switchFinder,
        140,
        scrollable: settingsScroll,
      );
      await tester.tap(switchFinder);
      await tester.pump();
    }
    await tester.scrollUntilVisible(
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
    final settingsScroll = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('xray-custom-config-field')),
      180,
      scrollable: settingsScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('xray-custom-config-field')),
      '{"routing":{"domainStrategy":"IPIfNonMatch"}}',
    );
    await tester.scrollUntilVisible(
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
    final settingsScroll = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    final minimum = find.byKey(const ValueKey('xray-version-minimum'));
    await tester.scrollUntilVisible(minimum, 180, scrollable: settingsScroll);
    await tester.enterText(minimum, '25.8.3');
    await tester.enterText(
      find.byKey(const ValueKey('xray-version-maximum')),
      '26.9.9',
    );
    final save = find.byKey(const ValueKey('save-xray-version-guard'));
    await tester.scrollUntilVisible(save, 120, scrollable: settingsScroll);
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
    final settingsScroll = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    final field = find.byKey(const ValueKey('xray-finalmask-field'));
    await tester.scrollUntilVisible(field, 180, scrollable: settingsScroll);
    await tester.enterText(
      field,
      '{"tcp":[{"type":"fragment","settings":{"packets":"tlshello","lengths":["100-200"]}}]}',
    );
    final save = find.byKey(const ValueKey('save-xray-finalmask'));
    await tester.scrollUntilVisible(save, 120, scrollable: settingsScroll);
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
