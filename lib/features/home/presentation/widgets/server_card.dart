import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/core/localization/app_strings.dart';
import '../server_selection_screen.dart';
import 'country_icon.dart';
import 'latency_label.dart';

class ServerCard extends ConsumerWidget {
  const ServerCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(sessionProvider).valueOrNull?.profiles ?? [];
    final id = ref.watch(selectedServerProvider);
    final isOptimal = id == optimalServerId;
    final profile = isOptimal || profiles.isEmpty
        ? null
        : profiles.firstWhere((p) => p.id == id, orElse: () => profiles.first);
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
              onTap: () => Navigator.push(
                context,
                appRoute(const ServerSelectionScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    FrostedCircle(
                      size: 30,
                      blurAmount: 15,
                      color: isOptimal
                          ? AppTheme.successColor.withValues(alpha: .1)
                          : null,
                      child: isOptimal
                          ? const Icon(
                              Icons.bolt_rounded,
                              size: 19,
                              color: AppTheme.successColor,
                            )
                          : CountryIcon(flag: profile?.flag, size: 22),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOptimal
                            ? context.tr('Optimal')
                            : profile?.name ?? context.tr('Choose location'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeBody,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (!isOptimal) LatencyLabel(latency: latency),
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
