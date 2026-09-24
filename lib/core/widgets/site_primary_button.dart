import 'package:flutter/material.dart';

/// Shared primary action with the website's subtle hover and press response.
class SitePrimaryButton extends StatefulWidget {
  const SitePrimaryButton({
    super.key,
    required this.child,
    required this.onPressed,
  });

  final Widget child;
  final VoidCallback? onPressed;

  @override
  State<SitePrimaryButton> createState() => _SitePrimaryButtonState();
}

class _SitePrimaryButtonState extends State<SitePrimaryButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_enabled) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFFCFCFC) : const Color(0xFF09090B);
    final background = dark ? const Color(0xFF020202) : const Color(0xFFFAFAFA);
    return Semantics(
      button: true,
      enabled: _enabled,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? .975 : 1,
            duration: const Duration(milliseconds: 120),
            curve: const Cubic(.2, .8, .2, 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: const Cubic(.2, .8, .2, 1),
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: foreground.withValues(alpha: _enabled ? 1 : .55),
                borderRadius: BorderRadius.circular(999),
                boxShadow: _hovered && _enabled
                    ? [
                        BoxShadow(
                          color: foreground.withValues(alpha: .18),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: background,
                  fontWeight: FontWeight.w700,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
