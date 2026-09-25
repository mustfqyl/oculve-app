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
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'widgets/country_icon.dart';
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
  bool _subscriptionRefreshFailed = false;
  Timer? _refreshFailureTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      try {
        await ref.read(sessionProvider.notifier).refresh();
      } catch (_) {
        if (mounted) {
          _refreshFailureTimer?.cancel();
          setState(() => _subscriptionRefreshFailed = true);
          _refreshFailureTimer = Timer(const Duration(seconds: 6), () {
            if (mounted) setState(() => _subscriptionRefreshFailed = false);
          });
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
  void dispose() {
    _refreshFailureTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(sessionProvider).valueOrNull?.profiles ?? [];
    final selected = ref.watch(selectedServerProvider);
    final vpn = ref.watch(vpnProvider);
    final tunnelMayBeActive = ref.watch(vpnTunnelMayBeActiveProvider);
    final enabled =
        !tunnelMayBeActive &&
        (vpn == VpnState.disconnected || vpn == VpnState.error);
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
                  ref.read(selectedServerProvider.notifier).state = profile.id;
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
        tooltip: sortHint,
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
          if (_subscriptionRefreshFailed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                context.tr(
                  'Could not refresh servers. Showing the last saved locations.',
                ),
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: AppTheme.fontSizeCaption,
                ),
              ),
            ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(context.tr('Disconnect before changing location.')),
            ),
          if (profiles.isEmpty)
            Text(context.tr('No servers available. Check your subscription.')),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FrostedCard(
              key: const ValueKey('optimal-server-card'),
              padding: EdgeInsets.zero,
              borderRadius: 14,
              borderColor: selected == optimalServerId
                  ? AppTheme.successColor.withValues(alpha: .75)
                  : null,
              borderWidth: selected == optimalServerId ? 1.1 : .5,
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
                    color: AppTheme.successColor.withValues(alpha: .1),
                    child: const Icon(
                      Icons.bolt_rounded,
                      size: 21,
                      color: AppTheme.successColor,
                    ),
                  ),
                  title: Text(
                    context.tr('Optimal'),
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    context.tr('Automatic selection'),
                    style: const TextStyle(fontSize: AppTheme.fontSizeCaption),
                  ),
                  enabled: enabled,
                  onTap: () {
                    ref.read(selectedServerProvider.notifier).state =
                        optimalServerId;
                    Navigator.pop(context);
                  },
                ),
              ),
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
