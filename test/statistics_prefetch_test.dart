import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/home/presentation/home_screen.dart';
import 'package:oculve/features/settings/presentation/usage_statistics_screen.dart';
import 'package:oculve/main.dart';

class _RestoredSession extends SessionController {
  _RestoredSession() : super(OculveApi());

  @override
  Future<void> restore() async {
    state = AsyncValue.data(Account({'status': 'expired'}, const []));
  }
}

class _StatisticsApi extends OculveApi {
  final response = Completer<Map<String, dynamic>>();
  int statisticsCalls = 0;

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) {
    expect(path, '/api/user/statistics');
    statisticsCalls++;
    return response.future;
  }
}

Widget _app({required Widget home, required ProviderContainer container}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.darkTheme, home: home),
    );

void main() {
  testWidgets('Statistics is prefetched after session restore and reused', (
    tester,
  ) async {
    final session = _RestoredSession();
    final api = _StatisticsApi();
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) => session),
        apiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(api.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _app(home: const SessionGate(), container: container),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(api.statisticsCalls, 1);

    api.response.complete({
      'summary': {'currentUsedBytes': 1073741824, 'isUnlimited': true},
      'usage': {
        'activeDays': 1,
        'daily30d': [
          {'date': '2026-10-16', 'usedBytes': 1048576},
        ],
        'monthly12m': [],
      },
      'nodes': const <Map<String, dynamic>>[],
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.statisticsCalls, 1);

    await tester.pumpWidget(
      _app(home: const UsageStatisticsScreen(), container: container),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('statistics-card-account')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('statistics-loading-state')),
      findsNothing,
    );
    expect(api.statisticsCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
