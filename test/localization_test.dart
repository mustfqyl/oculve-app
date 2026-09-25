import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart' as localized;
import 'package:oculve/core/providers/locale_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/home/presentation/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('English is the default and language choice is persisted', () async {
    final notifier = LocaleNotifier();
    expect(notifier.state, const Locale('en'));

    await notifier.setLanguage('tr');

    expect(notifier.state, const Locale('tr'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_language'), 'tr');
    notifier.dispose();
  });

  test(
    'every literal interface phrase has Spanish and Turkish translations',
    () {
      final sources = <String>{};
      final patterns = [
        RegExp(
          r"(?:context|dialogContext)\.tr\(\s*'((?:\\.|[^'])*)'",
          dotAll: true,
        ),
        RegExp(
          r'(?:context|dialogContext)\.tr\(\s*"((?:\\.|[^"])*)"',
          dotAll: true,
        ),
        RegExp(r"\bText\(\s*(?:const\s*)?'((?:\\.|[^'])*)'", dotAll: true),
        RegExp(r'\bText\(\s*(?:const\s*)?"((?:\\.|[^"])*)"', dotAll: true),
        RegExp(
          r'(?:tooltip|labelText|hintText|helperText|semanticsLabel):\s*'
          r"'((?:\\.|[^'])*)'",
          dotAll: true,
        ),
      ];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final contents = entity.readAsStringSync();
        for (final pattern in patterns) {
          for (final match in pattern.allMatches(contents)) {
            final source = match.group(1)!.replaceAll(r'\n', '\n');
            if (source.contains(r'$') ||
                source.trim().isEmpty ||
                source == '.') {
              continue;
            }
            if (RegExp(r'^[0-9]+$').hasMatch(source) ||
                source == 'XXXX-XXXX-XXXX' ||
                source == 'example.com\nsubdomain.example.org') {
              continue;
            }
            if (source.toLowerCase() == 'oculve') continue;
            sources.add(source);
          }
        }
      }

      for (final language in ['es', 'tr']) {
        for (final source in sources) {
          expect(
            AppStrings.hasTranslation(source, language),
            isTrue,
            reason: '$language translation missing for "$source"',
          );
        }
      }
    },
  );

  test(
    'connection setting categories are translated in every app language',
    () {
      for (final language in ['es', 'tr']) {
        for (final source in [
          'DNS & IP',
          'Split tunneling',
          'Advanced',
          'Diagnostics',
          'Keep the server defaults unless troubleshooting a connection.',
        ]) {
          expect(
            AppStrings.hasTranslation(source, language),
            isTrue,
            reason: '$language translation missing for "$source"',
          );
        }
      }
    },
  );

  testWidgets('reviewed interface labels render in Spanish and Turkish', (
    tester,
  ) async {
    for (final (locale, expected) in [
      (const Locale('es'), 'CONECTAR'),
      (const Locale('tr'), 'BAĞLAN'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: supportedAppLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(body: localized.Text('CONNECT')),
        ),
      );

      expect(find.text(expected), findsOneWidget);
    }
  });

  testWidgets('home controls fit and translate in every supported locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (locale, connectLabel) in [
      (const Locale('en'), 'CONNECT'),
      (const Locale('es'), 'CONECTAR'),
      (const Locale('tr'), 'BAĞLAN'),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: locale,
            supportedLocales: supportedAppLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.darkTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text(connectLabel), findsOneWidget);
      expect(tester.takeException(), isNull, reason: locale.languageCode);
    }
  });

  testWidgets('relative day labels use locale-appropriate grammar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: supportedAppLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => localized.Text(context.daysRemaining(1)),
          ),
        ),
      ),
    );

    expect(find.text('1 día restante'), findsOneWidget);
  });
}
