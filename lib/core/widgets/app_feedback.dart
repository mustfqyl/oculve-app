import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/models/user_facing_failure.dart';
import 'package:oculve/core/theme/app_theme.dart';

enum AppFeedbackKind { error, info, success }

/// Retained for callers; all screens use the same accessible header anchor.
enum AppFeedbackPlacement { home, auth, pageTop, pageBottom }

/// Removes feedback when its screen is covered, popped or replaced.
class AppFeedbackNavigatorObserver extends NavigatorObserver {
  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (AppFeedback._activeRoute != null &&
        AppFeedback._activeRoute != topRoute) {
      AppFeedback.dismiss();
    }
  }
}

/// One transient notice above the page, without affecting its layout.
class AppFeedback {
  AppFeedback._();

  static OverlayEntry? _activeEntry;
  static ModalRoute<dynamic>? _activeRoute;
  static String? _activeMessage;
  static AppFeedbackKind? _activeKind;
  static BuildContext? _activeOwner;
  static int _nextId = 0;

  static String errorMessage(Object error, {String? fallback}) =>
      UserFacingFailure.message(error, fallback: fallback);

  static void dismiss() {
    final entry = _activeEntry;
    _activeEntry = null;
    _activeRoute = null;
    _activeMessage = null;
    _activeKind = null;
    _activeOwner = null;
    if (entry == null) return;
    entry.remove();
    entry.dispose();
  }

  static void showError(
    BuildContext context,
    Object error, {
    String? fallback,
    AppFeedbackPlacement placement = AppFeedbackPlacement.pageBottom,
  }) => showMessage(
    context,
    errorMessage(error, fallback: fallback),
    kind: AppFeedbackKind.error,
    placement: placement,
  );

  static void showMessage(
    BuildContext context,
    String message, {
    AppFeedbackKind kind = AppFeedbackKind.info,
    AppFeedbackPlacement placement = AppFeedbackPlacement.pageBottom,
  }) {
    if (!context.mounted || message.trim().isEmpty) return;
    final route = ModalRoute.of(context);
    // Async results from a covered screen must not surface on another page.
    if (route != null && !route.isCurrent) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final translated = context.tr(message);
    if (_activeOwner?.mounted == true &&
        _activeRoute == route &&
        _activeMessage == translated &&
        _activeKind == kind) {
      return; // Repeated native/API events must not reset the expiry timer.
    }
    dismiss();
    final id = ++_nextId;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FeedbackOverlay(
        key: ValueKey(id),
        id: id,
        message: translated,
        kind: kind,
        owner: context,
        route: route,
        onDismissed: () {
          if (_activeEntry == entry) dismiss();
        },
      ),
    );
    _activeEntry = entry;
    _activeRoute = route;
    _activeMessage = translated;
    _activeKind = kind;
    _activeOwner = context;
    overlay.insert(entry);
  }
}

class _FeedbackOverlay extends StatefulWidget {
  const _FeedbackOverlay({
    super.key,
    required this.id,
    required this.message,
    required this.kind,
    required this.owner,
    required this.route,
    required this.onDismissed,
  });

  final int id;
  final String message;
  final AppFeedbackKind kind;
  final BuildContext owner;
  final ModalRoute<dynamic>? route;
  final VoidCallback onDismissed;

  @override
  State<_FeedbackOverlay> createState() => _FeedbackOverlayState();
}

class _FeedbackOverlayState extends State<_FeedbackOverlay>
    with TickerProviderStateMixin {
  static const _duration = Duration(seconds: 7);
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final AnimationController _remaining = AnimationController(
    vsync: this,
    duration: _duration,
  );
  Timer? _expiry;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _remaining.addListener(_checkOwner);
    _entry.forward();
    _remaining.forward();
    _expiry = Timer(_duration, _dismiss);
  }

  void _checkOwner() {
    if (!widget.owner.mounted || widget.route?.isCurrent == false) _dismiss();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _entry.dispose();
    _remaining.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _expiry?.cancel();
    _remaining.stop();
    try {
      await _entry.reverse().orCancel;
      if (mounted) widget.onDismissed();
    } on TickerCanceled {
      // A replacement notice or navigation already removed this entry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? AppTheme.foreground : AppTheme.lightForeground;
    final accent = switch (widget.kind) {
      AppFeedbackKind.error =>
        dark ? const Color(0xFFFF7777) : const Color(0xFFB42318),
      AppFeedbackKind.success => AppTheme.successColor,
      AppFeedbackKind.info => foreground,
    };
    final background = switch (widget.kind) {
      AppFeedbackKind.error =>
        dark ? const Color(0xFF271619) : const Color(0xFFFFF3F2),
      AppFeedbackKind.success =>
        dark ? const Color(0xFF10231E) : const Color(0xFFF0FDF7),
      AppFeedbackKind.info =>
        dark ? const Color(0xFF171A1E) : const Color(0xFFFFFFFF),
    };
    final icon = switch (widget.kind) {
      AppFeedbackKind.error => Icons.error_outline_rounded,
      AppFeedbackKind.success => Icons.check_circle_outline_rounded,
      AppFeedbackKind.info => Icons.info_outline_rounded,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        minimum: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 76,
          16,
          16,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: math.min(180, constraints.maxHeight),
              ),
              child: FadeTransition(
                opacity: _entry,
                child: SlideTransition(
                  position: _entry.drive(
                    Tween<Offset>(
                      begin: const Offset(0, -.12),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutCubic)),
                  ),
                  child: Dismissible(
                    key: ValueKey('feedback-${widget.id}'),
                    direction: DismissDirection.horizontal,
                    onDismissed: (_) => widget.onDismissed(),
                    child: Material(
                      key: const ValueKey('feedback-card'),
                      color: background,
                      elevation: 5,
                      shadowColor: Colors.black.withValues(alpha: .2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: accent.withValues(alpha: .24)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    14,
                                    9,
                                    12,
                                  ),
                                  child: Icon(icon, size: 18, color: accent),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      0,
                                      12,
                                      12,
                                      12,
                                    ),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        widget.message,
                                        style: TextStyle(
                                          color: foreground,
                                          fontSize: 13,
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            key: const ValueKey('feedback-progress'),
                            height: 2,
                            child: AnimatedBuilder(
                              animation: _remaining,
                              builder: (context, _) => LinearProgressIndicator(
                                value: 1 - _remaining.value,
                                backgroundColor: accent.withValues(alpha: .10),
                                valueColor: AlwaysStoppedAnimation(
                                  accent.withValues(alpha: .65),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A stable full-page error state for failures that prevent a screen from
/// loading. It keeps the message and recovery actions within a bounded area.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppTheme.foreground : AppTheme.lightForeground;
    final muted = dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: .1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.errorColor.withValues(alpha: .24),
                  ),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(title),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(message),
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12.5, height: 1.45),
              ),
              if (primaryLabel != null && onPrimary != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onPrimary,
                    child: Text(context.tr(primaryLabel!)),
                  ),
                ),
              ],
              if (secondaryLabel != null && onSecondary != null)
                TextButton(
                  onPressed: onSecondary,
                  child: Text(context.tr(secondaryLabel!)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
