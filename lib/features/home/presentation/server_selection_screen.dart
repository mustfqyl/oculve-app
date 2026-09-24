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
  bool _refreshingSubscription = true;
  bool _subscriptionRefreshFailed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      try {
        await ref.read(sessionProvider.notifier).refresh();
      } catch (_) {
        if (mounted) setState(() => _subscriptionRefreshFailed = true);
      }
      if (!mounted) return;
      final profiles = ref.read(sessionProvider).valueOrNull?.profiles ?? [];
      for (final profile in profiles) {
        ref.invalidate(serverLatencyProvider(profile.id));
      }
      setState(() => _refreshingSubscription = false);
    });
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
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    final latencies = {
      for (final profile in profiles)
        profile.id: ref.watch(serverLatencyProvider(profile.id)),
    };
    final measured = {
      for (final entry in latencies.entries) entry.key: entry.value.valueOrNull,
    };
    final refreshing = latencies.values.any((value) => value.isLoading);
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
    final serverRows = Column(
      key: ValueKey(orderedIds.join('\u0000')),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: ordered.map((profile) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FrostedCard(
            key: ValueKey('server-${profile.id}'),
            padding: EdgeInsets.zero,
            borderColor: selected == profile.id
                ? (dark
                      ? Colors.white.withValues(alpha: .58)
                      : Colors.black.withValues(alpha: .42))
                : null,
            borderWidth: selected == profile.id ? 1.1 : .5,
            child: ListTile(
              leading: FrostedCircle(
                size: 34,
                blurAmount: 15,
                child: CountryIcon(flag: profile.flag, size: 24),
              ),
              title: Text(profile.name),
              trailing: LatencyLabel(latency: latencies[profile.id]!),
              enabled: enabled,
              onTap: () {
                ref.read(selectedServerProvider.notifier).state = profile.id;
                Navigator.pop(context);
              },
            ),
          ),
        );
      }).toList(),
    );
    return AppPage(
      title: context.tr('Locations'),
      action: Semantics(
        button: true,
        label: _sort == ServerSort.latency
            ? context.tr('Sorted by ping. Tap to sort alphabetically.')
            : context.tr('Sorted alphabetically. Tap to sort by ping.'),
        child: Tooltip(
          message: _sort == ServerSort.latency
              ? context.tr('Sorted by ping. Tap to sort alphabetically.')
              : context.tr('Sorted alphabetically. Tap to sort by ping.'),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('server-sort-toggle'),
              borderRadius: BorderRadius.circular(11),
              onTap: () => setState(
                () => _sort = _sort == ServerSort.latency
                    ? ServerSort.alphabetical
                    : ServerSort.latency,
              ),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: .045)
                      : Colors.black.withValues(alpha: .035),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withValues(alpha: .10)
                        : Colors.black.withValues(alpha: .09),
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _sort == ServerSort.latency
                          ? Icons.sort_by_alpha_rounded
                          : Icons.speed_rounded,
                      size: 15,
                      color: sortForeground,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _sort == ServerSort.latency ? 'PING' : 'A–Z',
                      style: TextStyle(
                        color: sortForeground,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .65,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_refreshingSubscription)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    context.tr('Refreshing servers…'),
                    style: TextStyle(color: sortForeground, fontSize: 11),
                  ),
                ],
              ),
            ),
          if (_subscriptionRefreshFailed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                context.tr(
                  'Could not refresh servers. Showing the last saved locations.',
                ),
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 11,
                ),
              ),
            ),
          if (!enabled)
            Padding(
              padding: EdgeInsets.only(bottom: 16),
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
              child: ListTile(
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
                title: Text(context.tr('Optimal')),
                subtitle: Text(
                  context.tr('Automatic selection'),
                  style: const TextStyle(fontSize: 11),
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
          if (ordered.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              reverseDuration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: serverRows,
            ),
        ],
      ),
    );
  }
}
