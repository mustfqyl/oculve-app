import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';

class UsageStatisticsScreen extends ConsumerStatefulWidget {
  const UsageStatisticsScreen({super.key});
  @override
  ConsumerState<UsageStatisticsScreen> createState() =>
      _UsageStatisticsScreenState();
}

class _UsageStatisticsScreenState extends ConsumerState<UsageStatisticsScreen> {
  late Future<Map<String, dynamic>> _statistics;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      _statistics = ref.read(apiProvider).request('/api/user/statistics');
  String _gb(num? bytes) =>
      '${((bytes ?? 0) / 1073741824).toStringAsFixed(2)} GB';
  String _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '—';
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final traffic = ref.watch(trafficProvider);
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    return AppPage(
      title: 'Statistics',
      action: IconButton(
        tooltip: 'Refresh statistics',
        icon: const Icon(Icons.refresh),
        onPressed: () => setState(_reload),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _statistics,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Statistics are unavailable: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final response = snapshot.data!;
          final summary = response['summary'] is Map
              ? Map<String, dynamic>.from(response['summary'] as Map)
              : <String, dynamic>{};
          final usage = response['usage'] is Map
              ? Map<String, dynamic>.from(response['usage'] as Map)
              : <String, dynamic>{};
          final daily =
              (usage['daily30d'] as List?)?.whereType<Map>().toList() ?? [];
          final monthly =
              (usage['monthly12m'] as List?)?.whereType<Map>().toList() ?? [];
          final nodes =
              (response['nodes'] as List?)?.whereType<Map>().toList() ?? [];
          final devices = response['devices'] is Map
              ? Map<String, dynamic>.from(response['devices'] as Map)
              : <String, dynamic>{};
          final maxDaily = daily.fold<double>(
            1,
            (max, day) =>
                math.max(max, (day['usedBytes'] as num?)?.toDouble() ?? 0),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              _card('Account usage', [
                _row(
                  'Current period',
                  _gb(summary['currentUsedBytes'] as num?),
                  muted,
                ),
                _row(
                  'Lifetime tracked',
                  _gb(summary['lifetimeUsedBytes'] as num?),
                  muted,
                ),
                _row(
                  'Remaining',
                  summary['isUnlimited'] == true
                      ? 'Unlimited'
                      : _gb(summary['remainingBytes'] as num?),
                  muted,
                ),
                _row('Active days', '${usage['activeDays'] ?? 0}', muted),
                _row(
                  'Current cycle began',
                  _date(summary['currentPeriodStartedAt']),
                  muted,
                ),
                _row('Expires', _date(summary['expiresAt']), muted),
                _row(
                  'Registered devices',
                  '${devices['totalRegistered'] ?? 0}',
                  muted,
                ),
                _row('Last seen', _date(devices['lastSeenAt']), muted),
              ]),
              const SizedBox(height: 12),
              _card('Last 30 days', [
                const SizedBox(height: 10),
                SizedBox(
                  height: 72,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final day in daily)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Tooltip(
                              message:
                                  '${day['date']}: ${_gb(day['usedBytes'] as num?)}',
                              child: FractionallySizedBox(
                                alignment: Alignment.bottomCenter,
                                heightFactor: math.max(
                                  .04,
                                  ((day['usedBytes'] as num?)?.toDouble() ??
                                          0) /
                                      maxDaily,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ]),
              if (monthly.isNotEmpty) ...[
                const SizedBox(height: 12),
                _card('Last 12 months', [
                  const SizedBox(height: 10),
                  _barChart(monthly, 'month'),
                ]),
              ],
              if (nodes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _card('Servers', [
                  for (final node in nodes)
                    _row(
                      node['nodeName']?.toString() ?? 'Server',
                      _gb(node['trackedLifetimeBytes'] as num?),
                      muted,
                    ),
                ]),
              ],
              const SizedBox(height: 12),
              _card('Current VPN session', [
                _row(
                  'Downloaded',
                  '${((traffic?.download ?? 0) / 1048576).toStringAsFixed(2)} MB',
                  muted,
                ),
                _row(
                  'Uploaded',
                  '${((traffic?.upload ?? 0) / 1048576).toStringAsFixed(2)} MB',
                  muted,
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => FrostedCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );

  Widget _barChart(List<Map> points, String dateKey) {
    final maxValue = points.fold<double>(
      1,
      (max, point) =>
          math.max(max, (point['usedBytes'] as num?)?.toDouble() ?? 0),
    );
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Tooltip(
                  message:
                      '${point[dateKey]}: ${_gb(point['usedBytes'] as num?)}',
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: math.max(
                      .04,
                      ((point['usedBytes'] as num?)?.toDouble() ?? 0) /
                          maxValue,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.successColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String title, String value, Color muted) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: TextStyle(color: muted, fontSize: 12)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
