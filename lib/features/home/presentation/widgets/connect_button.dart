import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';

/// The veil itself is the connection control, including its surrounding space.
class ConnectButton extends ConsumerStatefulWidget {
  const ConnectButton({super.key});
  @override
  ConsumerState<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends ConsumerState<ConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  bool _hover = false;
  bool _focus = false;
  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _activate() {
    final state = ref.read(vpnProvider);
    if (state == VpnState.disconnecting) return;
    final notifier = ref.read(vpnProvider.notifier);
    // Cancellation must bypass toggle's guard while connect is awaiting work.
    final operation = state == VpnState.connecting
        ? notifier.disconnect()
        : notifier.toggle();
    operation.catchError((Object _) {
      // The notifier reports native failures through the existing error UI.
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vpnProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final enabled = state != VpnState.disconnecting;
    final connecting = state == VpnState.connecting;
    final connected = state == VpnState.connected;
    final fg = dark ? AppTheme.foreground : AppTheme.lightForeground;
    final title = switch (state) {
      VpnState.connected => context.tr('Connected'),
      VpnState.connecting => context.tr('CONNECTING'),
      VpnState.disconnecting => context.tr('STOPPING'),
      VpnState.error => context.tr('TRY AGAIN'),
      VpnState.disconnected => context.tr('CONNECT'),
    };
    final hint = connected
        ? context.tr('Connected. Tap to disconnect.')
        : connecting
        ? context.tr('Cancel')
        : state == VpnState.error
        ? context.tr('Tap to retry.')
        : state == VpnState.disconnecting
        ? context.tr('STOPPING…')
        : context.tr('Tap to connect');
    final opening = connected
        ? 1.0
        : connecting
        ? .52
        : 0.0;
    final height = math.min(300.0, MediaQuery.sizeOf(context).height * .51);

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title. $hint',
      onTap: enabled ? _activate : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          key: const ValueKey('vpn-connect-control'),
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _activate : null,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: SizedBox(
            width: 280,
            height: height,
            child: AnimatedContainer(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _focus
                      ? fg.withValues(alpha: .45)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: opening),
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 950),
                      curve: Curves.easeInOutCubic,
                      builder: (context, aperture, _) => AnimatedScale(
                        scale: _pressed
                            ? .97
                            : _hover
                            ? 1.025
                            : 1,
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _motion,
                            builder: (context, _) => CustomPaint(
                              size: Size.infinite,
                              painter: _VeilPainter(
                                opening: aperture,
                                phase: _motion.value * math.pi * 2,
                                dark: dark,
                                connecting: connecting,
                                hover: _hover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CompactLabel(
                    title,
                    style: TextStyle(
                      color: state == VpnState.error ? AppTheme.errorColor : fg,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 7),
                  CompactLabel(
                    hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fg.withValues(alpha: .48),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VeilPainter extends CustomPainter {
  const _VeilPainter({
    required this.opening,
    required this.phase,
    required this.dark,
    required this.connecting,
    required this.hover,
  });
  final double opening, phase;
  final bool dark, connecting, hover;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * .50;
    final color = dark ? Colors.white : const Color(0xFF24303E);
    final breath = math.sin(phase);
    final gap = w * (.012 + opening * .16);
    final drift = breath * (connecting ? 5 : 1.8);
    final bounds = Offset.zero & size;
    Path edge(double side, double spread) => Path()
      ..moveTo(cx + w * .085, h * .015)
      ..cubicTo(
        cx + w * .065,
        h * .25,
        cx + side * spread - w * .075 + drift,
        h * .35,
        cx + side * spread,
        cy,
      )
      ..cubicTo(
        cx + side * spread + w * .08,
        h * .65,
        cx - w * .055,
        h * .80,
        cx - w * .07,
        h * .985,
      );
    final aperture = Path()
      ..moveTo(cx + w * .085, h * .015)
      ..cubicTo(
        cx + w * .065,
        h * .25,
        cx - gap - w * .075 + drift,
        h * .35,
        cx - gap,
        cy,
      )
      ..cubicTo(
        cx - gap + w * .08,
        h * .65,
        cx - w * .055,
        h * .80,
        cx - w * .07,
        h * .985,
      )
      ..cubicTo(
        cx - w * .055,
        h * .80,
        cx + gap + w * .08,
        h * .65,
        cx + gap,
        cy,
      )
      ..cubicTo(
        cx + gap - w * .075 + drift,
        h * .35,
        cx + w * .065,
        h * .25,
        cx + w * .085,
        h * .015,
      )
      ..close();
    canvas.drawPath(
      aperture,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(.1, -.15),
          radius: .60,
          colors: [
            color.withValues(
              alpha: dark ? .12 + opening * .42 : .05 + opening * .12,
            ),
            color.withValues(alpha: 0),
          ],
        ).createShader(bounds)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    for (final side in [-1.0, 1.0]) {
      // Broad, feathered folds provide volume; the fine mesh stays subordinate.
      for (var i = 0; i < 4; i++) {
        final spread = gap + w * (.045 + i * .055);
        canvas.drawPath(
          edge(side, spread),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8 + i * 6
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0),
                color.withValues(alpha: .045 - i * .007),
                color.withValues(alpha: .015),
                color.withValues(alpha: 0),
              ],
              stops: const [0, .4, .65, 1],
            ).createShader(bounds)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 + i),
        );
      }
      for (var i = 34; i >= 0; i--) {
        final t = i / 34;
        final opacity = (1 - t) * .034 + .003;
        canvas.drawPath(
          edge(side, gap + w * .30 * t * t),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .45
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0),
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * .45),
                color.withValues(alpha: 0),
              ],
              stops: const [0, .38, .65, 1],
            ).createShader(bounds),
        );
      }
      final edgeShader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: .82),
          color.withValues(alpha: .38),
          color.withValues(alpha: 0),
        ],
        stops: const [0, .43, .68, 1],
      ).createShader(bounds);
      canvas.drawPath(
        edge(side, gap),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hover ? 7 : 5
          ..shader = edgeShader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        edge(side, gap),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .85
          ..shader = edgeShader,
      );
    }
    if (connecting) {
      final y = h * (.2 + ((phase / (math.pi * 2)) % 1) * .6);
      canvas.drawCircle(
        Offset(cx + math.sin(phase) * gap * .35, y),
        2,
        Paint()
          ..color = color.withValues(alpha: .6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(_VeilPainter old) =>
      opening != old.opening ||
      phase != old.phase ||
      dark != old.dark ||
      connecting != old.connecting ||
      hover != old.hover;
}
