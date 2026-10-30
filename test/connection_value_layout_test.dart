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
import 'package:oculve/features/settings/presentation/connection_settings_widgets.dart';
import 'package:oculve/features/settings/presentation/xray_core_settings_screen.dart';
import 'startup_service_test.dart' show FakeStartupBackend;

/// Fails when the rendered value is cut off, either by a horizontal clip or by
/// an exhausted line budget.
void _expectValueFullyVisible(WidgetTester tester, String value) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.text(value), matching: find.byType(RichText)),
  );
  expect(paragraph.didExceedMaxLines, isFalse, reason: '$value is truncated');
  // A line wider than the paragraph box is painted outside it and then cut by
  // the value's ClipRect, which happens when one word cannot fit the slot.
  final painter = TextPainter(
    text: paragraph.text,
    textScaler: paragraph.textScaler,
    textDirection: paragraph.textDirection,
    textAlign: paragraph.textAlign,
    maxLines: paragraph.maxLines,
  )..layout(maxWidth: paragraph.size.width);
  for (final line in painter.computeLineMetrics()) {
    expect(
      line.width,
      lessThanOrEqualTo(paragraph.size.width + 0.5),
      reason: '$value is clipped horizontally',
    );
  }
  painter.dispose();
}

Widget _connectionScreen(
  TextScaler textScaler, {
  Size size = const Size(360, 640),
  bool disableAnimations = true,
}) => ProviderScope(
  overrides: [
    startupServiceProvider.overrideWithValue(
      StartupService(FakeStartupBackend()),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('tr'), Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: textScaler,
        disableAnimations: disableAnimations,
      ),
      child: const XrayCoreSettingsScreen(),
    ),
  ),
);

Future<void> _pumpConnectionScreen(
  WidgetTester tester, {
  required Size size,
  required TextScaler textScaler,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _connectionScreen(textScaler, size: size, disableAnimations: false),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

/// Fails when the row resized or when any row below it moved, including while
/// the value cross-fade is still running.
void _expectLayoutUnchanged(
  WidgetTester tester,
  Finder row,
  Finder below,
  double height,
  double top,
) {
  expect(tester.getSize(row).height, height, reason: 'the row resized');
  // Measured against the row itself, so the list settling its own scroll
  // position (its extent is only estimated until every row is built) is not
  // mistaken for a row moving.
  expect(
    tester.getTopLeft(below).dy - tester.getTopLeft(row).dy,
    closeTo(top, .01),
    reason: 'a row below the value moved',
  );
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

  testWidgets('connection values stay readable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_connectionScreen(TextScaler.noScaling));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dns-provider-row')),
      150,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cloudflare'), findsOneWidget);
    _expectValueFullyVisible(tester, 'Cloudflare');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dpi-strategy')),
      150,
    );
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('dpi-strategy')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(await DpiPreferences.read(), DpiStrategy.profile4);
    expect(find.text('Reorder & split'), findsOneWidget);
    _expectValueFullyVisible(tester, 'Reorder & split');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cycle row wraps a long value instead of clipping it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsGroup(
                  children: [
                    SettingsCycleRow(
                      title: 'Strategy',
                      label: 'Reorder & split',
                      options: const ['Reorder & split'],
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Reorder & split'), findsOneWidget);
    _expectValueFullyVisible(tester, 'Reorder & split');
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  final variants = [
    (size: const Size(360, 640), scaler: TextScaler.noScaling, name: '360px'),
    (
      size: const Size(320, 568),
      scaler: const TextScaler.linear(2),
      name: '320px with 2x text',
    ),
  ];

  for (final variant in variants) {
    testWidgets('IP lookup cycle keeps its height (${variant.name})', (
      tester,
    ) async {
      const labels = ['Network-aware', 'IPv4 + IPv6', 'IPv4 only', 'IPv6 only'];
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: variant.size,
              textScaler: variant.scaler,
            ),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SettingsGroup(
                    children: [
                      StatefulBuilder(
                        builder: (context, setState) => SettingsCycleRow(
                          key: const ValueKey('ip-lookup'),
                          title: 'IP lookup',
                          label: labels[index],
                          options: labels,
                          onTap: () => setState(
                            () => index = (index + 1) % labels.length,
                          ),
                        ),
                      ),
                      const SettingRow(title: 'Below the value'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final row = find.byKey(const ValueKey('ip-lookup'));
      final below = find.text('Below the value');
      final height = tester.getSize(row).height;
      final top = tester.getTopLeft(below).dy - tester.getTopLeft(row).dy;
      for (var i = 0; i < labels.length; i++) {
        await tester.tap(row);
        await tester.pump();
        _expectLayoutUnchanged(tester, row, below, height, top);
        await tester.pump(const Duration(milliseconds: 80));
        _expectLayoutUnchanged(tester, row, below, height, top);
        await tester.pump(const Duration(milliseconds: 400));
        _expectLayoutUnchanged(tester, row, below, height, top);
        expect(find.text(labels[(i + 1) % labels.length]), findsOneWidget);
        _expectValueFullyVisible(tester, labels[(i + 1) % labels.length]);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'DPI strategy keeps its height while cycling (${variant.name})',
      (tester) async {
        await _pumpConnectionScreen(
          tester,
          size: variant.size,
          textScaler: variant.scaler,
        );
        final row = find.byKey(const ValueKey('dpi-strategy'));
        await tester.scrollUntilVisible(row, 150);
        await tester.ensureVisible(row);
        await tester.pump(const Duration(milliseconds: 350));

        final below = find.byKey(const ValueKey('dpi-retry'));
        expect(below, findsOneWidget);
        final height = tester.getSize(row).height;
        final top = tester.getTopLeft(below).dy - tester.getTopLeft(row).dy;
        final labels = <String>{};
        Future<void> cycle() async {
          await tester.tap(row);
          await tester.pump();
          _expectLayoutUnchanged(tester, row, below, height, top);
          await tester.pump(const Duration(milliseconds: 80));
          _expectLayoutUnchanged(tester, row, below, height, top);
          await tester.pump(const Duration(milliseconds: 400));
          _expectLayoutUnchanged(tester, row, below, height, top);
          labels.add(tester.widget<SettingsCycleRow>(row).label);
        }

        for (var i = 0; i < DpiStrategy.values.length - 1; i++) {
          await cycle();
        }
        expect(find.text('Reorder & split'), findsOneWidget);
        _expectValueFullyVisible(tester, 'Reorder & split');
        await cycle();
        expect(labels.length, DpiStrategy.values.length);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final variant in variants) {
    testWidgets('DNS provider presets keep the row height (${variant.name})', (
      tester,
    ) async {
      await _pumpConnectionScreen(
        tester,
        size: variant.size,
        textScaler: variant.scaler,
      );
      final row = find.byKey(const ValueKey('dns-provider-row'));
      await tester.scrollUntilVisible(row, 150);
      await tester.ensureVisible(row);
      await tester.pump(const Duration(milliseconds: 350));

      final below = find.byKey(const ValueKey('dns-strategy-row'));
      final height = tester.getSize(row).height;
      final top = tester.getTopLeft(below).dy - tester.getTopLeft(row).dy;
      for (var i = 0; i < 2; i++) {
        await tester.tap(row);
        await tester.pump();
        _expectLayoutUnchanged(tester, row, below, height, top);
        await tester.pump(const Duration(milliseconds: 80));
        _expectLayoutUnchanged(tester, row, below, height, top);
        await tester.pump(const Duration(milliseconds: 400));
        _expectLayoutUnchanged(tester, row, below, height, top);
      }
      // The custom field is added below the row; the row itself must not resize.
      await tester.tap(row);
      await tester.pump();
      expect(tester.getSize(row).height, height);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(row).height, height);
      expect(find.byKey(const ValueKey('custom-dns-field')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('cycle row keeps its height while its tap is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 640)),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsGroup(
                  children: [
                    SettingsCycleRow(
                      key: const ValueKey('enabled'),
                      title: 'Strategy',
                      label: 'Split',
                      options: const ['Split'],
                      onTap: () {},
                    ),
                    SettingsCycleRow(
                      key: const ValueKey('disabled'),
                      title: 'Strategy',
                      label: 'Split',
                      options: const ['Split'],
                      onTap: null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('disabled'))).height,
      tester.getSize(find.byKey(const ValueKey('enabled'))).height,
      reason: 'a busy row must not collapse',
    );
  });
}
