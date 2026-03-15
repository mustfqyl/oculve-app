import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/protocol_provider.dart';

class ModeSelector extends ConsumerWidget {
  const ModeSelector({super.key});

  final List<Map<String, dynamic>> _modes = const [
    {'icon': Icons.bolt, 'label': 'Speed', 'protocol': VpnProtocol.wireguard},
    {'icon': Icons.shield, 'label': 'Privacy', 'protocol': VpnProtocol.vless},
    {
      'icon': Icons.public_off,
      'label': 'Bypass',
      'protocol': VpnProtocol.byedpi,
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final fgSub = isDark
        ? AppTheme.foregroundSubtle
        : AppTheme.lightForegroundSubtle;

    final currentProtocol = ref.watch(protocolProvider);

    return FrostedCard(
      padding: const EdgeInsets.all(4),
      borderRadius: 14,
      blurAmount: 25,
      child: Row(
        children: List.generate(_modes.length, (index) {
          final modeProtocol = _modes[index]['protocol'] as VpnProtocol;
          final isSelected = currentProtocol == modeProtocol;

          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(protocolProvider.notifier).state = modeProtocol,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.08))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(
                      _modes[index]['icon'] as IconData,
                      color: isSelected ? fg : fgSub,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _modes[index]['label'] as String,
                      style: TextStyle(
                        color: isSelected ? fg : fgSub,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
