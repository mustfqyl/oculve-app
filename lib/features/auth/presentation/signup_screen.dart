import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/account/private_text_export.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/core/widgets/oculve_wordmark.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/auth/presentation/login_screen.dart';
import 'package:oculve/features/auth/presentation/widgets/oculve_veil_artwork.dart';
import 'package:url_launcher/url_launcher.dart';

typedef AccessCodeSaver =
    Future<bool> Function(BuildContext context, String code);

final accessCodeSaverProvider = Provider<AccessCodeSaver>(
  (ref) =>
      (context, code) => exportPrivateText(
        context,
        fileName: 'oculve-access-code.txt',
        contents: accessCodeFileContents(code),
      ),
);

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _welcomeAnimation;
  int _step = 0;
  String? _code;
  bool _loading = false, _saving = false, _creating = false;
  bool _codeExported = false;
  bool _copied = false, _registered = false;

  @override
  void initState() {
    super.initState();
    _welcomeAnimation = AnimationController(
      vsync: this,
      value: .5,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _welcomeAnimation.stop();
    } else if (!_welcomeAnimation.isAnimating) {
      _welcomeAnimation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _welcomeAnimation.dispose();
    super.dispose();
  }

  Future<bool> _requestCode() async {
    if (_loading) return false;
    setState(() {
      _loading = true;
    });
    try {
      final code = await ref
          .read(sessionProvider.notifier)
          .generateRegistrationCode();
      if (!mounted) return false;
      setState(() => _code = code);
      return true;
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(
          context,
          error,
          fallback: 'Could not create your sign-in key. Please try again.',
          placement: AppFeedbackPlacement.auth,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _next() async {
    if (_step == 0) {
      if (!_pages.hasClients) return;
      await _pages.animateToPage(
        1,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_step == 1) {
      if (_code == null) {
        await _requestCode();
        return;
      }
      if (!_codeExported && !await _saveCode()) return;
      if (!mounted || !_pages.hasClients) return;
      _pages.jumpToPage(2);
    } else {
      await _createAccount();
    }
  }

  Future<void> _back() async {
    if (_step == 0 || _creating) return;
    final previousStep = _step - 1;
    await _pages.animateToPage(
      previousStep,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _copyCode() async {
    final code = _code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _copied = false);
  }

  Future<bool> _saveCode() async {
    final code = _code;
    if (code == null) return false;
    if (_codeExported) return true;
    setState(() {
      _saving = true;
    });
    try {
      final saved = await ref.read(accessCodeSaverProvider)(context, code);
      if (!mounted) return false;
      if (!saved) {
        AppFeedback.showError(
          context,
          'Choose a place to save your code before continuing.',
          placement: AppFeedbackPlacement.auth,
        );
        return false;
      }
      setState(() => _codeExported = true);
      return true;
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(
          context,
          error,
          fallback:
              'Could not save your code. Choose a location and try again.',
          placement: AppFeedbackPlacement.auth,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createAccount() async {
    final code = _code;
    if (code == null || !_codeExported || _creating) return;
    setState(() {
      _creating = true;
    });
    try {
      await ref.read(sessionProvider.notifier).register(code);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } on RegistrationCreatedButNotReady {
      if (mounted) {
        setState(() => _registered = true);
        AppFeedback.showError(
          context,
          'Your account was created, but server setup is still finishing. Sign in again shortly.',
          placement: AppFeedbackPlacement.auth,
        );
      }
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(
          context,
          error,
          placement: AppFeedbackPlacement.auth,
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _openTerms() => launchUrl(
    Uri.parse('https://www.oculve.com/terms'),
    mode: LaunchMode.externalApplication,
  );

  void _onPageChanged(int page) {
    if (page > 1 && !_codeExported) {
      if (_step != 1) setState(() => _step = 1);
      if (_code == null && !_loading) unawaited(_requestCode());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pages.hasClients || (_pages.page ?? 1) <= 1) return;
        unawaited(
          _pages.animateToPage(
            1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          ),
        );
      });
      return;
    }
    if (page != _step) setState(() => _step = page);
    if (page == 1 && _code == null && !_loading) {
      unawaited(_requestCode());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppTheme.foreground : AppTheme.lightForeground;
    final muted = dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.height < 620;
    final veryCompact = screen.height < 440;
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 22,
              compact ? 4 : 12,
              compact ? 14 : 22,
              compact ? 8 : 16,
            ),
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_step > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 48,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: _creating || _saving ? null : _back,
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                color: fg,
                                size: 19,
                                semanticLabel: MaterialLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                              ),
                            ),
                          ),
                        ),
                      OculveWordmark(color: fg, alignment: Alignment.center),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Step ${_step + 1} of 3',
                  child: Row(
                    children: List.generate(
                      3,
                      (index) => Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                          height: 3,
                          decoration: BoxDecoration(
                            color: index <= _step
                                ? fg.withValues(alpha: .9)
                                : fg.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: _SignupPagePhysics(
                      isCodeSaved: () => _codeExported,
                    ),
                    onPageChanged: _onPageChanged,
                    children: [
                      _scroll(
                        context,
                        _welcomePage(fg, muted, compact, dark, veryCompact),
                      ),
                      _scroll(
                        context,
                        _accessCodePage(fg, muted, compact, dark),
                      ),
                      _scroll(context, _finishPage(fg, muted, compact, dark)),
                    ],
                  ),
                ),
                _footer(context, fg, muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomePage(
    Color fg,
    Color muted,
    bool compact,
    bool dark,
    bool veryCompact,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!veryCompact)
        SizedBox(
          height: compact ? 176 : 218,
          child: OculveVeilArtwork(progress: _welcomeAnimation, dark: dark),
        ),
      SizedBox(
        height: veryCompact
            ? 0
            : compact
            ? 2
            : 10,
      ),
      Text(
        'SEE THE UNSEEN',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: muted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        'Your private connection starts here.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontSize: veryCompact
              ? 20
              : compact
              ? 23
              : 28,
          height: 1.12,
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 9),
      Text(
        'Set up your access key, save it somewhere safe, then choose a location for your first private connection.',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 12.5, height: 1.55),
      ),
      SizedBox(
        height: veryCompact
            ? 8
            : compact
            ? 30
            : 46,
      ),
    ],
  );

  Widget _accessCodePage(
    Color fg,
    Color muted,
    bool compact,
    bool dark,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(height: compact ? 18 : 30),
      Text(
        'Your sign-in key',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontSize: compact ? 23 : 27,
          fontWeight: FontWeight.w700,
          letterSpacing: -.65,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'This is your access code. Tap it to copy; continuing saves it to your device.',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 12, height: 1.45),
      ),
      SizedBox(height: compact ? 24 : 34),
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _code == null ? null : _copyCode,
          child: MouseRegion(
            cursor: _code == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: AnimatedScale(
              scale: _copied ? .985 : 1,
              duration: const Duration(milliseconds: 180),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: compact ? 68 : 76,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _copied
                      ? AppTheme.successColor.withValues(alpha: .09)
                      : fg.withValues(alpha: .045),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _copied
                        ? AppTheme.successForeground(isDark: dark)
                        : fg.withValues(alpha: .2),
                    width: _copied ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _code == null
                        ? _loading
                              ? _AccessCodeScramble(
                                  key: ValueKey('signup-code-scramble'),
                                  color: muted,
                                )
                              : Text(
                                  'Try again to create your code.',
                                  key: const ValueKey('signup-code-retry'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: muted, fontSize: 12),
                                )
                        : FittedBox(
                            key: const ValueKey('signup-code-value'),
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _copied ? 'Copied' : _code!,
                              style: TextStyle(
                                color: fg,
                                fontFamily: 'monospace',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      SizedBox(height: compact ? 18 : 22),
      _notice(
        fg,
        muted,
        Icons.info_outline_rounded,
        'Oculve can’t recover a lost code.',
      ),
      SizedBox(height: compact ? 14 : 24),
    ],
  );

  Widget _finishPage(Color fg, Color muted, bool compact, bool dark) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(height: compact ? 18 : 30),
      Text(
        'Ready to create your account?',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontSize: compact ? 22 : 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -.65,
        ),
      ),
      const SizedBox(height: 9),
      Text(
        'Your access code is saved. Keep the file private; you’ll need it each time you sign in.',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 12, height: 1.5),
      ),
      SizedBox(height: compact ? 22 : 30),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: AppTheme.successColor.withValues(alpha: .24),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: AppTheme.successForeground(isDark: dark),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Access code saved to this device',
                    style: TextStyle(
                      color: fg,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'oculve-access-code.txt',
                    style: TextStyle(color: muted, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: compact ? 17 : 22),
      Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'By continuing, you agree to the ',
              style: TextStyle(color: muted, fontSize: 10.5),
            ),
            InkWell(
              onTap: _openTerms,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Terms of Service',
                  style: TextStyle(
                    color: fg,
                    fontSize: 10.5,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            Text('.', style: TextStyle(color: muted, fontSize: 10.5)),
          ],
        ),
      ),
      if (_registered)
        Center(
          child: TextButton(
            onPressed: () =>
                Navigator.push(context, appRoute(const LoginScreen())),
            child: const Text('Sign in'),
          ),
        ),
      SizedBox(height: compact ? 8 : 16),
    ],
  );

  Widget _footer(BuildContext context, Color fg, Color muted) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: ValueKey('signup-step-$_step-action'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              onPressed: switch (_step) {
                0 => _loading || _saving || _creating ? null : _next,
                1 => _loading || _saving || _creating ? null : _next,
                _ => _codeExported && !_creating && !_registered ? _next : null,
              },
              icon: _saving || _creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _step == 2
                          ? Icons.lock_open_rounded
                          : Icons.arrow_forward_rounded,
                      size: 17,
                    ),
              label: CompactLabel(switch (_step) {
                0 => 'Continue setup',
                1 =>
                  _loading
                      ? 'Continue'
                      : _code == null
                      ? 'Try again'
                      : _saving
                      ? 'Saving code…'
                      : 'Continue',
                _ => 'Create account',
              }),
            ),
          ),
          if (_step == 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(color: muted, fontSize: 10.5),
                  ),
                  TextButton(
                    key: const ValueKey('welcome-sign-in'),
                    onPressed: () =>
                        Navigator.push(context, appRoute(const LoginScreen())),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      foregroundColor: fg,
                      textStyle: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                      // The default hover fill is painted as a circle around
                      // the whole 48px target, so it overlaps the action button
                      // above this row. The pointer cursor carries the
                      // affordance instead; focus and press stay visible.
                    ).copyWith(
                      mouseCursor: const WidgetStatePropertyAll(
                        SystemMouseCursors.click,
                      ),
                      overlayColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.focused)) {
                          return fg.withValues(alpha: .09);
                        }
                        if (states.contains(WidgetState.hovered)) {
                          return Colors.transparent;
                        }
                        return fg.withValues(alpha: .07);
                      }),
                    ),
                    child: const Text('Sign in!'),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  Widget _scroll(BuildContext context, Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - 20).clamp(0.0, double.infinity),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: child,
          ),
        ),
      ),
    ),
  );

  Widget _notice(Color fg, Color muted, IconData icon, String label) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: fg.withValues(alpha: .09)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: muted),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: muted, fontSize: 11, height: 1.35),
              ),
            ),
          ],
        ),
      );
}

class _AccessCodeScramble extends StatefulWidget {
  const _AccessCodeScramble({super.key, required this.color});

  final Color color;

  @override
  State<_AccessCodeScramble> createState() => _AccessCodeScrambleState();
}

class _AccessCodeScrambleState extends State<_AccessCodeScramble> {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _tick = Duration(milliseconds: 55);

  final _random = math.Random();
  late String _value;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _value = _nextValue();
    _timer = Timer.periodic(_tick, (_) {
      if (mounted) setState(() => _value = _nextValue());
    });
  }

  String _nextValue() {
    final groups = List.generate(
      3,
      (_) => List.generate(
        4,
        (_) => _alphabet[_random.nextInt(_alphabet.length)],
      ).join(),
    );
    return groups.join('-');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (Localizations.localeOf(context).languageCode) {
      'tr' => 'Erişim kodun oluşturuluyor',
      'es' => 'Generando tu código de acceso',
      _ => 'Generating your access code',
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Text(
          _value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ).copyWith(color: widget.color),
        ),
      ),
    );
  }
}

class _SignupPagePhysics extends PageScrollPhysics {
  const _SignupPagePhysics({required this.isCodeSaved, super.parent});

  final bool Function() isCodeSaved;

  double _maxOffset(ScrollMetrics position) =>
      (isCodeSaved() ? 2 : 1) * position.viewportDimension;

  @override
  _SignupPagePhysics applyTo(ScrollPhysics? ancestor) => _SignupPagePhysics(
    isCodeSaved: isCodeSaved,
    parent: buildParent(ancestor),
  );

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final maxOffset = _maxOffset(position);
    if (value > maxOffset && position.pixels <= maxOffset) {
      return value - maxOffset;
    }
    if (position.pixels > maxOffset && value > position.pixels) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final maxOffset = _maxOffset(position);
    if (position.pixels > maxOffset) {
      if (velocity < 0) {
        return super.createBallisticSimulation(position, velocity);
      }
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        maxOffset,
        velocity,
        tolerance: toleranceFor(position),
      );
    }
    if (position.pixels >= maxOffset && velocity > 0) return null;
    return super.createBallisticSimulation(position, velocity);
  }
}
