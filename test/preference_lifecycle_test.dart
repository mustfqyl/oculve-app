import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/providers/locale_provider.dart';
import 'package:oculve/core/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'app_language': 'es',
      'app_theme_mode': 'dark',
    }),
  );
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
}
