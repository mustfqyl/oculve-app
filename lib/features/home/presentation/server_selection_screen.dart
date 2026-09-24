import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/vpn/server_latency.dart';
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

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(sessionProvider).valueOrNull?.profiles ?? [];
    final selected = ref.watch(selectedServerProvider);
    final vpn = ref.watch(vpnProvider);
    final enabled = vpn == VpnState.disconnected || vpn == VpnState.error;
    final latencies = {
      for (final profile in profiles)
        profile.id: ref.watch(serverLatencyProvider(profile.id)),
    };
    final measured = {
      for (final entry in latencies.entries) entry.key: entry.value.valueOrNull,
    };
    // Wait until measurements finish before moving rows under the pointer.
    final ordered = _sort == ServerSort.alphabetical
        ? sortProfilesAlphabetically(profiles)
        : latencies.values.any((value) => value.isLoading)
        ? profiles
        : sortProfilesByLatency(profiles, measured);
    return AppPage(
      title: context.tr('Locations'),
      action: Tooltip(
        message: _sort == ServerSort.latency
            ? 'Sort alphabetically'.tr(context)
            : 'Sort by ping'.tr(context),
        child: FilledButton.tonalIcon(
          key: const ValueKey('server-sort-toggle'),
          onPressed: () => setState(
            () => _sort = _sort == ServerSort.latency
                ? ServerSort.alphabetical
                : ServerSort.latency,
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(
            _sort == ServerSort.latency
                ? Icons.sort_by_alpha_rounded
                : Icons.bolt_rounded,
            size: 16,
          ),
          label: Text('Sort'.tr(context)),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
          ...ordered.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FrostedCard(
                key: ValueKey('server-${p.id}'),
                padding: EdgeInsets.zero,
                borderColor: selected == p.id
                    ? AppTheme.successColor.withValues(alpha: .75)
                    : null,
                borderWidth: selected == p.id ? 1.1 : .5,
                child: ListTile(
                  leading: FrostedCircle(
                    size: 34,
                    blurAmount: 15,
                    child: CountryIcon(flag: p.flag, size: 24),
                  ),
                  title: Text(p.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [LatencyLabel(latency: latencies[p.id]!)],
                  ),
                  enabled: enabled,
                  onTap: () {
                    ref.read(selectedServerProvider.notifier).state = p.id;
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String tr(BuildContext context) => context.tr(this);
}
