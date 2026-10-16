import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/providers/locale_provider.dart';
import 'package:oculve/core/providers/theme_provider.dart';
import 'package:oculve/features/splash/presentation/loading_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const launchThemeChannel = MethodChannel('com.oculve/launch_theme');

  test(
    'Android launch appearance follows each persisted theme choice',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final savedModes = <String?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launchThemeChannel, (call) async {
            expect(call.method, 'sync');
            final prefs = await SharedPreferences.getInstance();
            savedModes.add(prefs.getString('app_theme_mode'));
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(launchThemeChannel, null);
      });
      final notifier = ThemeNotifier(restorePreferences: false);
      addTearDown(notifier.dispose);
      await Future.wait([
        notifier.setTheme(AppThemeMode.light),
        notifier.setTheme(AppThemeMode.dark),
        notifier.setTheme(AppThemeMode.auto),
      ]);
      expect(savedModes, ['light', 'dark', 'auto']);
    },
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launchThemeChannel, (_) async => null);
    SharedPreferences.setMockInitialValues({
      'app_language': 'es',
      'app_theme_mode': 'dark',
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launchThemeChannel, null);
  });

  test('native appearance failure does not lose the saved theme', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launchThemeChannel, (_) async {
          throw PlatformException(code: 'unavailable');
        });
    final notifier = ThemeNotifier(restorePreferences: false);
    addTearDown(notifier.dispose);
    await notifier.setTheme(AppThemeMode.light);
    expect(notifier.state, AppThemeMode.light);
    expect(await ThemeNotifier.loadInitialMode(), AppThemeMode.light);
  });
  for (final (mode, brightness) in [
    (AppThemeMode.light, Brightness.light),
    (AppThemeMode.dark, Brightness.dark),
  ]) {
    testWidgets('first loading frame uses stored ${mode.name} theme', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': mode.name});
      final initialMode = await ThemeNotifier.loadInitialMode();
      final notifier = ThemeNotifier(
        initialMode: initialMode,
        restorePreferences: false,
      );
      addTearDown(notifier.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: notifier.state == AppThemeMode.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const LoadingScreen(),
        ),
      );
      expect(
        Theme.of(tester.element(find.byType(LoadingScreen))).brightness,
        brightness,
      );
    });
  }
  test('a new language choice wins over an older pending restore', () async {
    final notifier = LocaleNotifier();
    addTearDown(notifier.dispose);
    final save = notifier.setLanguage('tr');
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, const Locale('tr'));
    await save;
  });
  test('a new theme choice wins over an older pending restore', () async {
    final notifier = ThemeNotifier();
    addTearDown(notifier.dispose);
    final save = notifier.setTheme(AppThemeMode.light);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, AppThemeMode.light);
    await save;
  });
  testWidgets('preference restores do not update disposed notifiers', (
    tester,
  ) async {
    LocaleNotifier().dispose();
    ThemeNotifier().dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('invalid stored appearance types retain usable defaults', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app_language': 42,
      'app_theme_mode': false,
    });
    final locale = LocaleNotifier();
    final theme = ThemeNotifier();
    addTearDown(locale.dispose);
    addTearDown(theme.dispose);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(locale.state, const Locale('en'));
    expect(theme.state, AppThemeMode.auto);
    await locale.setLanguage('tr');
    await theme.setTheme(AppThemeMode.dark);
    expect(locale.state, const Locale('tr'));
    expect(theme.state, AppThemeMode.dark);
  });

  test(
    'auto theme follows local clock with evening and morning boundaries',
    () {
      expect(
        resolveThemeMode(AppThemeMode.auto, DateTime(2026, 1, 1, 5, 59)),
        AppThemeMode.dark,
      );
      expect(
        resolveThemeMode(AppThemeMode.auto, DateTime(2026, 1, 1, 6)),
        AppThemeMode.light,
      );
      expect(
        resolveThemeMode(AppThemeMode.auto, DateTime(2026, 1, 1, 17, 59)),
        AppThemeMode.light,
      );
      expect(
        resolveThemeMode(AppThemeMode.auto, DateTime(2026, 1, 1, 18)),
        AppThemeMode.dark,
      );
    },
  );
}
