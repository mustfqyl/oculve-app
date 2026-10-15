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
          {'date': '2026-09-23', 'usedBytes': 1048576},
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
  testWidgets(
    'reduced motion statistics loading settles without continuous frames',
    (tester) async {
      final api = _DeferredStatisticsApi();
      addTearDown(api.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(api)],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const UsageStatisticsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.byKey(const ValueKey('statistics-loading-state')),
        findsOneWidget,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('statistics loading uses themed skeleton instead of a spinner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _DeferredStatisticsApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const UsageStatisticsScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('statistics-loading-state')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final cardKeys = [
      'statistics-card-account',
      'statistics-card-history',
      'statistics-card-servers',
    ];
    final loadingHeights = {
      for (final key in cardKeys)
        key: tester.getSize(find.byKey(ValueKey(key))).height,
    };

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
    expect(
      find.byKey(const ValueKey('statistics-loading-state')),
      findsNothing,
    );
    expect(find.text('ACCOUNT USAGE'), findsOneWidget);
    for (final key in cardKeys) {
      final loadedHeight = tester.getSize(find.byKey(ValueKey(key))).height;
      expect(
        loadedHeight,
        closeTo(loadingHeights[key]!, 8),
        reason: '$key should keep its height when loading finishes',
      );
    }
    expect(tester.takeException(), isNull);
  });
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
      expect(find.text('ACCOUNT USAGE'), findsOneWidget);
      expect(find.text('1.00 GB'), findsWidgets);
      expect(find.text('Usage history'), findsOneWidget);
      expect(find.text('CURRENT SESSION'), findsOneWidget);
      expect(find.text('Server usage'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('statistics-period-true')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Monthly data usage'), findsOneWidget);
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
      expect(find.text('ACCOUNT USAGE'), findsOneWidget);
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
      testWidgets('statistics reference render $locale dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
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
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                home: const UsageStatisticsScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
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
              '$directory/statistics-$locale-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('statistics-servers')),
          120,
        );
        await tester.tap(find.byKey(const ValueKey('statistics-servers')));
        await tester.pump();
        await tester.scrollUntilVisible(find.text('extra-3'), 120);
        expect(find.text('extra-3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
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
