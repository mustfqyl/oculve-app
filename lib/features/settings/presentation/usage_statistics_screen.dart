import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/features/settings/providers/statistics_provider.dart';
import 'connection_settings_widgets.dart';

const _byteUnits = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB'];
const _maxDisplayBytes = 1023.94 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024;

Color _statisticsInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppTheme.foreground
    : AppTheme.lightForeground;

Color _statisticsInkForeground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppTheme.backgroundColor
    : Colors.white;

class UsageStatisticsScreen extends ConsumerStatefulWidget {
  const UsageStatisticsScreen({super.key});
  @override
  ConsumerState<UsageStatisticsScreen> createState() =>
      _UsageStatisticsScreenState();
}

class _UsageStatisticsScreenState extends ConsumerState<UsageStatisticsScreen> {
  bool _monthly = false, _allServers = false;

  double _bytes(Object? value) =>
      value is num && value.isFinite ? math.max(0, value.toDouble()) : 0;
  String _formatBytes(Object? value) {
    final bytes = math.min(_bytes(value), _maxDisplayBytes).toDouble();
    if (bytes == 0) return '0 B';
    var scaled = bytes;
    var unitIndex = 0;
    while (scaled >= 1024 && unitIndex < _byteUnits.length - 1) {
      scaled /= 1024;
      unitIndex++;
    }
    if (unitIndex == _byteUnits.length - 1) {
      scaled = math.min(scaled, 1023.94);
    }
    return '${scaled.toStringAsFixed(2)} ${_byteUnits[unitIndex]}';
  }

  List<Map> _points(Object? value) =>
      value is List ? value.whereType<Map>().toList() : [];

  @override
  Widget build(BuildContext context) {
    final muted = settingsMuted(context);
    final traffic = ref.watch(trafficProvider);
    final statistics = ref.watch(statisticsProvider);
    return AppPage(
      title: 'Statistics',
      headerHeight: 52,
      action: IconButton(
        icon: Icon(
          Icons.refresh,
          size: 22,
          semanticLabel: context.tr('Refresh statistics'),
        ),
        onPressed: () => ref.invalidate(statisticsProvider),
      ),
      child: statistics.when(
        loading: () => const SizedBox.expand(),
        error: (error, stackTrace) => AppErrorState(
          title: 'Statistics unavailable',
          message: AppFeedback.errorMessage(
            error,
            fallback:
                'Statistics are currently unavailable. Try again shortly.',
          ),
          primaryLabel: 'Try again',
          onPrimary: () => ref.invalidate(statisticsProvider),
        ),
        data: (response) {
          final summary = response['summary'] is Map
              ? response['summary'] as Map
              : <String, dynamic>{};
          final usage = response['usage'] is Map
              ? response['usage'] as Map
              : <String, dynamic>{};
          final daily = _points(usage['daily30d']);
          final monthly = _points(usage['monthly12m']);
          final nodes = _points(response['nodes'])
            ..sort(
              (a, b) => _bytes(
                b['trackedLifetimeBytes'],
              ).compareTo(_bytes(a['trackedLifetimeBytes'])),
            );
          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth <= 350;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 10 : 12,
                  compact ? 1 : 7,
                  compact ? 10 : 12,
                  compact ? 4 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _card(
                      context,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Tooltip(
                                        message: context.tr(
                                          'Data used in the current account period.',
                                        ),
                                        child: _caption('DATA USED', muted),
                                      ),
                                      SizedBox(height: compact ? 5 : 8),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _formatBytes(
                                            summary['currentUsedBytes'],
                                          ),
                                          style: TextStyle(
                                            fontSize: compact ? 22 : 24,
                                            height: 1.2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                VerticalDivider(
                                  width: 20,
                                  thickness: .5,
                                  indent: 3,
                                  endIndent: 3,
                                  color: muted.withValues(alpha: .25),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.zero,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Active days (all time)',
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 9.5,
                                            height: 1.2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: compact ? 5 : 8),
                                        Text(
                                          '${_bytes(usage['activeDays']).toInt()}',
                                          style: TextStyle(
                                            fontSize: compact ? 22 : 24,
                                            height: 1.2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (summary['isUnlimited'] == false) ...[
                            SizedBox(height: compact ? 3 : 6),
                            Text(
                              '${context.tr('Remaining')}: ${_formatBytes(summary['remainingBytes'])}',
                              style: TextStyle(color: muted, fontSize: 10),
                            ),
                          ],
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 4 : 8,
                            ),
                            child: Divider(
                              height: 1,
                              thickness: .5,
                              color: muted.withValues(alpha: .25),
                            ),
                          ),
                          _caption('CURRENT SESSION', muted),
                          SizedBox(height: compact ? 4 : 8),
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _transfer(
                                    context,
                                    Icons.arrow_downward,
                                    traffic?.download,
                                    'Downloaded',
                                    compact: compact,
                                  ),
                                ),
                                VerticalDivider(
                                  width: 20,
                                  thickness: .5,
                                  color: muted.withValues(alpha: .25),
                                ),
                                Expanded(
                                  child: _transfer(
                                    context,
                                    Icons.arrow_upward,
                                    traffic?.upload,
                                    'Uploaded',
                                    compact: compact,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (traffic == null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Session data not received yet.',
                              style: TextStyle(color: muted, fontSize: 9.5),
                            ),
                          ],
                        ],
                      ),
                      key: const ValueKey('statistics-card-account'),
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 5 : 9),
                    _card(
                      context,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Usage history',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: compact ? 12 : 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _period('30d', false, compact: compact),
                                    _period('12m', true, compact: compact),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 3 : 5),
                          _chart(
                            context,
                            _monthly ? monthly : daily,
                            _monthly ? 'month' : 'date',
                            compact: compact,
                            plotHeight:
                                (constraints.maxHeight -
                                        (compact ? 371 : 438) -
                                        (summary['isUnlimited'] == false
                                            ? (compact ? 16 : 19)
                                            : 0) +
                                        (traffic != null ? 18 : 0))
                                    .clamp(
                                      compact ? 74.0 : 100.0,
                                      double.infinity,
                                    ),
                          ),
                        ],
                      ),
                      key: const ValueKey('statistics-card-history'),
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 5 : 9),
                    _card(
                      context,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Server usage',
                                  style: TextStyle(
                                    fontSize: compact ? 12 : 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (nodes.length > 3)
                                IconButton(
                                  key: const ValueKey('statistics-servers'),
                                  style: ButtonStyle(
                                    overlayColor:
                                        WidgetStateProperty.resolveWith(
                                          (states) =>
                                              states.contains(
                                                WidgetState.focused,
                                              )
                                              ? _statisticsInk(
                                                  context,
                                                ).withValues(alpha: .09)
                                              : Colors.transparent,
                                        ),
                                    splashFactory: NoSplash.splashFactory,
                                  ),
                                  onPressed: () => setState(
                                    () => _allServers = !_allServers,
                                  ),
                                  icon: AnimatedRotation(
                                    turns: _allServers ? .5 : 0,
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                    child: Icon(
                                      Icons.expand_more,
                                      semanticLabel: context.tr(
                                        _allServers
                                            ? 'Show fewer servers'
                                            : 'View all servers',
                                      ),
                                      color: muted,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (nodes.isEmpty)
                            Text(
                              'No server usage yet.',
                              style: TextStyle(color: muted, fontSize: 10),
                            ),
                          for (final node
                              in _allServers ? nodes : nodes.take(3)) ...[
                            Padding(
                              padding: EdgeInsets.only(
                                top: node == nodes.first ? 0 : 9,
                                bottom: 9,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          node['nodeName']?.toString() ??
                                              context.tr('Server'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: compact ? 9.5 : 10,
                                            color: muted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatBytes(
                                          node['trackedLifetimeBytes'],
                                        ),
                                        style: TextStyle(
                                          fontSize: compact ? 9.5 : 10,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      key: const ValueKey('statistics-card-servers'),
                      compact: compact,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _card(
    BuildContext context,
    Widget child, {
    Key? key,
    bool compact = false,
  }) => FrostedCard(
    key: key,
    padding: EdgeInsets.all(compact ? 8 : 11),
    borderRadius: 13,
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: .035)
        : Colors.white.withValues(alpha: .45),
    borderColor: _statisticsInk(context).withValues(alpha: .06),
    child: DefaultTextStyle.merge(
      style: const TextStyle(
        height: 1.25,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
      ),
      child: child,
    ),
  );
  Widget _caption(String title, Color muted) => Text(
    title,
    style: TextStyle(
      color: muted,
      fontSize: 9.5,
      height: 1.2,
      letterSpacing: 1,
      fontWeight: FontWeight.w600,
    ),
  );
  Widget _transfer(
    BuildContext context,
    IconData icon,
    Object? bytes,
    String label, {
    bool compact = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          icon,
          color: _statisticsInk(context),
          size: compact ? 17 : 18,
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                bytes == null ? '—' : _formatBytes(bytes),
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Tooltip(
              message: bytes == null
                  ? context.tr(
                      'Session totals are unavailable until connection data is received.',
                    )
                  : context.tr(label),
              child: Text(
                label,
                semanticsLabel: bytes == null
                    ? '${context.tr(label)}. ${context.tr('Session totals are unavailable until connection data is received.')}'
                    : null,
                style: TextStyle(
                  fontSize: compact ? 9.5 : 10,
                  color: settingsMuted(context),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _period(String title, bool monthly, {bool compact = false}) =>
      Semantics(
        button: true,
        selected: _monthly == monthly,
        child: SizedBox(
          height: 48,
          width: 48,
          child: InkWell(
            key: ValueKey('statistics-period-$monthly'),
            onTap: () => setState(() => _monthly = monthly),
            borderRadius: BorderRadius.circular(20),
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? _statisticsInk(context).withValues(alpha: .09)
                  : Colors.transparent,
            ),
            splashFactory: NoSplash.splashFactory,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _monthly == monthly
                      ? _statisticsInk(context)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  title,
                  semanticsLabel: context.tr(monthly ? '12 months' : '30 days'),
                  style: TextStyle(
                    fontSize: compact ? 9 : 9.5,
                    fontWeight: _monthly == monthly
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: _monthly == monthly
                        ? _statisticsInkForeground(context)
                        : settingsMuted(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  String _pointLabel(BuildContext context, Object? value) {
    final date = DateTime.tryParse(
      '$value'.length == 7 ? '$value-01' : '$value',
    );
    if (date == null) return '—';
    final locale = Localizations.localeOf(context).languageCode;
    const months = {
      'en': [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ],
      'tr': [
        'Oca',
        'Şub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Ağu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara',
      ],
      'es': [
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ],
    };
    final month = (months[locale] ?? months['en']!)[date.month - 1];
    return _monthly ? '$month ${date.year}' : '${date.day} $month';
  }

  Widget _chart(
    BuildContext context,
    List<Map> points,
    String dateKey, {
    bool compact = false,
    double? plotHeight,
  }) {
    final muted = settingsMuted(context);
    if (points.isEmpty) {
      return SizedBox(
        height: compact ? 62 : 82,
        child: Center(
          child: Text(
            'No usage recorded for this period.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ),
      );
    }
    final max = points.fold<double>(
      0,
      (value, p) => math.max(value, _bytes(p['usedBytes']) / 1073741824),
    );
    final power = math
        .pow(10, math.max(0, (math.log(math.max(1, max)) / math.ln10).floor()))
        .toDouble();
    final normalized = max / power;
    final ceiling =
        (normalized <= 1.5
            ? 1.5
            : normalized <= 2
            ? 2
            : normalized <= 3
            ? 3
            : normalized <= 5
            ? 5
            : normalized <= 7.5
            ? 7.5
            : 10) *
        power;
    String tick(double value) => value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}k'
        : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
    return Column(
      children: [
        SizedBox(
          height: plotHeight ?? (compact ? 74 : 100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 42,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tick(ceiling)} GB',
                      style: TextStyle(fontSize: 8, color: muted),
                    ),
                    Text(
                      '${tick(ceiling / 2)} GB',
                      style: TextStyle(fontSize: 8, color: muted),
                    ),
                    Text(
                      '${tick(0)} GB',
                      style: TextStyle(fontSize: 8, color: muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Divider(
                            height: 1,
                            thickness: .5,
                            color: muted.withValues(alpha: .25),
                          ),
                      ],
                    ),
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final point in points)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: Tooltip(
                                  message:
                                      '${point[dateKey]}: ${_formatBytes(point['usedBytes'])}',
                                  child: FractionallySizedBox(
                                    heightFactor:
                                        (_bytes(point['usedBytes']) /
                                                1073741824 /
                                                ceiling)
                                            .clamp(0, 1),
                                    alignment: Alignment.bottomCenter,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: _statisticsInk(context),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(2),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 2 : 4),
        Padding(
          padding: const EdgeInsets.only(left: 42),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final point in [
                points.first,
                if (points.length > 2) points[(points.length - 1) ~/ 2],
                if (points.length > 1) points.last,
              ])
                Text(
                  _pointLabel(context, point[dateKey]),
                  style: TextStyle(fontSize: 8, color: muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
