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
import 'package:oculve/features/settings/presentation/xray_core_settings_screen.dart';
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

  test('DPI Bypass keeps its product name in Turkish', () {
    expect(AppStrings.translate('DPI Bypass', 'tr'), 'DPI Bypass');
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
                source == 'example.com\nsubdomain.example.org' ||
                source.startsWith('https://') ||
                source == 'example.com') {
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
          'DNS & network',
          'Split tunneling',
          'Connection options',
          'Diagnostics',
          'Choose an encrypted DNS provider and lookup address family.',
          'Optional connection adjustments. Defaults work for most people.',
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

  testWidgets('compact translated labels stay legible inside narrow controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(120, 52);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (locale, expected) in [
      (const Locale('en'), 'Connection Settings'),
      (const Locale('es'), 'Ajustes de Conexión'),
      (const Locale('tr'), 'Bağlantı Ayarları'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: supportedAppLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 96,
                child: localized.CompactLabel(
                  'Connection Settings',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text(expected), findsOneWidget);
      expect(tester.takeException(), isNull, reason: locale.languageCode);
      expect(
        tester.getSize(find.byType(FittedBox)).width,
        lessThanOrEqualTo(96),
      );
    }
  });

  testWidgets('home controls fit and translate in every supported locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (locale, connectLabel, hintLabel) in [
      (const Locale('en'), 'CONNECT', 'Tap to connect'),
      (const Locale('es'), 'CONECTAR', 'Toca para conectar'),
      (const Locale('tr'), 'BAĞLAN', 'Bağlanmak için dokunun'),
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
      expect(find.text(hintLabel), findsOneWidget);
      expect(tester.takeException(), isNull, reason: locale.languageCode);
    }
  });

  testWidgets('connection settings categories render in Spanish and Turkish', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (locale, dns, split, connectionOptions, diagnostics) in [
      (const Locale('es'), 'DNS', 'TÚNEL DIVIDIDO', 'CONEXIÓN', 'DIAGNÓSTICO'),
      (const Locale('tr'), 'DNS', 'BÖLÜNMÜŞ TÜNELLEME', 'BAĞLANTI', 'TANILAMA'),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: locale,
            supportedLocales: supportedAppLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.darkTheme,
            home: const XrayCoreSettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      for (final heading in [dns, split, connectionOptions, diagnostics]) {
        await tester.scrollUntilVisible(
          find.text(heading),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(heading), findsOneWidget, reason: locale.languageCode);
      }
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
