import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/account/private_text_export.dart';
import 'package:oculve/core/widgets/animated_entry.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/auth/presentation/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  String? _code;
  String? _codeError;
  String? _error;
  bool _loading = true;
  bool _creating = false;
  bool _saved = false;
  bool _copied = false;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCode);
  }

  Future<void> _loadCode() async {
    setState(() {
      _loading = true;
      _codeError = null;
      _error = null;
    });
    try {
      final code = await ref
          .read(sessionProvider.notifier)
          .generateRegistrationCode();
      if (mounted) setState(() => _code = code);
    } catch (error) {
      if (mounted) setState(() => _codeError = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyCode() async {
    final code = _code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _copied = false);
  }

  Future<void> _downloadCode() async {
    final code = _code;
    if (code == null) return;
    try {
      final saved = await exportPrivateText(
        context,
        fileName: 'oculve-access-code.txt',
        contents: accessCodeFileContents(code),
      );
      if (saved && mounted) setState(() => _saved = true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _createAccount() async {
    final code = _code;
    if (code == null || !_saved || _creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).register(code);
      if (mounted && Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on RegistrationCreatedButNotReady catch (error) {
      if (mounted) {
        setState(() {
          _registered = true;
          _error = error.toString();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _openTerms() async {
    await launchUrl(
      Uri.parse('https://www.oculve.com/terms'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppTheme.foreground : AppTheme.lightForeground;
    final muted = dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    final subtle = dark
        ? AppTheme.foregroundSubtle
        : AppTheme.lightForegroundSubtle;

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedEntry(
                      index: 0,
                      child: Text(
                        'Account Setup',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: fg,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedEntry(
                      index: 1,
                      child: Text(
                        'Save your unique access code to initialize your Oculve account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedEntry(
                      index: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR UNIQUE ACCESS CODE',
                            style: TextStyle(
                              color: subtle,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: dark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _codeError != null
                                    ? AppTheme.errorColor
                                    : _copied
                                    ? AppTheme.successColor
                                    : dark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.09),
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                if (_loading)
                                  const SizedBox(
                                    height: 36,
                                    child: Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                else if (_codeError != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          size: 16,
                                          color: AppTheme.errorColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            _codeError!,
                                            style: const TextStyle(
                                              color: AppTheme.errorColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: _copyCode,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 10,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _copied
                                                ? 'COPIED'
                                                : _code ?? 'XXXX-XXXX-XXXX',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: _copied
                                                  ? AppTheme.successColor
                                                  : fg,
                                              fontFamily: 'monospace',
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.8,
                                            ),
                                          ),
                                          if (!_copied && _code != null) ...[
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.copy_rounded,
                                              size: 15,
                                              color: muted,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    if (_code == null && !_loading)
                      TextButton(
                        onPressed: _loadCode,
                        child: const Text('Try again'),
                      ),
                    const SizedBox(height: 12),
                    AnimatedEntry(
                      index: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: .06),
                          border: Border.all(
                            color: AppTheme.warningColor.withValues(alpha: .18),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _saved,
                              onChanged: _code == null || _registered
                                  ? null
                                  : (value) {
                                      final checked = value ?? false;
                                      setState(() => _saved = checked);
                                      if (checked) _downloadCode();
                                    },
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    color: subtle,
                                    fontSize: 11.5,
                                    height: 1.3,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: context.tr(
                                        'I have securely saved my access code. I understand that if I lose it, ',
                                      ),
                                    ),
                                    TextSpan(
                                      text: context.tr(
                                        'I will permanently lose access',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: context.tr(' to my account.'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedEntry(
                      index: 4,
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed:
                              _saved && !_loading && !_creating && !_registered
                              ? _createAccount
                              : null,
                          child: _creating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('GO TO DASHBOARD'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedEntry(
                      index: 5,
                      child: Column(
                        children: [
                          TextButton(
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                Navigator.push(
                                  context,
                                  appRoute(const LoginScreen()),
                                );
                              }
                            },
                            child: const Text('Back to sign in'),
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              Text(
                                'By proceeding, you agree to our ',
                                style: TextStyle(color: muted, fontSize: 11),
                              ),
                              InkWell(
                                onTap: _openTerms,
                                child: Text(
                                  'Terms',
                                  style: TextStyle(
                                    color: fg,
                                    fontSize: 11,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              Text(
                                '.',
                                style: TextStyle(color: muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
