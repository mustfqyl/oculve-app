import 'package:flutter/material.dart';
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

void main() {
  testWidgets(
    'account statistics show API usage, monthly history and devices',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
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
      expect(find.text('Account usage'), findsOneWidget);
      expect(find.text('1.00 GB'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Last 12 months'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Last 12 months'), findsOneWidget);
    },
  );
}
