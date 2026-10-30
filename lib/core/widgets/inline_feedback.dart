import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';

import 'package:oculve/core/haptics/app_haptics.dart';
import 'package:oculve/core/theme/app_theme.dart';

import 'app_feedback.dart';

/// A line of error text that belongs to the element above it.
///
/// The slot always takes the same height, with or without a message, so a
/// failure never pushes the content below it. The text fades in and out
/// instead of popping; with reduced motion it just swaps.
class InlineErrorSlot extends StatelessWidget {
  const InlineErrorSlot({super.key, required this.message, this.height = 42});

  /// Already user-facing text; null or empty shows nothing.
  final String? message;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = AppFeedback.errorTone(dark: dark);
    final text = (message ?? '').trim();
    return SizedBox(
      height: height,
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: text.isEmpty
            ? const SizedBox.shrink(key: ValueKey('inline-error-empty'))
            : Padding(
                key: ValueKey('inline-error:$text'),
                padding: const EdgeInsets.only(top: 6),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 15,
                          color: tone,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          context.tr(text),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tone,
                            fontSize: 12.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Controls a single inline error line with automatic expiry and
/// immediate clear-on-interaction semantics.
///
/// Usage:
///   final controller = InlineErrorController();
///   // In build:
///   InlineErrorSlot(message: controller.message)
///   // On error:
///   controller.show(error, fallback: 'Something went wrong.');
///   // On any user action that should dismiss:
///   controller.clear();
///   // In dispose:
///   controller.dispose();
class InlineErrorController extends ChangeNotifier {
  InlineErrorController();

  String? _message;
  AppFeedbackKind _kind = AppFeedbackKind.error;
  Timer? _timer;

  String? get message => _message;

  /// Whether the visible line is a failure or a confirmation.
  AppFeedbackKind get kind => _kind;

  /// Shows [error] filtered through [UserFacingFailure.message] with optional
  /// [fallback]. Starts an auto-dismiss timer (4–8s based on length).
  /// Does nothing if the same message is already visible (prevents timer reset).
  void show(Object error, {String? fallback}) {
    final text = AppFeedback.errorMessage(error, fallback: fallback);
    _display(text, AppFeedbackKind.error);
  }

  /// Shows a reviewed [text] that is not an exception, such as a confirmation
  /// ("Access code copied.") or a validation hint.
  void showMessage(
    String text, {
    AppFeedbackKind kind = AppFeedbackKind.success,
  }) => _display(text, kind);

  void _display(String text, AppFeedbackKind kind) {
    if (text == _message && kind == _kind) return; // Don't reset the timer.
    _timer?.cancel();
    _message = text;
    _kind = kind;
    switch (kind) {
      case AppFeedbackKind.error:
        AppHaptics.error();
      case AppFeedbackKind.success:
        AppHaptics.success();
      case AppFeedbackKind.info:
        break;
    }
    notifyListeners();
    final visible = (3000 + text.length * 45).clamp(4000, 8000);
    _timer = Timer(Duration(milliseconds: visible), clear);
  }

  /// Clears the error immediately and cancels any pending timer.
  void clear() {
    _timer?.cancel();
    _timer = null;
    if (_message != null) {
      _message = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// Shows a brief success/info toast anchored to a button-like widget.
///
/// The label temporarily changes to an icon+text badge (e.g. "✓ Copied"),
/// then fades back. With reduced motion the swap is instant.
class InlineTooltipFeedback extends StatefulWidget {
  const InlineTooltipFeedback({
    super.key,
    required this.child,
    required this.message,
    this.duration = const Duration(milliseconds: 1500),
    this.icon = Icons.check_rounded,
    this.controller,
  });

  final Widget child;
  final String message;
  final Duration duration;
  final IconData icon;
  final InlineTooltipFeedbackController? controller;

  @override
  State<InlineTooltipFeedback> createState() => _InlineTooltipFeedbackState();
}

/// Controller for [InlineTooltipFeedback] that can be triggered from callbacks.
class InlineTooltipFeedbackController {
  final List<_InlineTooltipFeedbackState> _listeners = [];

  void _register(_InlineTooltipFeedbackState listener) {
    _listeners.add(listener);
  }

  void _unregister(_InlineTooltipFeedbackState listener) {
    _listeners.remove(listener);
  }

  /// Shows the feedback message for the default duration.
  void show(String message) {
    for (final listener in _listeners) {
      listener._showWithMessage(message);
    }
  }

  void dispose() {
    _listeners.clear();
  }
}

class _InlineTooltipFeedbackState extends State<InlineTooltipFeedback> {
  Timer? _timer;
  bool _showing = false;
  String _currentMessage = '';

  @override
  void initState() {
    super.initState();
    widget.controller?._register(this);
  }

  @override
  void dispose() {
    widget.controller?._unregister(this);
    _timer?.cancel();
    super.dispose();
  }

  void _showWithMessage(String message) {
    if (_showing && _currentMessage == message) return;
    _timer?.cancel();
    _currentMessage = message;
    AppHaptics.success();
    setState(() => _showing = true);
    _timer = Timer(widget.duration, _hide);
  }

  void _hide() {
    _timer?.cancel();
    // The AnimatedSwitcher in build fades the badge back out.
    if (mounted && _showing) setState(() => _showing = false);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _showing
          ? Semantics(
              key: const ValueKey('inline-tooltip-visible'),
              liveRegion: true,
              child: IgnorePointer(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _currentMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : widget.child,
    );
  }
}

/// Rebuilds with the current message of an [InlineErrorController].
///
/// It listens to the controller itself, so a failure appears and fades away on
/// its own. With [kInlineFeedback] off the same failures go to the top banner
/// instead (and [builder] gets null), so the rollback switch covers every
/// screen that shows errors through a controller.
class InlineErrorBuilder extends StatefulWidget {
  const InlineErrorBuilder({
    super.key,
    required this.controller,
    required this.builder,
  });

  final InlineErrorController controller;
  final Widget Function(BuildContext context, String? message) builder;

  @override
  State<InlineErrorBuilder> createState() => _InlineErrorBuilderState();
}

class _InlineErrorBuilderState extends State<InlineErrorBuilder> {
  String? _bannered;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(InlineErrorBuilder old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final message = widget.controller.message;
    if (!kInlineFeedback && message != null && message != _bannered) {
      _bannered = message;
      AppFeedback.showMessage(context, message, kind: AppFeedbackKind.error);
    }
    if (message == null) _bannered = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    kInlineFeedback ? widget.controller.message : null,
  );
}

/// An [InlineErrorSlot] driven by an [InlineErrorController].
class InlineErrorOf extends StatelessWidget {
  const InlineErrorOf(this.controller, {super.key, this.height = 42});

  final InlineErrorController controller;
  final double height;

  @override
  Widget build(BuildContext context) => InlineErrorBuilder(
    controller: controller,
    builder: (context, message) =>
        InlineErrorSlot(message: message, height: height),
  );
}

/// A small heading whose text turns into a failure message and back.
///
/// The heading and the message share one fixed-height line, so nothing around
/// it moves; the swap is a cross-fade.
class InlineErrorCaption extends StatelessWidget {
  const InlineErrorCaption({
    super.key,
    required this.title,
    required this.controller,
    required this.titleStyle,
    this.height = 14,
  });

  final String title;
  final InlineErrorController controller;
  final TextStyle titleStyle;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = AppFeedback.errorTone(dark: dark);
    return InlineErrorBuilder(
      controller: controller,
      builder: (context, message) => SizedBox(
        height: height,
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: message == null
              ? Align(
                  key: const ValueKey('caption-title'),
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: titleStyle),
                )
              : Semantics(
                  key: ValueKey('caption-error:$message'),
                  liveRegion: true,
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 12, color: tone),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          context.tr(message),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tone,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Turns a page header title into a message and back.
///
/// The header has a fixed height, so the swap never moves anything, and it is
/// always on screen however far the page is scrolled.
class InlineHeaderMessage extends StatelessWidget {
  const InlineHeaderMessage({
    super.key,
    required this.controller,
    required this.title,
  });

  final InlineErrorController controller;
  final Widget title;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InlineErrorBuilder(
      controller: controller,
      builder: (context, message) {
        final kind = controller.kind;
        final tone = switch (kind) {
          AppFeedbackKind.error => AppFeedback.errorTone(dark: dark),
          AppFeedbackKind.success => AppTheme.successForeground(isDark: dark),
          AppFeedbackKind.info =>
            (dark ? AppTheme.foreground : AppTheme.lightForeground).withValues(
              alpha: .8,
            ),
        };
        final icon = switch (kind) {
          AppFeedbackKind.error => Icons.error_outline_rounded,
          AppFeedbackKind.success => Icons.check_circle_outline_rounded,
          AppFeedbackKind.info => Icons.info_outline_rounded,
        };
        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: message == null
              ? KeyedSubtree(key: const ValueKey('header-title'), child: title)
              : Semantics(
                  key: ValueKey('header-message:$message'),
                  liveRegion: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: tone),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          context.tr(message),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tone,
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
