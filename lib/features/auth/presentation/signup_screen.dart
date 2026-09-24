import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/account/private_text_export.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
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
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FrostedCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Account Setup',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: fg,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Save your unique access code to initialize your Oculve account.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'YOUR UNIQUE ACCESS CODE',
                            style: TextStyle(
                              color: subtle,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .65,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _code == null || _codeError != null
                                  ? null
                                  : _copyCode,
                              child: AnimatedScale(
                                scale: _copied ? .98 : 1,
                                duration: const Duration(milliseconds: 240),
                                curve: const Cubic(.16, 1, .3, 1),
                                child: CustomPaint(
                                  painter: _DashedOutlinePainter(
                                    color: _codeError != null
                                        ? AppTheme.errorColor
                                        : _copied
                                        ? AppTheme.successColor
                                        : (dark
                                                  ? AppTheme.accent
                                                  : AppTheme.lightAccent)
                                              .withValues(alpha: .6),
                                    radius: 12,
                                    dashed: _codeError == null && !_copied,
                                  ),
                                  child: Container(
                                    height: 76,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _codeError != null
                                          ? AppTheme.errorColor.withValues(
                                              alpha: .08,
                                            )
                                          : _copied
                                          ? AppTheme.successColor.withValues(
                                              alpha: .06,
                                            )
                                          : fg.withValues(alpha: .035),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : _codeError != null
                                        ? Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.error_outline_rounded,
                                                  size: 18,
                                                  color: AppTheme.errorColor,
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    _codeError!,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color:
                                                          AppTheme.errorColor,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Text(
                                            _copied
                                                ? 'COPIED'
                                                : _code ?? 'XXXX-XXXX-XXXX',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: _copied
                                                  ? AppTheme.successColor
                                                  : fg,
                                              fontFamily: 'monospace',
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.7,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (_code == null && !_loading)
                            TextButton(
                              onPressed: _loadCode,
                              child: const Text('Try again'),
                            ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withValues(
                                alpha: .05,
                              ),
                              border: Border.all(
                                color: AppTheme.warningColor.withValues(
                                  alpha: .2,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text.rich(
                                      TextSpan(
                                        style: TextStyle(
                                          color: subtle,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                        children: const [
                                          TextSpan(
                                            text:
                                                'I have securely saved my access code. I understand that if I lose it, ',
                                          ),
                                          TextSpan(
                                            text:
                                                'I will permanently lose access',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          TextSpan(text: ' to my account.'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed:
                                  _saved &&
                                      !_loading &&
                                      !_creating &&
                                      !_registered
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to sign in'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          'By proceeding, you agree to our ',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        InkWell(
                          onTap: _openTerms,
                          child: Text(
                            'Terms',
                            style: TextStyle(
                              color: fg,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        Text('.', style: TextStyle(color: muted, fontSize: 12)),
                      ],
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

class _DashedOutlinePainter extends CustomPainter {
  const _DashedOutlinePainter({
    required this.color,
    required this.radius,
    required this.dashed,
  });

  final Color color;
  final double radius;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = dashed ? 1 : 2;
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 12) {
        final end = (distance + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedOutlinePainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      dashed != oldDelegate.dashed;
}
