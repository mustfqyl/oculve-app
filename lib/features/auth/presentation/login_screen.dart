import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:oculve/core/haptics/app_haptics.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/core/widgets/inline_feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/animated_entry.dart';
import '../data/auth_repository.dart';
import 'signup_screen.dart';
import 'widgets/tunnel_active_notice.dart';
import 'package:oculve/core/auth/client_passkey.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  late final AnimationController _verifyController;
  late final AnimationController _errorController;
  String? _challenge;
  String? _error;
  String? _lastAutoSubmitted;
  bool _busy = false;
  bool _hasPasskey = false;
  bool _hasTotp = true;
  bool _passkeyBusy = false;
  int _passkeyAttempt = 0;
  Map<String, dynamic>? _passkeyOptions;
  ClientPasskey? _activePasskey;

  @override
  void initState() {
    super.initState();
    _verifyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _passkeyAttempt++;
    unawaited(_activePasskey?.cancel());
    _code.dispose();
    _codeFocus.dispose();
    _verifyController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  bool get _isAccessCode => _challenge == null;

  bool _isReady(String value) {
    final compact = value.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    return _isAccessCode
        ? RegExp(r'^[A-Z0-9]{12}$').hasMatch(compact)
        : RegExp(r'^(?:\d{6}|[A-Z0-9]{8})$').hasMatch(compact);
  }

  String _formatInput(String value) {
    if (!_isAccessCode) {
      final normalized = value.toUpperCase();
      return normalized.substring(0, math.min(normalized.length, 32));
    }
    final compact = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final limited = compact.substring(0, math.min(compact.length, 12));
    return RegExp(
      r'.{1,4}',
    ).allMatches(limited).map((match) => match.group(0)!).join('-');
  }

  void _onCodeChanged(String value) {
    final formatted = _formatInput(value);
    if (formatted != _code.text) {
      _code.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    if (_error != null) setState(() => _error = null);
    if (!_isReady(formatted)) {
      _lastAutoSubmitted = null;
      return;
    }
    if (!_busy && _lastAutoSubmitted != formatted) {
      _lastAutoSubmitted = formatted;
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_busy || _passkeyBusy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _verifyController.repeat();
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(_code.text, challenge: _challenge);
      if (mounted && Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on SecondFactorRequired catch (e) {
      if (!mounted) return;
      final available =
          e.passkey &&
          e.passkeyOptions != null &&
          e.nativePasskeySupported &&
          await ref.read(clientPasskeyProvider).isAvailable();
      if (mounted) {
        setState(() {
          _challenge = e.challenge;
          _hasPasskey = available;
          _passkeyOptions = available ? e.passkeyOptions : null;
          _hasTotp = e.totp;
          _code.clear();
          _lastAutoSubmitted = null;
        });
      }
    } catch (e) {
      if (mounted) {
        {
          AppHaptics.error();
          setState(() => _error = AppFeedback.errorMessage(e));
        }
        _errorController.forward(from: 0);
        if (!kInlineFeedback) {
          AppFeedback.showError(
            context,
            e,
            placement: AppFeedbackPlacement.auth,
          );
        }
      }
    } finally {
      if (mounted) {
        _verifyController.stop();
        _verifyController.reset();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submitPasskey() async {
    final challenge = _challenge;
    final options = _passkeyOptions;
    if (challenge == null || options == null || _busy || _passkeyBusy) return;
    final attempt = ++_passkeyAttempt;
    setState(() {
      _passkeyBusy = true;
      _error = null;
    });
    try {
      _activePasskey = ref.read(clientPasskeyProvider);
      final response = await _activePasskey!.authenticate(options);
      if (response == null || !mounted || attempt != _passkeyAttempt) return;
      setState(() => _busy = true);
      await ref
          .read(sessionProvider.notifier)
          .loginWithPasskey(challenge, response);
      if (mounted && Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted && attempt == _passkeyAttempt) {
        {
          AppHaptics.error();
          setState(() => _error = AppFeedback.errorMessage(e));
        }
        if (!kInlineFeedback) {
          AppFeedback.showError(
            context,
            e,
            placement: AppFeedbackPlacement.auth,
          );
        }
      }
    } finally {
      if (mounted && attempt == _passkeyAttempt) {
        setState(() {
          _passkeyBusy = false;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 395),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedEntry(
                  index: 0,
                  child: Text(
                    _isAccessCode ? 'Welcome Back' : 'Verify your account',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 27,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedEntry(
                  index: 1,
                  child: Text(
                    _isAccessCode
                        ? 'Enter your access code to access your secure network infrastructure.'
                        : _passkeyBusy
                        ? 'Complete verification using your device.'
                        : _hasPasskey
                        ? 'Use your passkey to continue securely.'
                        : _hasTotp
                        ? 'Enter your authenticator or recovery code to continue securely.'
                        : 'This device cannot use your passkey. Set up an authenticator code in your web account to sign in here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF94A3B8)
                          : AppTheme.lightForegroundMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                if (!_isAccessCode && _hasPasskey) ...[
                  FilledButton.icon(
                    onPressed: _busy || _passkeyBusy ? null : _submitPasskey,
                    icon: const Icon(Icons.key_rounded),
                    label: Text(
                      _passkeyBusy
                          ? 'Verifying passkey…'
                          : 'Sign in with passkey',
                    ),
                  ),
                  if (_passkeyBusy)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _passkeyAttempt++;
                              unawaited(_activePasskey?.cancel());
                              _passkeyBusy = false;
                            }),
                      child: const Text('Cancel'),
                    ),
                  if (_isAccessCode || _hasTotp)
                    const SizedBox(height: 20)
                  else
                    InlineErrorSlot(message: kInlineFeedback ? _error : null),
                ],
                if (_isAccessCode || _hasTotp) ...[
                  if (!_isAccessCode)
                    AnimatedEntry(
                      index: 2,
                      child: CompactLabel(
                        'VERIFICATION CODE',
                        textAlign: TextAlign.start,
                        alignment: Alignment.centerLeft,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF64748B)
                              : AppTheme.lightForegroundMuted,
                          fontSize: 13,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .65,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  AnimatedEntry(
                    index: 3,
                    child: _AccessCodeInput(
                      controller: _code,
                      focusNode: _codeFocus,
                      isAccessCode: _isAccessCode,
                      busy: _busy || _passkeyBusy,
                      error: _error != null,
                      verifyAnimation: _verifyController,
                      errorAnimation: _errorController,
                      onChanged: _onCodeChanged,
                    ),
                  ),
                  // Reserved line under the field; the failure fades in here.
                  InlineErrorSlot(message: kInlineFeedback ? _error : null),
                ],
                if (!_isAccessCode) ...[
                  const SizedBox(height: 12),
                  Align(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _challenge = null;
                              _passkeyAttempt++;
                              unawaited(_activePasskey?.cancel());
                              _passkeyBusy = false;
                              _hasPasskey = false;
                              _passkeyOptions = null;
                              _hasTotp = true;
                              _code.clear();
                              _lastAutoSubmitted = null;
                            }),
                      child: const CompactLabel('Back to sign in'),
                    ),
                  ),
                ],
                if (_isAccessCode) ...[
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.push(context, appRoute(const SignUpScreen()));
                      }
                    },
                    child: const CompactLabel('New to Oculve? Create account!'),
                  ),
                ],
                const SizedBox(height: 8),
                const TunnelActiveNotice(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AccessCodeInput extends StatelessWidget {
  const _AccessCodeInput({
    required this.controller,
    required this.focusNode,
    required this.isAccessCode,
    required this.busy,
    required this.error,
    required this.verifyAnimation,
    required this.errorAnimation,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isAccessCode;
  final bool busy;
  final bool error;
  final Animation<double> verifyAnimation;
  final Animation<double> errorAnimation;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? AppTheme.foreground : AppTheme.lightForeground;
    final muted = dark
        ? const Color(0xFF94A3B8)
        : AppTheme.lightForegroundMuted;
    final border = dark
        ? Colors.white.withValues(alpha: .13)
        : Colors.black.withValues(alpha: .14);
    return AnimatedBuilder(
      animation: Listenable.merge([
        verifyAnimation,
        errorAnimation,
        focusNode,
        controller,
      ]),
      builder: (context, _) {
        final shake = errorAnimation.isAnimating
            ? math.sin(errorAnimation.value * math.pi * 5) *
                  (1 - errorAnimation.value) *
                  10
            : 0.0;
        final focused = focusNode.hasFocus;
        final showMask = isAccessCode && controller.text.isEmpty && !busy;
        return AnimatedSlide(
          // Match the website's subtle one-pixel lift when the access-code
          // field receives focus; the glow and fill animate with it below.
          offset: focused && !error ? const Offset(0, -1 / 52) : Offset.zero,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Transform.translate(
            offset: Offset(shake, 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: const Cubic(.2, .8, .2, 1),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: dark
                    ? focused || busy
                          ? AppTheme.backgroundColor
                          : AppTheme.backgroundSecondary
                    : focused || busy
                    ? AppTheme.lightBackground
                    : AppTheme.lightBackgroundSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: error
                      ? AppTheme.errorColor
                      : busy
                      ? foreground.withValues(alpha: .24)
                      : focused
                      ? (dark
                            ? AppTheme.foregroundSubtle
                            : AppTheme.lightForegroundSubtle)
                      : border,
                  width: 1,
                ),
                boxShadow: focused && !error
                    ? [
                        BoxShadow(
                          color: foreground.withValues(alpha: .09),
                          blurRadius: 16,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : busy
                    ? [
                        BoxShadow(
                          color: foreground.withValues(alpha: .08),
                          blurRadius: 24,
                        ),
                      ]
                    : null,
              ),
              child: SizedBox(
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: isAccessCode
                          ? null
                          : const [AutofillHints.oneTimeCode],
                      textCapitalization: TextCapitalization.characters,
                      keyboardType: TextInputType.visiblePassword,
                      textAlign: TextAlign.center,
                      cursorColor: Colors.transparent,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          isAccessCode ? 14 : 32,
                        ),
                      ],
                      style: TextStyle(
                        color: foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: context.tr(
                          isAccessCode ? 'ACCESS CODE' : 'VERIFICATION CODE',
                        ),
                        hintStyle: TextStyle(
                          color: Colors.transparent,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                      onChanged: onChanged,
                    ),
                    if (showMask)
                      ExcludeSemantics(
                        child: IgnorePointer(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final part in const [
                                'XXXX',
                                '-',
                                'XXXX',
                                '-',
                                'XXXX',
                              ])
                                Text(
                                  part,
                                  style: TextStyle(
                                    color: muted.withValues(
                                      alpha: part == '-' ? .28 : .4,
                                    ),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (busy)
                      Positioned(
                        bottom: 0,
                        left: -120 + verifyAnimation.value * 520,
                        child: Container(
                          width: 120,
                          height: 2,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                foreground.withValues(alpha: .72),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
