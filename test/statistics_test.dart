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
      tester.view.physicalSize = const Size(360, 640);
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
      expect(find.text('Account usage'), findsOneWidget);
      expect(find.text('1.00 GB'), findsWidgets);
      expect(find.text('Usage history'), findsOneWidget);
      expect(find.text('Last 12 months'), findsOneWidget);
      expect(find.text('Current VPN session'), findsOneWidget);
      expect(find.text('Servers'), findsOneWidget);
      for (final target in [
        find.text('Account usage'),
        find.text('Usage history'),
        find.text('Last 12 months'),
        find.text('Current VPN session'),
        find.text('Servers'),
      ]) {
        final rect = tester.getRect(target);
        expect(
          rect.top >= 64 && rect.bottom <= 640,
          isTrue,
          reason: '$target should fit in the compact statistics view',
        );
      }
    },
  );
}
