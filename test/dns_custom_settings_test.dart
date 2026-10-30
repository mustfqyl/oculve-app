import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/desktop/startup_service.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'package:oculve/features/settings/presentation/xray_core_settings_screen.dart';
import 'startup_service_test.dart' show FakeStartupBackend;

const _hint = 'Enter a DNS address, such as dns.adguard.com or 94.140.14.14.';
const _cloudflare = 'https://cloudflare-dns.com/dns-query';

/// A fresh root key rebuilds the screen state, which is what re-opening the
/// settings page does on a device.
Widget _screen(Key key) => ProviderScope(
  overrides: [
    startupServiceProvider.overrideWithValue(
      StartupService(FakeStartupBackend()),
    ),
  ],
  child: MaterialApp(
    key: key,
    theme: AppTheme.darkTheme,
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('tr'), Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const XrayCoreSettingsScreen(),
  ),
);

Finder get _field => find.byKey(const ValueKey('custom-dns-field'));

Future<void> _openCustomField(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.tap(find.byKey(const ValueKey('dns-provider-row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  expect(_field, findsOneWidget);
}

Future<void> _type(WidgetTester tester, String value) async {
  await tester.enterText(_field, value);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpScreen(WidgetTester tester, Key key) async {
  await tester.pumpWidget(_screen(key));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Outfit', 'Ahem', 'Roboto', '.AppleSystemUIFont']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/Outfit.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a valid custom DNS saves and survives reopening the screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpScreen(tester, const ValueKey('first'));
    await _openCustomField(tester);
    await _type(tester, 'https://resolver.example/dns-query');

    expect((await XrayPreferences.userDnsSettings()).servers, [
      'https://resolver.example/dns-query',
    ]);
    expect(find.text(_hint), findsNothing);
    expect(find.text('Custom'), findsOneWidget);

    await _pumpScreen(tester, const ValueKey('reopened'));
    expect(
      _field,
      findsOneWidget,
      reason: 'custom mode must be restored, not a preset',
    );
    expect(
      tester.widget<TextField>(_field).controller!.text,
      'https://resolver.example/dns-query',
    );
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Cloudflare'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an invalid custom DNS is never saved and keeps the last value', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpScreen(tester, const ValueKey('first'));
    expect((await XrayPreferences.userDnsSettings()).servers, [_cloudflare]);
    await _openCustomField(tester);
    final lastValid = (await XrayPreferences.userDnsSettings()).servers;

    for (final invalid in [
      'not a URL',
      'localhost',
      'http://resolver.example/dns-query',
      'https://',
      'tcp://dns.google',
    ]) {
      await _type(tester, invalid);
      expect((await XrayPreferences.userDnsSettings()).servers, lastValid);
      expect(find.text(_hint), findsOneWidget, reason: '$invalid needs a hint');
    }

    await _type(tester, 'https://resolver.example/dns-query');
    expect((await XrayPreferences.userDnsSettings()).servers, [
      'https://resolver.example/dns-query',
    ]);
    expect(find.text(_hint), findsNothing);

    await _type(tester, 'https://broken.example:99999/dns-query');
    expect((await XrayPreferences.userDnsSettings()).servers, [
      'https://resolver.example/dns-query',
    ]);
    expect(find.text(_hint), findsOneWidget);

    // Reopening keeps the last valid value instead of a half-typed one.
    await _pumpScreen(tester, const ValueKey('reopened'));
    expect(
      tester.widget<TextField>(_field).controller!.text,
      'https://resolver.example/dns-query',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('clearing the custom field shows no error and saves nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpScreen(tester, const ValueKey('first'));
    await _openCustomField(tester);
    await _type(tester, 'https://resolver.example/dns-query');
    await _type(tester, '');
    expect((await XrayPreferences.userDnsSettings()).servers, [
      'https://resolver.example/dns-query',
    ]);
    expect(find.text(_hint), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a plain hostname or a plain IP is accepted and saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpScreen(tester, const ValueKey('first'));
    await _openCustomField(tester);

    await _type(tester, 'dns.adguard.com');
    expect((await XrayPreferences.userDnsSettings()).servers, [
      'https://dns.adguard.com/dns-query',
    ]);
    expect(find.text(_hint), findsNothing);

    await _type(tester, '94.140.14.14');
    expect((await XrayPreferences.userDnsSettings()).servers, [
      'tcp://94.140.14.14',
    ]);
    expect(find.text(_hint), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('typed DNS input is turned into a stored endpoint', () {
    String n(String v) => XrayPreferences.normalizeUserDnsInput(v);
    expect(n('dns.adguard.com'), 'https://dns.adguard.com/dns-query');
    expect(n('  dns.adguard.com  '), 'https://dns.adguard.com/dns-query');
    expect(n('dns.adguard.com/custom'), 'https://dns.adguard.com/custom');
    expect(n('dns.example.net:8443'), 'https://dns.example.net:8443/dns-query');
    expect(n('94.140.14.14'), 'tcp://94.140.14.14');
    expect(n('2606:4700:4700::1111'), 'tcp://[2606:4700:4700::1111]');
    expect(n('[2606:4700:4700::1111]'), 'tcp://[2606:4700:4700::1111]');
    // Explicit schemes are kept as typed and judged afterwards.
    expect(
      n('https://dns.example.net/dns-query'),
      'https://dns.example.net/dns-query',
    );
    expect(
      n('http://resolver.example/dns-query'),
      'http://resolver.example/dns-query',
    );
    // Not an address: returned unchanged so validation rejects it.
    expect(n('localhost'), 'localhost');
    expect(n('not a URL'), 'not a URL');
    expect(n(''), '');
  });

  test('only HTTPS URLs and plain IPs over TCP are valid endpoints', () {
    bool ok(String v) => XrayPreferences.isUserDnsEndpoint(v);
    expect(ok('https://dns.adguard.com/dns-query'), isTrue);
    expect(ok('tcp://94.140.14.14'), isTrue);
    expect(ok('tcp://94.140.14.14:53'), isTrue);
    expect(ok('tcp://[2606:4700:4700::1111]'), isTrue);
    expect(ok('tcp://dns.google'), isFalse);
    expect(ok('tcp://1.1.1.1/path'), isFalse);
    expect(ok('tcp://user@1.1.1.1'), isFalse);
    expect(ok('94.140.14.14'), isFalse);
    expect(ok('http://dns.adguard.com/dns-query'), isFalse);
    expect(ok('https://dns.example.net:99999/dns-query'), isFalse);
    expect(ok('https://user:pw@dns.example.net/dns-query'), isFalse);
  });
}
