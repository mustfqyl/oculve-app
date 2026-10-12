import 'dart:async';
import 'dart:math' as math;
import 'package:oculve/core/localization/app_strings.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/theme/app_theme.dart';

Color settingsMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppTheme.foregroundMuted
    : AppTheme.lightForegroundMuted;
final quietOverlay = WidgetStateProperty.resolveWith<Color?>(
  (states) =>
      states.contains(WidgetState.focused) &&
          !states.contains(WidgetState.hovered)
      ? Colors.white.withValues(alpha: .08)
      : Colors.transparent,
);

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => FrostedCard(
    padding: EdgeInsets.zero,
    borderRadius: 14,
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: .055)
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                color: settingsMuted(context).withValues(alpha: .16),
              ),
            ),
          children[i],
        ],
      ],
    ),
  );
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.compact = false,
    this.titleStyle,
  });
  final String title;
  final String? subtitle, value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool compact;
  final TextStyle? titleStyle;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    overlayColor: quietOverlay,
    splashFactory: NoSplash.splashFactory,
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 13 : 16,
        vertical: compact ? 10 : 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    height: compact ? 1.25 : null,
                    fontWeight: compact ? FontWeight.w600 : FontWeight.w500,
                  ).merge(titleStyle),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: settingsMuted(context),
                      fontSize: compact ? 10.5 : 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 116),
              child: Text(
                value!,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: settingsMuted(context),
                  fontSize: 12,
                  height: compact ? 1.25 : null,
                ),
              ),
            ),
          ],
          if (trailing != null)
            trailing!
          else if (onTap != null) ...[
            const SizedBox(width: 5),
            Icon(Icons.chevron_right, size: 18, color: settingsMuted(context)),
          ],
        ],
      ),
    ),
  );
}

class SettingsCaption extends StatelessWidget {
  const SettingsCaption(
    this.title, {
    super.key,
    this.compact = false,
    this.topPadding,
  });
  final String title;
  final bool compact;
  final double? topPadding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(0, topPadding ?? (compact ? 14 : 18), 0, 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: compact ? 9.5 : 10,
        height: compact ? 1.25 : null,
        letterSpacing: 1,
        fontWeight: FontWeight.w600,
        color: settingsMuted(context),
      ),
    ),
  );
}

class SettingsSlidingValue extends StatelessWidget {
  const SettingsSlidingValue({
    super.key,
    required this.label,
    this.maxLines = 2,
    this.alignment = Alignment.centerRight,
  });
  final String label;
  final int maxLines;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: Offset(child.key == ValueKey(label) ? 1 : -1, 0),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Align(
        key: ValueKey(label),
        alignment: alignment,
        child: Text(
          label,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 12,
            height: 1.3,
            color: settingsMuted(context),
          ),
        ),
      ),
    ),
  );
}

class SettingsCycleRow extends StatelessWidget {
  const SettingsCycleRow({
    super.key,
    required this.title,
    required this.label,
    required this.options,
    required this.onTap,
  });
  final String title, label;
  final List<String> options;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double width = 0;
    for (final option in [...options, label]) {
      final painter = TextPainter(
        text: TextSpan(
          text: context.tr(option),
          style: DefaultTextStyle.of(
            context,
          ).style.merge(const TextStyle(fontSize: 12, height: 1.3)),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      width = math.max(width, painter.width + 2);
      painter.dispose();
    }
    final wrapped = width > 116 * scaler.scale(1);
    width = math.min(width, 116 * scaler.scale(1));
    return SettingRow(
      title: title,
      onTap: onTap,
      trailing: Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              height: (wrapped ? 32 : 24) * scaler.scale(1),
              child: SettingsSlidingValue(
                label: label,
                maxLines: wrapped ? 2 : 1,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.chevron_left, size: 18, color: settingsMuted(context)),
          ],
        ),
      ),
    );
  }
}

LinearGradient settingsMenuGradient(BuildContext context) => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: Theme.of(context).brightness == Brightness.dark
      ? const [Color(0xE6333740), Color(0xEB141D2B)]
      : const [Color(0xEBF8F9FC), Color(0xE6E4E9F2)],
);

class SettingsMenuSurface extends StatelessWidget {
  const SettingsMenuSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: settingsMenuGradient(context)),
        child: Material(color: Colors.transparent, child: child),
      ),
    ),
  );
}

class SettingsOptionDivider extends StatelessWidget {
  const SettingsOptionDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Divider(
      height: 1,
      thickness: .5,
      color: settingsMuted(context).withValues(alpha: .18),
    ),
  );
}

class SettingsChoiceRow extends StatelessWidget {
  const SettingsChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
  });
  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      minimumSize: Size.fromHeight(
        (description == null ? 44 : 64) *
            MediaQuery.textScalerOf(context).scale(1),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      foregroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.foreground
          : AppTheme.lightForeground,
      overlayColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(
        fontFamily: 'Outfit',
        fontSize: 11.5,
        height: 1.3,
        fontWeight: FontWeight.w500,
      ),
    ),
    onPressed: onTap,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 2,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 3),
                Text(
                  description!,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    color: settingsMuted(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.check,
          size: 15,
          color: selected ? AppTheme.successColor : Colors.transparent,
        ),
      ],
    ),
  );
}

Future<T?> chooseSetting<T>(
  BuildContext context,
  String title,
  Map<T, String> options,
  T value, {
  Map<T, String>? descriptions,
}) => showDialog<T>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(24),
    child: SettingsMenuSurface(
      child: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final option in options.entries) ...[
                if (option.key != options.keys.first)
                  const SettingsOptionDivider(),
                SettingsChoiceRow(
                  label: option.value,
                  description: descriptions?[option.key],
                  selected: option.key == value,
                  onTap: () => Navigator.pop(context, option.key),
                ),
              ],
              const SettingsOptionDivider(),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 11.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

class SettingsModal extends StatelessWidget {
  const SettingsModal({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });
  final Widget title, content;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(24),
    child: SettingsMenuSurface(
      child: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  child: title,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 12, height: 1.4),
                  child: content,
                ),
              ),
              const SettingsOptionDivider(),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Wrap(alignment: WrapAlignment.end, children: actions),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SettingsRestoreButton extends StatefulWidget {
  const SettingsRestoreButton({
    super.key,
    required this.onRestore,
    this.enabled = true,
  });
  final Future<bool> Function() onRestore;
  final bool enabled;
  @override
  State<SettingsRestoreButton> createState() => _SettingsRestoreButtonState();
}

class _SettingsRestoreButtonState extends State<SettingsRestoreButton> {
  bool _done = false, _busy = false, _armed = false;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    if (_busy) return;
    if (!_armed) {
      _timer?.cancel();
      setState(() {
        _done = false;
        _armed = true;
      });
      _timer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _armed = false);
      });
      return;
    }
    _timer?.cancel();
    setState(() {
      _armed = false;
      _busy = true;
    });
    try {
      final success = await widget.onRestore();
      if (mounted && success) {
        _timer?.cancel();
        setState(() => _done = true);
        _timer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _done = false);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsGroup(
    children: [
      SettingRow(
        compact: true,
        title: 'Restore defaults',
        titleStyle: TextStyle(
          color: settingsMuted(context),
          fontWeight: FontWeight.w500,
        ),
        trailing: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Icon(
            _armed
                ? Icons.question_mark_rounded
                : _done
                ? Icons.check_rounded
                : Icons.chevron_right,
            key: _armed ? const ValueKey('confirm') : ValueKey(_done),
            size: 18,
            color: _armed
                ? AppTheme.warningColor
                : _done
                ? AppTheme.successColor
                : settingsMuted(context),
          ),
        ),
        onTap: widget.enabled && !_busy ? _restore : null,
      ),
    ],
  );
}
