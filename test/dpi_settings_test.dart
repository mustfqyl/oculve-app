import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/connection/dpi_preferences.dart';
import 'package:oculve/core/desktop/startup_service.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/settings/presentation/xray_core_settings_screen.dart';
import 'package:oculve/features/settings/presentation/dpi_settings.dart';
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
  test(
    'strategy preference defaults safely and saves each engine selection',
    () async {
      SharedPreferences.setMockInitialValues({DpiPreferences.key: 99});
      expect(await DpiPreferences.read(), DpiStrategy.automatic);
      for (final strategy in DpiStrategy.values) {
        await DpiPreferences.save(strategy);
        expect(await DpiPreferences.read(), strategy);
      }
    },
  );
  for (final locale in ['en', 'tr', 'es']) {
    testWidgets(
      'DPI section cycles and fits existing connection page in $locale',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              startupServiceProvider.overrideWithValue(
                StartupService(FakeStartupBackend()),
              ),
            ],
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.darkTheme,
                locale: Locale(locale),
                supportedLocales: const [
                  Locale('en'),
                  Locale('tr'),
                  Locale('es'),
                ],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: const XrayCoreSettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('dpi-strategy')),
          150,
        );
        await tester.ensureVisible(find.byType(DpiSettings));
        await tester.pump(const Duration(milliseconds: 350));
        final directory = Platform.environment['OCULVE_DPI_PREVIEW'];
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
              '$directory/dpi-$locale.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        for (final next in [
          DpiStrategy.profile1,
          DpiStrategy.profile2,
          DpiStrategy.profile3,
          DpiStrategy.profile4,
          DpiStrategy.automatic,
        ]) {
          await tester.tap(find.byKey(const ValueKey('dpi-strategy')).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(await DpiPreferences.read(), next);
          expect(find.byType(Dialog), findsNothing);
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byKey(const ValueKey('dpi-retry')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
