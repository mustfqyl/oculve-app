import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/settings/presentation/usage_statistics_screen.dart';

class _StatisticsApi extends OculveApi {
  _StatisticsApi({this.dailyBytes = 1048576});

  final num dailyBytes;

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async {
    expect(path, '/api/user/statistics');
    return {
      'summary': {
        'currentUsedBytes': 1073741824,
        'lifetimeUsedBytes': 2147483648,
        'remainingBytes': 3221225472,
        'isUnlimited': false,
        'currentPeriodStartedAt': '2026-09-01T00:00:00Z',
        'expiresAt': '2026-10-01T00:00:00Z',
      },
      'usage': {
        'daily30d': [
          {'date': '2026-09-23', 'usedBytes': dailyBytes},
        ],
        'monthly12m': [
          {'month': '2026-09', 'usedBytes': 1073741824},
        ],
        'activeDays': 1,
      },
      'nodes': [
        {'nodeName': 'Istanbul', 'trackedLifetimeBytes': 1073741824},
      ],
      'devices': {'totalRegistered': 2, 'lastSeenAt': '2026-09-23T00:00:00Z'},
    };
  }
}

class _DeferredStatisticsApi extends _StatisticsApi {
  final response = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) => response.future;
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
  testWidgets('statistics do not show a loading screen before cached data', (
    tester,
  ) async {
    final api = _DeferredStatisticsApi();
    addTearDown(api.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: UsageStatisticsScreen()),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('statistics-loading-state')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('statistics-loading-skeleton')),
      findsNothing,
    );
    expect(find.text('Fetching your data'), findsNothing);

    api.response.complete({
      'summary': {'currentUsedBytes': 0, 'isUnlimited': true},
      'usage': {
        'activeDays': 0,
        'daily30d': [
          for (var day = 1; day <= 30; day++)
            {
              'date': '2026-10-${day.toString().padLeft(2, '0')}',
              'usedBytes': 0,
            },
        ],
        'monthly12m': [],
      },
      'nodes': [],
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('DATA USED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final (peak, ceiling) in [
    (0, '1.5'),
    (11, '15'),
    (15, '15'),
    (16, '20'),
    (39, '50'),
  ]) {
    testWidgets('chart uses a readable ceiling for $peak GB', (tester) async {
      final api = _StatisticsApi(dailyBytes: peak * 1073741824);
      addTearDown(api.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: UsageStatisticsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('$ceiling GB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'account statistics show API usage, monthly history and devices',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(_StatisticsApi())],
          child: const MaterialApp(home: UsageStatisticsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('DATA USED'), findsOneWidget);
      expect(find.text('1.00 GB'), findsWidgets);
      expect(find.text('Usage history'), findsOneWidget);
      expect(find.text('Downloaded'), findsOneWidget);
      expect(find.text('Uploaded'), findsOneWidget);
      expect(find.text('Session data not received yet.'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('DATA USED')).dy,
        tester.getTopLeft(find.text('Active days (all time)')).dy,
      );
      expect(
        tester.getTopLeft(find.text('1.00 GB').first).dy,
        tester.getTopLeft(find.text('1')).dy,
      );
      final account = find.byKey(const ValueKey('statistics-card-account'));
      final separators = find.descendant(
        of: account,
        matching: find.byType(VerticalDivider),
      );
      expect(separators, findsNWidgets(2));
      expect(
        tester.getCenter(separators.first).dx,
        tester.getCenter(separators.last).dx,
      );
      expect(
        tester.getTopLeft(find.text('1')).dx,
        tester.getTopLeft(find.byIcon(Icons.arrow_upward)).dx,
      );
      expect(
        tester.getTopLeft(find.text('1.00 GB').first).dx,
        tester.getTopLeft(find.byIcon(Icons.arrow_downward)).dx,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Tooltip &&
              (widget.message?.contains('Session totals are unavailable') ??
                  false),
        ),
        findsNWidgets(2),
      );
      expect(find.text('Server usage'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Active days (all time)'), findsOneWidget);
      expect(find.text('Current period'), findsNothing);
      expect(find.text('Relative to most-used server'), findsNothing);
      expect(find.text('Daily data usage'), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('statistics-period-false')))
            .height,
        48,
      );
      for (final key in [
        'statistics-card-account',
        'statistics-card-history',
        'statistics-card-servers',
      ]) {
        expect(
          tester.getRect(find.byKey(ValueKey(key))).bottom,
          lessThanOrEqualTo(568),
        );
      }
      await tester.tap(find.byKey(const ValueKey('statistics-period-true')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Monthly data usage'), findsNothing);
      expect(find.text('Sep 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'statistics retry and refresh fetch real data while period change stays local',
    (tester) async {
      final api = _RecoveringStatisticsApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: UsageStatisticsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Statistics unavailable'), findsOneWidget);
      api.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('DATA USED'), findsOneWidget);
      expect(api.calls, 2);
      await tester.tap(find.byKey(const ValueKey('statistics-period-true')));
      await tester.pump();
      expect(api.calls, 2);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.refresh));
      await tester.pump();
      expect(api.calls, 3);
    },
  );
  for (final locale in ['en', 'tr', 'es']) {
    for (final dark in [true, false]) {
      for (final (size, scale) in [
        (const Size(320, 568), 1.0),
        (const Size(320, 568), 1.6),
        (const Size(515, 700), 1.0),
        (const Size(515, 700), 1.6),
      ]) {
        testWidgets(
          'statistics reference render $locale dark=$dark $size scale=$scale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final key = GlobalKey();
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  apiProvider.overrideWithValue(_ReferenceStatisticsApi()),
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
                    localizationsDelegates:
                        GlobalMaterialLocalizations.delegates,
                    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: const UsageStatisticsScreen(),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump(const Duration(milliseconds: 350));
            expect(tester.takeException(), isNull);
            expect(find.text(locale == 'tr' ? '30g' : '30d'), findsOneWidget);
            expect(find.text(locale == 'tr' ? '12a' : '12m'), findsOneWidget);
            for (final monthly in [false, true]) {
              final period = tester.widget<InkWell>(
                find.byKey(ValueKey('statistics-period-$monthly')),
              );
              expect(
                period.overlayColor!.resolve({WidgetState.hovered}),
                Colors.transparent,
              );
              expect(
                period.overlayColor!.resolve({WidgetState.focused}),
                isNot(Colors.transparent),
              );
              expect(period.splashFactory, NoSplash.splashFactory);
            }
            final directory = Platform.environment['OCULVE_STATISTICS_PREVIEW'];
            if (directory != null) {
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
                  '$directory/statistics-$locale-${dark ? 'dark' : 'light'}-${size.width.toInt()}-$scale.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            expect(find.byType(SingleChildScrollView), findsOneWidget);
            if (scale == 1) {
              for (final card in [
                'statistics-card-account',
                'statistics-card-history',
                'statistics-card-servers',
              ]) {
                expect(
                  tester.getRect(find.byKey(ValueKey(card))).bottom,
                  lessThanOrEqualTo(size.height),
                  reason: '$card must fit in one screen',
                );
              }
            }
            await tester.ensureVisible(
              find.byKey(const ValueKey('statistics-servers')),
            );
            final servers = tester.widget<IconButton>(
              find.byKey(const ValueKey('statistics-servers')),
            );
            expect(
              find.descendant(
                of: find.byKey(const ValueKey('statistics-servers')),
                matching: find.byIcon(Icons.expand_more),
              ),
              findsOneWidget,
            );
            expect(
              tester
                  .widget<AnimatedRotation>(
                    find.descendant(
                      of: find.byKey(const ValueKey('statistics-servers')),
                      matching: find.byType(AnimatedRotation),
                    ),
                  )
                  .turns,
              0,
            );
            expect(servers.tooltip, isNull);
            expect(
              servers.style!.overlayColor!.resolve({WidgetState.hovered}),
              Colors.transparent,
            );
            expect(
              servers.style!.overlayColor!.resolve({WidgetState.focused}),
              isNot(Colors.transparent),
            );
            final mouse = await tester.createGesture(
              kind: ui.PointerDeviceKind.mouse,
            );
            await mouse.addPointer();
            await mouse.moveTo(
              tester.getCenter(
                find.byKey(const ValueKey('statistics-servers')),
              ),
            );
            await tester.pump(const Duration(seconds: 1));
            expect(find.text('View all servers'), findsNothing);
            await mouse.removePointer();
            await tester.tap(find.byKey(const ValueKey('statistics-servers')));
            await tester.pump(const Duration(milliseconds: 500));
            expect(
              tester
                  .widget<AnimatedRotation>(
                    find.descendant(
                      of: find.byKey(const ValueKey('statistics-servers')),
                      matching: find.byType(AnimatedRotation),
                    ),
                  )
                  .turns,
              .5,
            );
            expect(find.text('extra-3'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

class _ReferenceStatisticsApi extends OculveApi {
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async => {
    'summary': {'currentUsedBytes': 1371.62 * 1073741824, 'isUnlimited': true},
    'usage': {
      'activeDays': 64,
      'daily30d': [
        for (var i = 0; i < 30; i++)
          {
            'date': DateTime(
              2026,
              9,
              13,
            ).add(Duration(days: i)).toIso8601String(),
            'usedBytes':
                [
                  17,
                  8,
                  6,
                  6,
                  13,
                  20,
                  12,
                  10,
                  10,
                  22,
                  31,
                  25,
                  39,
                  13,
                  8,
                  10,
                  6,
                  4,
                  17,
                  8,
                  9,
                  8,
                  15,
                  13,
                  24,
                  19,
                  12,
                  28,
                  19,
                  0,
                ][i] *
                1073741824,
          },
      ],
      'monthly12m': [
        {'month': '2026-09', 'usedBytes': 600 * 1073741824},
        {'month': '2026-10', 'usedBytes': 771.62 * 1073741824},
      ],
    },
    'nodes': [
      {'nodeName': 'tr-ist-01', 'trackedLifetimeBytes': 262.41 * 1073741824},
      {'nodeName': 'de-frg-01', 'trackedLifetimeBytes': 75.62 * 1073741824},
      {'nodeName': 'tr-ist-04', 'trackedLifetimeBytes': 17.44 * 1073741824},
      for (var i = 1; i <= 3; i++)
        {'nodeName': 'extra-$i', 'trackedLifetimeBytes': (4 - i) * 1073741824},
    ],
  };
}

class _RecoveringStatisticsApi extends _StatisticsApi {
  bool fail = true;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async {
    calls++;
    if (fail) {
      throw StateError(
        'Statistics are currently unavailable. Try again shortly.',
      );
    }
    return super.request(path, body: body, method: method, headers: headers);
  }
}
