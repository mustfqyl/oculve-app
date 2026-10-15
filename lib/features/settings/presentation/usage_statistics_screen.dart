import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'connection_settings_widgets.dart';

class UsageStatisticsScreen extends ConsumerStatefulWidget {
  const UsageStatisticsScreen({super.key});
  @override
  ConsumerState<UsageStatisticsScreen> createState() =>
      _UsageStatisticsScreenState();
}

class _UsageStatisticsScreenState extends ConsumerState<UsageStatisticsScreen> {
  late Future<Map<String, dynamic>> _statistics;
  bool _monthly = false, _allServers = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _statistics = ref.read(apiProvider).request('/api/user/statistics');
  }

  double _bytes(Object? value) =>
      value is num && value.isFinite ? math.max(0, value.toDouble()) : 0;
  String _gb(Object? value) =>
      '${(_bytes(value) / 1073741824).toStringAsFixed(2)} GB';
  List<Map> _points(Object? value) =>
      value is List ? value.whereType<Map>().toList() : [];

  @override
  Widget build(BuildContext context) {
    final muted = settingsMuted(context);
    final traffic = ref.watch(trafficProvider);
    return AppPage(
      title: 'Statistics',
      headerHeight: 52,
      action: IconButton(
        icon: Icon(
          Icons.refresh,
          size: 22,
          semanticLabel: context.tr('Refresh statistics'),
        ),
        onPressed: () => setState(_reload),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _statistics,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const _StatisticsLoadingState();
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'Statistics unavailable',
              message: AppFeedback.errorMessage(
                snapshot.error!,
                fallback:
                    'Statistics are currently unavailable. Try again shortly.',
              ),
              primaryLabel: 'Try again',
              onPrimary: () => setState(_reload),
            );
          }
          final response = snapshot.data!;
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
          final maxNode = nodes.fold<double>(
            0,
            (max, node) => math.max(max, _bytes(node['trackedLifetimeBytes'])),
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _card(
                  context,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _caption('ACCOUNT USAGE', muted),
                      const SizedBox(height: 6),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 64,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _gb(summary['currentUsedBytes']),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        height: 1.2,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Current period',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            VerticalDivider(
                              width: 22,
                              thickness: .5,
                              color: muted.withValues(alpha: .25),
                            ),
                            Expanded(
                              flex: 36,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${_bytes(usage['activeDays']).toInt()}',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      context.tr('Active days').toLowerCase(),
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 10,
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
                        const SizedBox(height: 6),
                        Text(
                          '${context.tr('Remaining')}: ${_gb(summary['remainingBytes'])}',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          thickness: .5,
                          color: muted.withValues(alpha: .25),
                        ),
                      ),
                      _caption('CURRENT SESSION', muted),
                      const SizedBox(height: 8),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _transfer(
                                context,
                                Icons.arrow_downward,
                                traffic?.download ?? 0,
                                'Downloaded',
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
                                traffic?.upload ?? 0,
                                'Uploaded',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  key: const ValueKey('statistics-card-account'),
                ),
                const SizedBox(height: 9),
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
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: muted.withValues(alpha: .18),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _period('30 days', false),
                                _period('12 months', true),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _monthly ? 'Monthly data usage' : 'Daily data usage',
                        style: TextStyle(color: muted, fontSize: 10),
                      ),
                      const SizedBox(height: 10),
                      _chart(
                        context,
                        _monthly ? monthly : daily,
                        _monthly ? 'month' : 'date',
                      ),
                    ],
                  ),
                  key: const ValueKey('statistics-card-history'),
                ),
                const SizedBox(height: 9),
                _card(
                  context,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Server usage',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (nodes.isEmpty)
                        Text(
                          'No server usage yet.',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                      for (final node
                          in _allServers ? nodes : nodes.take(3)) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
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
                                        fontSize: 10,
                                        color: muted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _gb(node['trackedLifetimeBytes']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: maxNode > 0
                                      ? (_bytes(node['trackedLifetimeBytes']) /
                                                maxNode)
                                            .clamp(0, 1)
                                      : 0,
                                  minHeight: 4,
                                  color: AppTheme.successForeground(
                                    isDark:
                                        Theme.of(context).brightness ==
                                        Brightness.dark,
                                  ),
                                  backgroundColor: muted.withValues(alpha: .22),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (node != (_allServers ? nodes : nodes.take(3)).last)
                          Divider(
                            height: 1,
                            thickness: .5,
                            color: muted.withValues(alpha: .25),
                          ),
                      ],
                      if (nodes.length > 3) ...[
                        Divider(
                          height: 1,
                          thickness: .5,
                          color: muted.withValues(alpha: .25),
                        ),
                        InkWell(
                          key: const ValueKey('statistics-servers'),
                          onTap: () =>
                              setState(() => _allServers = !_allServers),
                          overlayColor: quietOverlay(context),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _allServers
                                          ? 'Show fewer servers'
                                          : 'View all servers',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _allServers
                                        ? Icons.expand_less
                                        : Icons.chevron_right,
                                    color: muted,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  key: const ValueKey('statistics-card-servers'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, Widget child, {Key? key}) => FrostedCard(
    key: key,
    padding: const EdgeInsets.all(11),
    borderRadius: 13,
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: .055)
        : null,
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
    num bytes,
    String label,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          icon,
          color: AppTheme.successForeground(
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
          size: 18,
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
                '${(_bytes(bytes) / 1048576).toStringAsFixed(2)} MB',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: settingsMuted(context)),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _period(String title, bool monthly) => Semantics(
    button: true,
    selected: _monthly == monthly,
    child: SizedBox(
      height: 48,
      child: InkWell(
        key: ValueKey('statistics-period-$monthly'),
        onTap: () => setState(() => _monthly = monthly),
        borderRadius: BorderRadius.circular(20),
        overlayColor: quietOverlay(context),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _monthly == monthly
                  ? AppTheme.lightSuccessColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: _monthly == monthly
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: _monthly == monthly
                    ? Colors.white
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

  Widget _chart(BuildContext context, List<Map> points, String dateKey) {
    final muted = settingsMuted(context);
    if (points.isEmpty) {
      return SizedBox(
        height: 82,
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
        (normalized <= 2
            ? 2
            : normalized <= 4
            ? 4
            : 10) *
        power;
    String tick(double value) => value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}k'
        : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
    return Column(
      children: [
        SizedBox(
          height: 66,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tick(ceiling)} GB',
                      style: TextStyle(fontSize: 8, color: muted),
                    ),
                    Text(
                      tick(ceiling / 2),
                      style: TextStyle(fontSize: 8, color: muted),
                    ),
                    Text('0', style: TextStyle(fontSize: 8, color: muted)),
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
                                      '${point[dateKey]}: ${_gb(point['usedBytes'])}',
                                  child: FractionallySizedBox(
                                    heightFactor:
                                        (_bytes(point['usedBytes']) /
                                                1073741824 /
                                                ceiling)
                                            .clamp(0, 1),
                                    alignment: Alignment.bottomCenter,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppTheme.successForeground(
                                          isDark:
                                              Theme.of(context).brightness ==
                                              Brightness.dark,
                                        ),
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
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
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

class _StatisticsLoadingState extends StatefulWidget {
  const _StatisticsLoadingState();

  @override
  State<_StatisticsLoadingState> createState() =>
      _StatisticsLoadingStateState();
}

class _StatisticsLoadingStateState extends State<_StatisticsLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.foreground
        : AppTheme.lightForeground;
    return Semantics(
      key: const ValueKey('statistics-loading-state'),
      label: context.tr('Loading statistics'),
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final color = foreground.withValues(
              alpha: .055 + (_pulse.value * .045),
            );
            Widget bar(double width, {double height = 11}) => Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            );

            return SingleChildScrollView(
              key: const ValueKey('statistics-loading-skeleton'),
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FrostedCard(
                    key: const ValueKey('statistics-card-account'),
                    padding: const EdgeInsets.all(11),
                    borderRadius: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: .055)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(104, height: 10),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  bar(132, height: 25),
                                  const SizedBox(height: 2),
                                  bar(88, height: 11),
                                ],
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  bar(74, height: 25),
                                  bar(66, height: 13),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            color: foreground.withValues(alpha: .08),
                            height: 1,
                          ),
                        ),
                        bar(112, height: 11),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _transferPlaceholder(bar)),
                            const SizedBox(width: 12),
                            Expanded(child: _transferPlaceholder(bar)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  FrostedCard(
                    key: const ValueKey('statistics-card-history'),
                    padding: const EdgeInsets.all(11),
                    borderRadius: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: .055)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              bar(98, height: 28),
                              bar(126, height: 28),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        bar(112, height: 12),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 66,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var i = 0; i < 3; i++)
                                bar(double.infinity, height: 1),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            bar(36, height: 10),
                            bar(36, height: 10),
                            bar(36, height: 10),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  FrostedCard(
                    key: const ValueKey('statistics-card-servers'),
                    padding: const EdgeInsets.all(11),
                    borderRadius: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: .055)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(94, height: 16),
                        const SizedBox(height: 4),
                        bar(188, height: 13),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _transferPlaceholder(Widget Function(double, {double height}) bar) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(18, height: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(82, height: 18),
              const SizedBox(height: 1),
              bar(62, height: 12),
            ],
          ),
        ],
      );
}
