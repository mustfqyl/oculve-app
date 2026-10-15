import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'dpi_bypass_logo.dart';
import '../server_selection_screen.dart';
import 'country_icon.dart';
import 'latency_label.dart';

class ServerCard extends ConsumerWidget {
  const ServerCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final profiles = ref.watch(sessionProvider).valueOrNull?.profiles ?? [];
    final id = ref.watch(selectedServerProvider);
    final isOptimal = id == optimalServerId;
    final isDpiBypass = id == dpiBypassServerId;
    VpnProfile? profile;
    if (!isDpiBypass && profiles.isNotEmpty) {
      if (isOptimal) {
        final resolvedId = ref.watch(optimalServerProfileProvider);
        final lastKnown = ref.watch(serverLatencyLastKnownProvider);
        final latencies = <String, int?>{};
        for (final candidate in profiles) {
          final measured = ref.watch(serverLatencyProvider(candidate.id));
          latencies[candidate.id] = retainLastKnownLatency(
            measured,
            lastKnown[candidate.id],
          ).valueOrNull;
        }
        final preview = resolvedId == null
            ? sortProfilesByLatency(profiles, latencies).first
            : profiles.where((item) => item.id == resolvedId).firstOrNull;
        profile = preview ?? sortProfilesByLatency(profiles, latencies).first;
      } else {
        profile = profiles.firstWhere(
          (p) => p.id == id,
          orElse: () => profiles.first,
        );
      }
    }
    final latency = profile == null
        ? const AsyncValue<int?>.data(null)
        : retainLastKnownLatency(
            ref.watch(serverLatencyProvider(profile.id)),
            ref.watch(serverLatencyLastKnownProvider)[profile.id],
          );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 232),
        child: FrostedCard(
          padding: EdgeInsets.zero,
          blurAmount: 30,
          borderRadius: 14,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              mouseCursor: SystemMouseCursors.click,
              overlayColor: AppTheme.interactionOverlay(isDark: dark),
              onTap: () => Navigator.push(
                context,
                appRoute(const ServerSelectionScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    FrostedCircle(
                      size: 30,
                      blurAmount: 15,
                      color: isOptimal && profile == null
                          ? AppTheme.successColor.withValues(alpha: .1)
                          : isDpiBypass
                          ? Colors.blueAccent.withValues(alpha: .1)
                          : null,
                      child: isDpiBypass
                          ? const DpiBypassLogo(size: 22)
                          : isOptimal && profile == null
                          ? Icon(
                              Icons.bolt_rounded,
                              size: 19,
                              color: AppTheme.successForeground(isDark: dark),
                            )
                          : CountryIcon(flag: profile?.flag, size: 22),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: profile == null
                          ? CompactLabel(
                              isDpiBypass ? 'DPI Bypass' : 'Choose location',
                              textAlign: TextAlign.start,
                              alignment: Alignment.centerLeft,
                              style: const TextStyle(
                                fontSize: AppTheme.fontSizeBody,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Text(
                              profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppTheme.fontSizeBody,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(width: 4),
                    if (profile != null) LatencyLabel(latency: latency),
                    const Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
