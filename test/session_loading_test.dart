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
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/home/presentation/home_screen.dart';
import 'package:oculve/features/splash/presentation/loading_screen.dart';
import 'package:oculve/features/auth/presentation/widgets/oculve_veil_artwork.dart';
import 'package:oculve/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DeferredRestoreSession extends SessionController {
  _DeferredRestoreSession() : super(OculveApi());

  final restored = Completer<void>();

  @override
  Future<void> restore() async {
    await restored.future;
    state = const AsyncValue.data(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Outfit', '.AppleSystemUIFont']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/Outfit.ttf'))).load();
    }
  });

  testWidgets('session gate holds the branded screen until restore completes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = _DeferredRestoreSession();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: const SessionGate(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LoadingScreen), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(OculveVeilArtwork), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LoadingScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    session.restored.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LoadingScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading screen is icon-only and respects reduced motion', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (locale, theme, expectedLabel, reduceMotion, size) in [
      (
        const Locale('tr'),
        AppTheme.darkTheme,
        'Yükleniyor',
        false,
        const Size(393, 852),
      ),
      (
        const Locale('es'),
        AppTheme.lightTheme,
        'Cargando',
        true,
        const Size(393, 852),
      ),
      (
        const Locale('tr'),
        AppTheme.darkTheme,
        'Yükleniyor',
        false,
        const Size(320, 568),
      ),
      (
        const Locale('es'),
        AppTheme.lightTheme,
        'Cargando',
        true,
        const Size(320, 568),
      ),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('es'), Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: theme,
          themeMode: theme.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: RepaintBoundary(
            key: const ValueKey('loading-preview'),
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.noScaling,
                disableAnimations: reduceMotion,
              ),
              child: const LoadingScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(Text), findsNothing);
      expect(find.byType(OculveVeilArtwork), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('loading-dots')), findsNothing);
      expect(find.bySemanticsLabel(expectedLabel), findsOneWidget);
      final artwork = find.byType(OculveVeilArtwork);
      expect(tester.widget<OculveVeilArtwork>(artwork).progress.value, .5);
      if (reduceMotion) {
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.widget<OculveVeilArtwork>(artwork).progress.value, .5);
      } else {
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byKey(const ValueKey('loading-dots')), findsNothing);
        expect(tester.widget<OculveVeilArtwork>(artwork).progress.value, .5);
      }
      expect(tester.takeException(), isNull);

      final directory = Platform.environment['OCULVE_SESSION_LOADING_PREVIEW'];
      if (directory != null) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('loading-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(directory).createSync(recursive: true);
          await File(
            '$directory/loading-${locale.languageCode}-${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
