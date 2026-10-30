import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/theme/app_theme.dart';

/// One option of a [SettingsSegmentedControl].
class SettingsSegment<T> {
  const SettingsSegment({
    required this.value,
    required this.label,
    this.icon,
    this.semanticsLabel,
    this.key,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? semanticsLabel;
  final Key? key;
}

/// Shared segmented selector. Appearance (theme) and Language both use it so the
/// selected option keeps exactly the same fill, radius and typography.
class SettingsSegmentedControl<T> extends StatelessWidget {
  const SettingsSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.expand = true,
    this.compact = false,
  });

  final List<SettingsSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Whether options split the available width evenly.
  final bool expand;

  /// Compact options drop the 48dp minimum height and add horizontal padding.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.foreground : AppTheme.lightForeground;
    final fgMuted = isDark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final segment in segments)
            _option(context, segment, isDark, fg, fgMuted),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context,
    SettingsSegment<T> segment,
    bool isDark,
    Color fg,
    Color fgMuted,
  ) {
    final isSelected = segment.value == selected;
    void select() => onSelected(segment.value);
    final option = Semantics(
      key: segment.key,
      label: context.tr(segment.semanticsLabel ?? segment.label),
      button: true,
      selected: isSelected,
      onTap: select,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: select,
          borderRadius: BorderRadius.circular(9),
          mouseCursor: SystemMouseCursors.click,
          splashFactory: NoSplash.splashFactory,
          overlayColor: AppTheme.interactionOverlay(isDark: isDark),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 0 : 48),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                vertical: 7,
                horizontal: compact ? 8 : 0,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: isSelected && !isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (segment.icon != null) ...[
                    Icon(
                      segment.icon,
                      size: 16,
                      color: isSelected ? fg : fgMuted,
                    ),
                    const SizedBox(height: 3),
                  ],
                  CompactLabel(
                    segment.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? fg : fgMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return expand ? Expanded(child: option) : option;
  }
}
