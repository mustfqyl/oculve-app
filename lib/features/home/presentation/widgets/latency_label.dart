import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/localization/app_strings.dart';

/// Three-bar indicator backed by the node's direct TCP connect time.
class LatencyLabel extends StatelessWidget {
  const LatencyLabel({super.key, required this.latency});

  final AsyncValue<int?> latency;

  @override
  Widget build(BuildContext context) {
    final ms = latency.valueOrNull;
    final bars = latency.isLoading || ms == null
        ? 0
        : ms < 120
        ? 3
        : ms < 250
        ? 2
        : 1;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    final active = bars == 3
        ? AppTheme.successColor
        : bars == 2
        ? AppTheme.warningColor
        : AppTheme.dangerColor;
    final label = latency.isLoading
        ? '…'
        : ms == null
        ? '—'
        : '${ms}ms';
    final accessibleLabel = ms == null
        ? (latency.isLoading
              ? context.tr('Measuring VPN server ping')
              : context.tr('Ping unavailable'))
        : '$ms ${context.tr('milliseconds')}';

    return Tooltip(
      message: label,
      child: Semantics(
        label: accessibleLabel,
        child: ExcludeSemantics(
          child: SizedBox(
            width: 20,
            height: 17,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < 3; index++) ...[
                  if (index > 0) const SizedBox(width: 2),
                  Container(
                    width: 4,
                    height: 6.0 + index * 5,
                    decoration: BoxDecoration(
                      color: index < bars
                          ? active
                          : muted.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
