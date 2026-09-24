import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'widgets/country_icon.dart';
import 'widgets/latency_label.dart';

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
      title: 'Locations',
      action: PopupMenuButton<ServerSort>(
        tooltip: 'Sort servers',
        icon: const Icon(Icons.sort, size: 20),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF15191F)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: .35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.cardBorder
                : AppTheme.lightCardBorder,
          ),
        ),
        menuPadding: const EdgeInsets.all(6),
        position: PopupMenuPosition.under,
        initialValue: _sort,
        onSelected: (value) => setState(() => _sort = value),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: ServerSort.latency,
            child: _SortMenuItem(
              icon: Icons.bolt_rounded,
              label: 'Best ping',
              selected: _sort == ServerSort.latency,
            ),
          ),
          PopupMenuItem(
            value: ServerSort.alphabetical,
            child: _SortMenuItem(
              icon: Icons.sort_by_alpha_rounded,
              label: 'Alphabetical',
              selected: _sort == ServerSort.alphabetical,
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!enabled)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Disconnect before changing location.'),
            ),
          if (profiles.isEmpty)
            const Text('No servers available. Check your subscription.'),
          ...ordered.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FrostedCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: FrostedCircle(
                    size: 34,
                    blurAmount: 15,
                    child: CountryIcon(flag: p.flag, size: 24),
                  ),
                  title: Text(p.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LatencyLabel(latency: latencies[p.id]!),
                      if (selected == p.id) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check, size: 18),
                      ],
                    ],
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

class _SortMenuItem extends StatelessWidget {
  const _SortMenuItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: selected ? AppTheme.successColor : null),
      const SizedBox(width: 10),
      Expanded(child: Text(label)),
      if (selected) ...[
        const SizedBox(width: 10),
        const Icon(Icons.check_rounded, size: 16, color: AppTheme.successColor),
      ],
    ],
  );
}
