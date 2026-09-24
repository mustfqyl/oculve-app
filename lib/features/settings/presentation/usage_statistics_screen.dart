import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/app_strings.dart';
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
      title: context.tr('Statistics'),
      action: IconButton(
        tooltip: context.tr('Refresh statistics'),
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
                padding: const EdgeInsets.all(20),
                child: Text(
                  '${context.tr('Statistics are unavailable')}: ${snapshot.error}',
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
          final dailyMax = daily.fold<double>(
            1,
            (max, day) =>
                math.max(max, (day['usedBytes'] as num?)?.toDouble() ?? 0),
          );
          final monthlyMax = monthly.fold<double>(
            1,
            (max, point) =>
                math.max(max, (point['usedBytes'] as num?)?.toDouble() ?? 0),
          );
          final unlimited = summary['isUnlimited'] == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 3, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _compactCard(
                  context,
                  title: context.tr('Account usage'),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              context,
                              context.tr('Current period'),
                              _gb(summary['currentUsedBytes'] as num?),
                            ),
                          ),
                          Expanded(
                            child: _metric(
                              context,
                              context.tr('Remaining'),
                              unlimited
                                  ? context.tr('Unlimited')
                                  : _gb(summary['remainingBytes'] as num?),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              context,
                              context.tr('Lifetime tracked'),
                              _gb(summary['lifetimeUsedBytes'] as num?),
                            ),
                          ),
                          Expanded(
                            child: _metric(
                              context,
                              context.tr('Active days'),
                              '${usage['activeDays'] ?? 0}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${context.tr('Expires')}  ${_date(summary['expiresAt'])}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: muted, fontSize: 9),
                            ),
                          ),
                          Text(
                            '${devices['totalRegistered'] ?? 0} ${context.tr('Devices').toLowerCase()}',
                            style: TextStyle(color: muted, fontSize: 9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(height: 1, color: muted.withValues(alpha: .2)),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              context,
                              context.tr('Downloaded'),
                              '${((traffic?.download ?? 0) / 1048576).toStringAsFixed(2)} MB',
                            ),
                          ),
                          Expanded(
                            child: _metric(
                              context,
                              context.tr('Uploaded'),
                              '${((traffic?.upload ?? 0) / 1048576).toStringAsFixed(2)} MB',
                            ),
                          ),
                          Text(
                            context.tr('Current VPN session'),
                            style: TextStyle(color: muted, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _compactCard(
                  context,
                  title: context.tr('Usage history'),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 86,
                            child: Text(
                              context.tr('Last 30 days'),
                              style: TextStyle(color: muted, fontSize: 9),
                            ),
                          ),
                          Expanded(
                            child: _barChart(
                              daily,
                              'date',
                              dailyMax,
                              height: 23,
                            ),
                          ),
                        ],
                      ),
                      if (monthly.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Divider(height: 1, color: muted.withValues(alpha: .2)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(
                              width: 86,
                              child: Text(
                                context.tr('Last 12 months'),
                                style: TextStyle(color: muted, fontSize: 9),
                              ),
                            ),
                            Expanded(
                              child: _barChart(
                                monthly,
                                'month',
                                monthlyMax,
                                height: 23,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (nodes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _compactCard(
                    context,
                    title: context.tr('Servers'),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 3,
                      children: [
                        for (final node in nodes.take(3))
                          Text(
                            '${node['nodeName']?.toString() ?? context.tr('Server')}  ${_gb(node['trackedLifetimeBytes'] as num?)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: muted, fontSize: 9),
                          ),
                        if (nodes.length > 3)
                          Text(
                            '+${nodes.length - 3}',
                            style: TextStyle(color: muted, fontSize: 9),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _compactCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) => FrostedCard(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    borderRadius: 13,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );

  Widget _metric(BuildContext context, String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.foregroundMuted
              : AppTheme.lightForegroundMuted,
          fontSize: 9,
        ),
      ),
    ],
  );

  Widget _barChart(
    List<Map> points,
    String dateKey,
    double maxValue, {
    required double height,
  }) => SizedBox(
    height: height,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final point in points)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Tooltip(
                message:
                    '${point[dateKey]}: ${_gb(point['usedBytes'] as num?)}',
                child: FractionallySizedBox(
                  alignment: Alignment.bottomCenter,
                  heightFactor: math.max(
                    .06,
                    ((point['usedBytes'] as num?)?.toDouble() ?? 0) / maxValue,
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
