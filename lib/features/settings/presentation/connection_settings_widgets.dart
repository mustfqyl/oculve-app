import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:oculve/core/haptics/app_haptics.dart';
import 'package:oculve/core/widgets/inline_feedback.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/theme/app_theme.dart';

Color settingsMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppTheme.foregroundMuted
    : AppTheme.lightForegroundMuted;
WidgetStateProperty<Color?> quietOverlay(BuildContext context) =>
    AppTheme.interactionOverlay(
      isDark: Theme.of(context).brightness == Brightness.dark,
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
    this.valueChild,
    this.trailing,
    this.onTap,
    this.compact = false,
    this.dense = false,
    this.titleStyle,
  });
  final String title;
  final String? subtitle, value;

  /// Custom value widget rendered in the same slot as [value].
  final Widget? valueChild;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool compact, dense;
  final TextStyle? titleStyle;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    overlayColor: quietOverlay(context),
    splashFactory: NoSplash.splashFactory,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: onTap == null && valueChild == null
            ? 0
            : dense
            ? 44
            : 48,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 13 : 16,
          vertical: dense
              ? 12
              : compact
              ? (onTap == null ? 10 : 17)
              : 12,
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
            if (valueChild != null || value != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 116),
                child:
                    valueChild ??
                    Text(
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
              Icon(
                Icons.chevron_right,
                size: 18,
                color: settingsMuted(context),
              ),
            ],
          ],
        ),
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
    this.errors,
  });
  final String title;
  final bool compact;
  final double? topPadding;

  /// When given, a failure of this group is shown in place of the heading.
  final InlineErrorController? errors;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: compact ? 9.5 : 10,
      height: compact ? 1.25 : null,
      letterSpacing: 1,
      fontWeight: FontWeight.w600,
      color: settingsMuted(context),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(0, topPadding ?? (compact ? 14 : 18), 0, 8),
      child: errors == null
          ? Text(title, style: style)
          : InlineErrorCaption(
              title: title,
              controller: errors!,
              titleStyle: style,
            ),
    );
  }
}

/// Style of a row value. Also used to measure values so the slot can reserve a
/// stable size instead of resizing while the value changes.
TextStyle settingsValueStyle(BuildContext context) =>
    DefaultTextStyle.of(context).style.merge(
      TextStyle(fontSize: 12, height: 1.3, color: settingsMuted(context)),
    );

/// Clips the sliding value vertically but lets a glyph run a few pixels past
/// the slot sideways, so a value measured slightly short is never cut.
class _ValueClipper extends CustomClipper<Rect> {
  const _ValueClipper();
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-14, 0, size.width + 14, size.height);
  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class SettingsSlidingValue extends StatelessWidget {
  const SettingsSlidingValue({
    super.key,
    required this.label,
    this.maxLines = 2,
    this.alignment = Alignment.centerRight,
    this.width,
    this.height,
  });
  final String label;
  final int maxLines;
  final Alignment alignment;

  /// When set, the value is laid out in a fixed slot so a new label can never
  /// resize (and thereby shift) the row or the rows below it.
  final double? width, height;
  @override
  Widget build(BuildContext context) {
    final content = ClipRect(
      clipper: const _ValueClipper(),
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
          widthFactor: width == null ? 1 : null,
          child: Text(
            label,
            maxLines: maxLines,
            textAlign: width == null ? null : TextAlign.end,
            style: settingsValueStyle(context),
          ),
        ),
      ),
    );
    if (width == null && height == null) return content;
    return SizedBox(width: width, height: height, child: content);
  }
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

  /// Measures every value this row can show, so the value slot keeps one width
  /// and one height for all of them. The previous value used to wrap to two
  /// lines while the next one fitted on one, which resized the row and pushed
  /// the rows below it up and down on every tap.
  ({double width, double height}) _valueSlot(BuildContext context) {
    final style = settingsValueStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final language = Localizations.localeOf(context).languageCode;
    final values = {label, ...options};
    double widest = 0;
    for (final value in values) {
      final painter = TextPainter(
        text: TextSpan(
          text: AppStrings.translate(value, language),
          style: style,
        ),
        textScaler: scaler,
        textDirection: direction,
        locale: locale,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    // Measured text can come out a little narrower than what the device then
    // paints (fonts, rounding), and a single long word cannot wrap. A margin
    // keeps the last letter of a value from being cut off.
    final width = math.min(128.0, widest * 1.1 + 8);
    var height = 0.0;
    for (final value in values) {
      final painter = TextPainter(
        text: TextSpan(
          text: AppStrings.translate(value, language),
          style: style,
        ),
        textScaler: scaler,
        textDirection: direction,
        locale: locale,
        maxLines: 2,
      )..layout(maxWidth: width);
      height = math.max(height, painter.height);
      painter.dispose();
    }
    return (width: width, height: height + .5);
  }

  @override
  Widget build(BuildContext context) {
    final slot = _valueSlot(context);
    return SettingRow(
      title: title,
      onTap: onTap == null
          ? null
          : () {
              AppHaptics.selection();
              onTap!();
            },
      valueChild: SettingsSlidingValue(
        label: label,
        width: slot.width,
        height: slot.height,
      ),
      trailing: Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Icon(
          Icons.chevron_left,
          size: 18,
          color: settingsMuted(context),
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
        (description == null ? 48 : 64) *
            MediaQuery.textScalerOf(context).scale(1),
      ),
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
          color: selected
              ? AppTheme.successForeground(
                  isDark: Theme.of(context).brightness == Brightness.dark,
                )
              : Colors.transparent,
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
        dense: true,
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
                ? AppTheme.successForeground(
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  )
                : settingsMuted(context),
          ),
        ),
        onTap: widget.enabled && !_busy ? _restore : null,
      ),
    ],
  );
}
