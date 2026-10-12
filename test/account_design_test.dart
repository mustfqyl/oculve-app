import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/settings/presentation/account_screen.dart';

class _Session extends SessionController {
  _Session(String? expiry) : super(OculveApi()) {
    state = AsyncValue.data(
      Account({
        'status': 'active',
        'authCode': 'EXAMPLE-ACCOUNT',
        'createdAt': '2026-04-05T12:00:00Z',
        'expiresAt': expiry,
        'billing': {'nextBillingAt': '2030-01-01T00:00:00Z'},
        'usage': {'usedGB': 1371.96},
        'devices': [
          for (var i = 0; i < 4; i++) {'name': 'Device $i'},
        ],
        'security': {
          'totpEnabled': true,
          'passkeys': [
            {'enabled': true},
          ],
        },
      }, const []),
    );
  }
  @override
  Future<void> refreshAccount() async {}
}

class _DeviceResetApi extends OculveApi {
  final resetGate = Completer<void>();
  int resetCalls = 0;

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async {
    if (path == '/api/user/devices/reset') {
      resetCalls++;
      await resetGate.future;
    }
    return {};
  }
}

class _DeviceResetSession extends SessionController {
  _DeviceResetSession(super.api) {
    state = AsyncValue.data(
      Account({
        'status': 'active',
        'devices': [
          {'deviceModel': 'Mac14,2', 'deviceOs': 'macOS'},
        ],
      }, const []),
    );
  }

  int logoutCalls = 0;

  @override
  Future<void> refreshAccount() async {}

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncValue.data(null);
  }
}

class _IdleVpnNotifier extends VpnNotifier {
  _IdleVpnNotifier(super.ref);

  @override
  Future<void> disconnect() async {}
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
  testWidgets('device reset requires a visible second press then logs out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _DeviceResetApi();
    final session = _DeviceResetSession(api);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          sessionProvider.overrideWith((ref) => session),
          vpnProvider.overrideWith((ref) => _IdleVpnNotifier(ref)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Devices').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.widgetWithIcon(IconButton, Icons.restart_alt));
    await tester.pump();
    expect(find.byIcon(Icons.question_mark_rounded), findsOneWidget);
    expect(api.resetCalls, 0);
    expect(session.logoutCalls, 0);

    await tester.tap(find.byIcon(Icons.question_mark_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(api.resetCalls, 1);
    expect(session.logoutCalls, 0);

    api.resetGate.complete();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(session.logoutCalls, 1);
    expect(find.text('Registered devices (1)'), findsNothing);
  });
  for (final locale in ['en', 'tr', 'es']) {
    for (final dark in [true, false]) {
      testWidgets('account reference $locale dark=$dark', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionProvider.overrideWith(
                (ref) => _Session('2027-01-01T00:00:00Z'),
              ),
            ],
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(locale),
                supportedLocales: const [
                  Locale('en'),
                  Locale('tr'),
                  Locale('es'),
                ],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                home: const AccountScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<Icon>(find.byKey(const ValueKey('account-status-dot')))
              .size,
          6,
        );
        expect(find.text('01.01.2030'), findsNothing);
        expect(
          tester.getBottomRight(find.byType(OutlinedButton)).dy,
          lessThanOrEqualTo(568),
        );
        final directory = Platform.environment['OCULVE_ACCOUNT_PREVIEW'];
        if (directory != null) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory(directory).createSync(recursive: true);
            await File(
              '$directory/account-$locale-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (directory != null && locale == 'en' && dark) {
          Future<void> capture(String state) async {
            await tester.pump();
            await tester.runAsync(() async {
              final image =
                  await (key.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$directory/delete-$state.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await tester.tap(find.byKey(const ValueKey('account-delete-start')));
          await tester.pump();
          await capture('input');
          await tester.enterText(find.byType(TextField), 'DELETE MY ACCOUNT');
          await tester.pump();
          await tester.pump(const Duration(seconds: 5));
          await capture('fill');
          await tester.pump(const Duration(milliseconds: 5020));
          await capture('ready');
          // Do not invoke destructive action while capturing the real page.
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
        }
        // Test larger accessibility text against the same narrow window.
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'remaining duration uses expiry and handles missing and expired dates',
    (tester) async {
      for (final expiry in [
        null,
        '2020-01-01T00:00:00Z',
        DateTime.now()
            .add(const Duration(days: 3, hours: 12))
            .toIso8601String(),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              sessionProvider.overrideWith((ref) => _Session(expiry)),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const AccountScreen(),
            ),
          ),
        );
        await tester.pump();
        final label = tester
            .widget<Text>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Text &&
                    widget.key == const ValueKey('account-time-left'),
              ),
            )
            .data;
        expect(
          label,
          expiry == null
              ? '—'
              : expiry.startsWith('2020')
              ? 'Expired'
              : '4 d remaining',
        );
        expect(find.text('Next billing'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
