import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/desktop/tray_click_preferences.dart';
import 'package:oculve/core/desktop/desktop_tray_controller.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/settings/presentation/tray_preferences_screen.dart';
import 'profile_test.dart' show testLink;

class _Session extends SessionController {
  _Session() : super(OculveApi()) {
    state = AsyncValue.data(
      Account(
        {'status': 'active'},
        VpnProfile.parseSubscription(
          testLink.replaceFirst('#Test%20location', '#Netherlands'),
        ),
      ),
    );
  }
}

class _Connected extends VpnNotifier {
  _Connected(super.ref) {
    state = VpnState.connected;
  }
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
  test('overlapping click edits cannot assign the same action', () async {
    final notifier = TrayClickPreferencesNotifier();
    addTearDown(notifier.dispose);
    await notifier.ready;
    final left = notifier.setLeft(TrayClickAction.chooseServer);
    final right = expectLater(
      notifier.setRight(TrayClickAction.chooseServer),
      throwsStateError,
    );
    await Future.wait([left, right]);
    expect(notifier.state.left, TrayClickAction.chooseServer);
    expect(notifier.state.right, TrayClickAction.showMenu);
    // A rejected edit must not poison the next save.
    await notifier.setRight(TrayClickAction.quit);
    final restored = TrayClickPreferencesNotifier();
    addTearDown(restored.dispose);
    await restored.ready;
    expect(restored.state.right, TrayClickAction.quit);
  });
  test('existing click preferences survive new settings and restart', () async {
    SharedPreferences.setMockInitialValues({
      'tray.left_click_action.v1': 'chooseServer',
      'tray.right_click_action.v1': 'toggleConnection',
      'unrelated': 'keep',
    });
    final notifier = TrayClickPreferencesNotifier();
    await notifier.ready;
    expect(notifier.state.left, TrayClickAction.chooseServer);
    await notifier.setHideOnBlur(false);
    await notifier.setCloseAction(TrayCloseAction.quit);
    await notifier.setIndicator(TrayStatusIndicator.appIcon);
    notifier.dispose();
    final restored = TrayClickPreferencesNotifier();
    await restored.ready;
    expect(restored.state.hideOnBlur, isFalse);
    expect(restored.state.closeAction, TrayCloseAction.quit);
    expect(restored.state.indicator, TrayStatusIndicator.appIcon);
    expect(restored.state.right, TrayClickAction.toggleConnection);
    await restored.reset();
    expect(restored.state.left, TrayClickAction.toggleWindow);
    expect(restored.state.hideOnBlur, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getString('unrelated'),
      'keep',
    );
    restored.dispose();
  });
  test('an early edit waits for preference restoration', () async {
    SharedPreferences.setMockInitialValues({
      'tray.left_click_action.v1': 'quit',
    });
    final notifier = TrayClickPreferencesNotifier();
    await notifier.setHideOnBlur(false);
    expect(notifier.state.left, TrayClickAction.quit);
    expect(notifier.state.hideOnBlur, isFalse);
    notifier.dispose();
  });
  test('unknown stored choices fall back safely', () async {
    SharedPreferences.setMockInitialValues({
      'tray.close_action.v1': 'invalid',
      'tray.status_indicator.v1': 'invalid',
    });
    final notifier = TrayClickPreferencesNotifier();
    await notifier.ready;
    expect(notifier.state.closeAction, TrayCloseAction.hide);
    expect(notifier.state.indicator, TrayStatusIndicator.connection);
    notifier.dispose();
  });
  test('native window focus respects the persisted hide preference', () async {
    final calls = <MethodCall>[];
    const window = MethodChannel('window_manager'),
        tray = MethodChannel('tray_manager');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(window, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(tray, (call) async {
      calls.add(call);
      return null;
    });
    final container = ProviderContainer(
      overrides: [sessionProvider.overrideWith((ref) => _Session())],
    );
    final controller = DesktopTrayController(container);
    addTearDown(() async {
      await controller.dispose();
      container.dispose();
      messenger.setMockMethodCallHandler(window, null);
      messenger.setMockMethodCallHandler(tray, null);
    });
    await controller.initialize();
    calls.clear();
    controller.onWindowBlur();
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((call) => call.method == 'hide'), hasLength(1));
    calls.clear();
    await container
        .read(trayClickPreferencesProvider.notifier)
        .setHideOnBlur(false);
    controller.onWindowBlur();
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((call) => call.method == 'hide'), isEmpty);
    controller.onWindowClose();
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((call) => call.method == 'hide'), hasLength(1));
    await container
        .read(trayClickPreferencesProvider.notifier)
        .setIndicator(TrayStatusIndicator.appIcon);
    await Future<void>.delayed(Duration.zero);
    if (!Platform.isLinux) {
      // Linux updates the StatusNotifierItem pixmap over DBus; it does not
      // call tray_manager.setIcon like Windows and macOS do.
      final icon = calls.lastWhere((call) => call.method == 'setIcon');
      expect(
        (icon.arguments as Map)['iconPath'],
        endsWith('assets/tray_icon_idle.png'),
      );
    }
  });
  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ]) {
    for (final locale in ['en', 'tr', 'es']) {
      testWidgets('tray settings fit $platform / $locale', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [sessionProvider.overrideWith((ref) => _Session())],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: Locale(locale),
              supportedLocales: const [
                Locale('en'),
                Locale('tr'),
                Locale('es'),
              ],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: AppTheme.darkTheme.copyWith(platform: platform),
              home: const TrayPreferencesScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(
          tester
              .getSize(find.byKey(const ValueKey('tray-selector-left')))
              .height,
          60,
        );
        await tester.tap(find.byKey(const ValueKey('tray-selector-left')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(Dialog), findsNothing);
        await tester.tap(find.byKey(const ValueKey('tray-selector-left')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          container.read(trayClickPreferencesProvider).left,
          TrayClickAction.chooseServer,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('tray-hide-on-blur')),
        );
        await tester.tap(find.byKey(const ValueKey('tray-hide-on-blur')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          container.read(trayClickPreferencesProvider).hideOnBlur,
          isFalse,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('tray-selector-close')),
          100,
        );
        await tester.tap(find.byKey(const ValueKey('tray-selector-close')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          container.read(trayClickPreferencesProvider).closeAction,
          TrayCloseAction.quit,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final locale in ['en', 'tr', 'es']) {
    for (final dark in [true, false]) {
      testWidgets('render tray page and open menu, dark=$dark / $locale', (
        tester,
      ) async {
        final directory = Platform.environment['OCULVE_TRAY_PREVIEW'];
        tester.view.physicalSize = const Size(360, 648);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final profile = VpnProfile.parseSubscription(
          testLink.replaceFirst('#Test%20location', '#Netherlands'),
        ).single;
        final container = ProviderContainer(
          overrides: [
            sessionProvider.overrideWith((ref) => _Session()),
            vpnProvider.overrideWith((ref) => _Connected(ref)),
          ],
        );
        addTearDown(container.dispose);
        container.read(selectedServerProvider.notifier).state = profile.id;
        final key = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
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
                theme: (dark ? AppTheme.darkTheme : AppTheme.lightTheme)
                    .copyWith(platform: TargetPlatform.linux),
                home: const TrayPreferencesScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        Future<void> capture(String suffix) async {
          if (directory == null) return;
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory(directory).createSync(recursive: true);
            await File(
              '$directory/tray-${dark ? 'dark' : 'light'}-$suffix-$locale.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        expect(find.text('MENU PREVIEW'), findsNothing);
        await capture('page');
        await tester.tap(find.byKey(const ValueKey('tray-selector-left')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        await capture('cycled');
        await tester.tapAt(const Offset(4, 540));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(
          find.text(
            locale == 'tr'
                ? 'Varsayılanlara dön'
                : locale == 'es'
                ? 'Restaurar valores predeterminados'
                : 'Restore defaults',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const ValueKey('confirm')), findsOneWidget);
        await tester.tap(
          find.text(
            locale == 'tr'
                ? 'Varsayılanlara dön'
                : locale == 'es'
                ? 'Restaurar valores predeterminados'
                : 'Restore defaults',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const ValueKey(true)), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const ValueKey(true)), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
