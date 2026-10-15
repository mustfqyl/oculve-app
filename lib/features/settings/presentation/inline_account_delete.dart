import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/theme/app_theme.dart';

enum _DeleteStage { idle, typing, waiting, ready, deleting }

/// A single stable footer control; only the final explicit tap submits deletion.
class InlineAccountDelete extends StatefulWidget {
  const InlineAccountDelete({
    super.key,
    required this.onDelete,
    this.enabled = true,
  });
  final Future<void> Function() onDelete;
  final bool enabled;

  @override
  State<InlineAccountDelete> createState() => _InlineAccountDeleteState();
}

class _InlineAccountDeleteState extends State<InlineAccountDelete>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const phrase = 'DELETE MY ACCOUNT';
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _controlFocus = FocusNode();
  late final AnimationController _fill;
  _DeleteStage _stage = _DeleteStage.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fill =
        AnimationController(
          vsync: this,
          duration: const Duration(seconds: 10),
          // This is a destructive-action safety delay, not decorative motion.
          animationBehavior: AnimationBehavior.preserve,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed &&
              _stage == _DeleteStage.waiting) {
            setState(() => _stage = _DeleteStage.ready);
          }
        });
  }

  void _reset() {
    if (_stage == _DeleteStage.deleting) return;
    _fill.reset();
    _text.clear();
    _focus.unfocus();
    setState(() => _stage = _DeleteStage.idle);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _reset();
    }
  }

  @override
  void didUpdateWidget(InlineAccountDelete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _stage != _DeleteStage.deleting) _reset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fill.dispose();
    _text.dispose();
    _focus.dispose();
    _controlFocus.dispose();
    super.dispose();
  }

  void _startWaiting(String value) {
    if (_stage != _DeleteStage.typing || value != phrase) return;
    _focus.unfocus();
    _controlFocus.requestFocus();
    setState(() => _stage = _DeleteStage.waiting);
    _fill.forward(from: 0);
  }

  Future<void> _submit() async {
    if (_stage != _DeleteStage.ready || !widget.enabled) return;
    setState(() => _stage = _DeleteStage.deleting);
    try {
      await widget.onDelete();
    } finally {
      if (mounted) {
        _stage = _DeleteStage.idle;
        _reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const red = AppTheme.dangerColor;
    return Focus(
      focusNode: _controlFocus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _reset();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        height: 40,
        child: _stage == _DeleteStage.idle
            ? TextButton.icon(
                key: const ValueKey('account-delete-start'),
                style: TextButton.styleFrom(
                  foregroundColor: red,
                  minimumSize: const Size.fromHeight(40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.standard,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: widget.enabled
                    ? () {
                        setState(() => _stage = _DeleteStage.typing);
                        _focus.requestFocus();
                      }
                    : null,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(
                  context.tr('Delete account'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : _stage == _DeleteStage.typing
            ? TextField(
                key: const ValueKey('delete-account-confirmation-field'),
                controller: _text,
                focusNode: _focus,
                autocorrect: false,
                enableSuggestions: false,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: red,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                onChanged: _startWaiting,
                onTapOutside: (_) => _reset(),
                decoration: InputDecoration(
                  hintText: phrase,
                  hintStyle: TextStyle(
                    color: red.withValues(alpha: .55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    // The outline should fill the same 40px slot as the idle
                    // and countdown buttons; the smaller padding made the
                    // focused field's painted border look vertically shorter.
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: red.withValues(alpha: .035),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(color: red.withValues(alpha: .3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(color: red.withValues(alpha: .3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(color: red.withValues(alpha: .6)),
                  ),
                ),
              )
            : AnimatedBuilder(
                animation: _fill,
                builder: (context, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: red.withValues(alpha: .055),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _fill.value,
                          heightFactor: 1,
                          child: ColoredBox(color: red.withValues(alpha: .18)),
                        ),
                      ),
                      OutlinedButton(
                        key: const ValueKey('account-delete-confirm'),
                        onPressed:
                            _stage == _DeleteStage.ready && widget.enabled
                            ? _submit
                            : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.standard,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          foregroundColor: red,
                          disabledForegroundColor: red.withValues(alpha: .7),
                          side: BorderSide(color: red.withValues(alpha: .35)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: Text(
                          _stage == _DeleteStage.deleting
                              ? context.tr('Deleting…')
                              : _stage == _DeleteStage.ready
                              ? context.tr('Are you sure?')
                              : '${(10 * (1 - _fill.value)).ceil().clamp(1, 10)} s',
                          style: const TextStyle(
                            fontSize: 13,
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
