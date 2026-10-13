import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:flutter/scheduler.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'widgets/country_icon.dart';
import 'widgets/dpi_bypass_logo.dart';
import 'widgets/latency_label.dart';
import 'package:oculve/core/localization/app_strings.dart';

enum ServerSort { latency, alphabetical }

class ServerSelectionScreen extends ConsumerStatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  ConsumerState<ServerSelectionScreen> createState() =>
      _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends ConsumerState<ServerSelectionScreen> {
  ServerSort _sort = ServerSort.latency;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      try {
        await ref.read(sessionProvider.notifier).refresh();
      } catch (error) {
        if (mounted) {
          AppFeedback.showError(
            context,
            error,
            fallback:
                'Could not refresh servers. Showing the last saved locations.',
            placement: AppFeedbackPlacement.pageTop,
          );
        }
      }
      if (!mounted) return;
      final profiles = ref.read(sessionProvider).valueOrNull?.profiles ?? [];
      for (final profile in profiles) {
        ref.invalidate(serverLatencyProvider(profile.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(sessionProvider).valueOrNull?.profiles ?? [];
    final selected = ref.watch(selectedServerProvider);
    final vpn = ref.watch(vpnProvider);
    final enabled = vpn != VpnState.connecting && vpn != VpnState.disconnecting;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sortForeground = dark
        ? AppTheme.foreground
        : AppTheme.lightForeground;
    final sortHint = _sort == ServerSort.latency
        ? context.tr('Sorted by ping. Tap to sort alphabetically.')
        : context.tr('Sorted alphabetically. Tap to sort by ping.');
    final rawLatencies = {
      for (final profile in profiles)
        profile.id: ref.watch(serverLatencyProvider(profile.id)),
    };
    final lastKnownLatencies = ref.watch(serverLatencyLastKnownProvider);
    final latencies = {
      for (final entry in rawLatencies.entries)
        entry.key: retainLastKnownLatency(
          entry.value,
          lastKnownLatencies[entry.key],
        ),
    };
    final measured = {
      for (final entry in latencies.entries) entry.key: entry.value.valueOrNull,
    };
    final refreshing = rawLatencies.values.any((value) => value.isLoading);
    final savedIds = ref.watch(serverLatencyDisplayOrderProvider);
    final profileById = {for (final profile in profiles) profile.id: profile};
    final stableProfiles = <VpnProfile>[
      ...savedIds.map((id) => profileById[id]).whereType<VpnProfile>(),
      ...profiles.where((profile) => !savedIds.contains(profile.id)),
    ];
    final hasPing = measured.values.any((value) => value != null);
    final ordered = _sort == ServerSort.alphabetical
        ? sortProfilesAlphabetically(profiles)
        : refreshing || !hasPing
        ? stableProfiles
        : sortProfilesByLatency(stableProfiles, measured);
    final orderedIds = ordered.map((profile) => profile.id).toList();
    if (_sort == ServerSort.latency && !refreshing && hasPing) {
      final nextOrderKey = orderedIds.join('\u0000');
      final currentOrderKey = savedIds.join('\u0000');
      if (nextOrderKey != currentOrderKey) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              ref.read(serverLatencyDisplayOrderProvider).join('\u0000') !=
                  nextOrderKey) {
            ref.read(serverLatencyDisplayOrderProvider.notifier).state =
                orderedIds;
          }
        });
      }
    }
    final serverRows = ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ordered.length,
      itemBuilder: (context, index) {
        final profile = ordered[index];
        final isSelected = selected == profile.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: FrostedCard(
            key: ValueKey('server-${profile.id}'),
            padding: EdgeInsets.zero,
            borderRadius: 14,
            borderColor: isSelected
                ? (dark
                      ? Colors.white.withValues(alpha: .58)
                      : Colors.black.withValues(alpha: .42))
                : null,
            borderWidth: isSelected ? 1.1 : 0.5,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                dense: true,
                minTileHeight: 56,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: FrostedCircle(
                  size: 34,
                  blurAmount: 15,
                  child: CountryIcon(flag: profile.flag, size: 24),
                ),
                title: Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: LatencyLabel(latency: latencies[profile.id]!),
                enabled: enabled,
                onTap: () {
                  unawaited(
                    ref.read(vpnProvider.notifier).selectServer(profile.id),
                  );
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        );
      },
    );
    return AppPage(
      title: context.tr('Locations'),
      action: IconButton(
        key: const ValueKey('server-sort-toggle'),
        splashRadius: 20,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: Icon(
            _sort == ServerSort.latency
                ? Icons.bolt_rounded
                : Icons.sort_by_alpha_rounded,
            key: ValueKey(_sort),
            size: 21,
            color: sortForeground,
            semanticLabel: sortHint,
          ),
        ),
        onPressed: () => setState(
          () => _sort = _sort == ServerSort.latency
              ? ServerSort.alphabetical
              : ServerSort.latency,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (profiles.isEmpty)
            Text(context.tr('No servers available. Check your subscription.')),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: _ServerModeCard(
                    key: const ValueKey('optimal-server-card'),
                    label: context.tr('Optimal'),
                    selected: selected == optimalServerId,
                    enabled: enabled,
                    accentColor: AppTheme.successColor,
                    icon: const Icon(
                      Icons.bolt_rounded,
                      size: 21,
                      color: AppTheme.successColor,
                    ),
                    onTap: () {
                      unawaited(
                        ref
                            .read(vpnProvider.notifier)
                            .selectServer(optimalServerId),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ServerModeCard(
                    key: const ValueKey('dpi-bypass-server-card'),
                    label: context.tr('DPI Bypass'),
                    selected: selected == dpiBypassServerId,
                    enabled: enabled,
                    accentColor: Colors.blueAccent,
                    icon: const DpiBypassLogo(),
                    onTap: () {
                      unawaited(
                        ref
                            .read(vpnProvider.notifier)
                            .selectServer(dpiBypassServerId),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: .12)
                  : Colors.black.withValues(alpha: .1),
            ),
          ),
          if (ordered.isNotEmpty) serverRows,
        ],
      ),
    );
  }
}

class _ServerModeCard extends StatelessWidget {
  const _ServerModeCard({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.accentColor,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final Color accentColor;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: EdgeInsets.zero,
      borderRadius: 14,
      borderColor: selected ? accentColor.withValues(alpha: .75) : null,
      borderWidth: selected ? 1.1 : .5,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 82),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FrostedCircle(
                    size: 36,
                    blurAmount: 15,
                    color: accentColor.withValues(alpha: .1),
                    child: icon,
                  ),
                  const SizedBox(height: 6),
                  CompactLabel(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
