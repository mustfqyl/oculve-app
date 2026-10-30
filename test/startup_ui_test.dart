import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  testWidgets(
    'custom DNS autosaves valid input and preserves last valid settings',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupServiceProvider.overrideWithValue(
              StartupService(FakeStartupBackend()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const XrayCoreSettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final cloudflare = find.text('Cloudflare');
      expect(tester.widget<Text>(cloudflare).maxLines, 2);
      expect(
        (tester.renderObject(cloudflare) as RenderParagraph).didExceedMaxLines,
        isFalse,
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('dns-provider-row')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }
      final input = find.byKey(const ValueKey('custom-dns-field'));
      expect(find.byKey(const ValueKey('save-custom-dns')), findsNothing);
      expect(tester.widget<TextField>(input).decoration!.labelText, isNull);
      final previous = (await XrayPreferences.userDnsSettings()).servers;
      await tester.enterText(input, 'not a URL');
      await tester.pump(const Duration(milliseconds: 600));
      expect((await XrayPreferences.userDnsSettings()).servers, previous);
      await tester.enterText(input, 'https://resolver.example/dns-query');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 350));
      expect((await XrayPreferences.userDnsSettings()).servers, [
        'https://resolver.example/dns-query',
      ]);
      await tester.enterText(input, 'https://');
      await tester.pump(const Duration(milliseconds: 600));
      expect((await XrayPreferences.userDnsSettings()).servers, [
        'https://resolver.example/dns-query',
      ]);
      await tester.enterText(input, 'https://new.example/dns-query');
      await tester.tap(find.byKey(const ValueKey('dns-provider-row')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect((await XrayPreferences.userDnsSettings()).servers, [
        'https://cloudflare-dns.com/dns-query',
      ]);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('dns-provider-row')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }
      await tester.enterText(
        find.byKey(const ValueKey('custom-dns-field')),
        'https://last.example/dns-query',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect((await XrayPreferences.userDnsSettings()).servers, [
        'https://last.example/dns-query',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['en', 'tr', 'es']) {
    for (final dark in [true, false]) {
      testWidgets('startup inside connection settings $locale dark=$dark', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final backend = FakeStartupBackend();
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              startupServiceProvider.overrideWithValue(StartupService(backend)),
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
                home: const XrayCoreSettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byKey(const ValueKey('startup-mode')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('startup-mode')));
        final initialRowHeight = tester
            .getSize(find.byKey(const ValueKey('startup-mode')))
            .height;
        await tester.tap(find.byKey(const ValueKey('startup-mode')));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const ValueKey('startup-mode')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          (await SharedPreferences.getInstance()).getString(
            StartupService.modeKey,
          ),
          'connect',
        );
        expect(backend.changes, [true, true]);
        expect(
          tester.getSize(find.byKey(const ValueKey('startup-mode'))).height,
          initialRowHeight,
        );
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
        final directory = Platform.environment['OCULVE_STARTUP_PREVIEW'];
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
              '$directory/$suffix-$locale-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('connection');
        await tester.drag(find.byType(ListView).first, const Offset(0, 1400));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.ensureVisible(
          find.byKey(const ValueKey('dns-provider-row')),
        );
        await tester.tap(find.byKey(const ValueKey('dns-provider-row')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
        await capture('dns-cycled');
      });
    }
  }
}
