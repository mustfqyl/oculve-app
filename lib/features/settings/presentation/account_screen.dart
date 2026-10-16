import 'dart:async';
import 'inline_account_delete.dart';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/account/private_text_export.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/core/localization/app_strings.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen>
    with WidgetsBindingObserver {
  bool _showCode = false;
  bool _busy = false;
  bool _accountRefreshBusy = false;
  Timer? _accountRefresh;
  bool _appVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshAccount());
    _accountRefresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_refreshAccount()),
    );
  }

  Future<void> _refreshAccount() async {
    if (_accountRefreshBusy || _busy || !_appVisible || !mounted) return;
    _accountRefreshBusy = true;
    try {
      await ref.read(sessionProvider.notifier).refreshAccount();
    } catch (_) {
      // Preserve the last known account state when a background read fails.
    } finally {
      _accountRefreshBusy = false;
    }
  }

  @override
  void dispose() {
    _accountRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAccount());
    }
  }

  Color get _fg => Theme.of(context).brightness == Brightness.dark
      ? AppTheme.foreground
      : AppTheme.lightForeground;
  Color get _muted => Theme.of(context).brightness == Brightness.dark
      ? AppTheme.foregroundMuted
      : AppTheme.lightForegroundMuted;

  String _date(String? value) {
    final date = DateTime.tryParse(value ?? '');
    if (date == null) return '—';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return switch (Localizations.localeOf(context).languageCode) {
      'en' => '$month/$day/$year',
      'es' => '$day/$month/$year',
      _ => '$day.$month.$year',
    };
  }

  String _decimal(num value) {
    final formatted = value.toStringAsFixed(2);
    return switch (Localizations.localeOf(context).languageCode) {
      'es' || 'tr' => formatted.replaceFirst('.', ','),
      _ => formatted,
    };
  }

  String _lastActive(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toUtc();
    if (date == null) return '—';
    String two(int part) => part.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)} UTC';
  }

  void _message(String message, {BuildContext? source}) {
    if (!mounted) return;
    AppFeedback.showMessage(source ?? context, message);
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(
          context,
          error,
          placement: AppFeedbackPlacement.pageBottom,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String description, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            final cancel = cupertino.CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: CompactLabel(context.tr('Cancel')),
            );
            final confirm = cupertino.CupertinoDialogAction(
              isDestructiveAction: title == 'Permanently delete?',
              onPressed: () => Navigator.pop(dialogContext, true),
              child: CompactLabel(context.tr(action)),
            );
            if (Platform.isIOS) {
              return cupertino.CupertinoPopupSurface(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 19, 22, 15),
                        child: Column(
                          children: [
                            Text(
                              context.tr(title),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              context.tr(description),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 1 / MediaQuery.devicePixelRatioOf(context),
                        color: cupertino.CupertinoColors.separator.resolveFrom(
                          context,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: cupertino.CupertinoButton(
                              onPressed: cancel.onPressed,
                              child: cancel.child,
                            ),
                          ),
                          Container(
                            width: 1 / MediaQuery.devicePixelRatioOf(context),
                            height: 44,
                            color: cupertino.CupertinoColors.separator
                                .resolveFrom(context),
                          ),
                          Expanded(
                            child: cupertino.CupertinoButton(
                              onPressed: confirm.onPressed,
                              child: DefaultTextStyle.merge(
                                style: TextStyle(
                                  color: title == 'Permanently delete?'
                                      ? cupertino.CupertinoColors.systemRed
                                            .resolveFrom(context)
                                      : cupertino.CupertinoColors.activeBlue
                                            .resolveFrom(context),
                                ),
                                child: confirm.child,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }
            return AlertDialog(
              title: Text(context.tr(title)),
              content: Text(context.tr(description)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: CompactLabel(context.tr('Cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: CompactLabel(context.tr(action)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _securityAction(
    String path,
    String message, {
    Map<String, dynamic>? body,
  }) async {
    await _run(() async {
      await ref.read(apiProvider).request(path, body: body ?? {});
      await ref.read(sessionProvider.notifier).refreshAccount();
      _message(message);
    });
  }

  Widget _securityDialog({
    required BuildContext dialogContext,
    required String title,
    required IconData icon,
    required Widget content,
    required List<Widget> actions,
  }) {
    final height = MediaQuery.sizeOf(dialogContext).height;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: height - 24),
        child: FrostedCard(
          padding: EdgeInsets.zero,
          borderRadius: 20,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(icon, color: _muted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: _fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        semanticLabel: context.tr('Close'),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _muted.withValues(alpha: .2)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
              ),
              Divider(height: 1, color: _muted.withValues(alpha: .2)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(children: actions),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _resetDevices() => _run(() async {
    await ref.read(vpnProvider.notifier).disconnect();
    await ref.read(apiProvider).request('/api/user/devices/reset', body: {});
    try {
      await ref.read(sessionProvider.notifier).logout();
    } finally {
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  });

  Future<void> _startTotpSetup() async {
    await _run(() async {
      final setup = await ref
          .read(apiProvider)
          .request('/api/user/security/totp/setup', body: {});
      if (!mounted) return;
      final key = setup['manualEntryKey']?.toString() ?? '';
      final token = setup['setupToken']?.toString() ?? '';
      final qr = setup['qrDataUrl']?.toString() ?? '';
      if (key.isEmpty || token.isEmpty) {
        throw const FormatException('Invalid TOTP setup response.');
      }
      final code = TextEditingController();
      try {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (dialogContext) => _securityDialog(
            dialogContext: dialogContext,
            title: 'Set up authenticator',
            icon: Icons.verified_user_outlined,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scan this code with your authenticator app, then enter the six-digit code it generates.',
                  style: TextStyle(color: _muted, fontSize: 13, height: 1.35),
                ),
                if (qr.startsWith('data:image/png;base64,')) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 176,
                      height: 176,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.memory(
                        base64Decode(qr.split(',').last),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'MANUAL SETUP KEY',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                FrostedCard(
                  padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
                  borderRadius: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          key,
                          style: TextStyle(
                            color: _fg,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: key));
                          _message('Setup key copied.', source: dialogContext);
                        },
                        icon: Icon(
                          Icons.copy_outlined,
                          size: 17,
                          semanticLabel: context.tr('Copy setup key'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: _fg,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('Authenticator code'),
                    hintText: '000000',
                    counterText: '',
                    filled: true,
                    fillColor: _muted.withValues(alpha: .08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: _muted.withValues(alpha: .2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: _muted.withValues(alpha: .2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.tr('Cancel')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, {
                    'setupToken': token,
                    'code': code.text.trim(),
                  }),
                  child: Text(context.tr('Enable 2FA')),
                ),
              ),
            ],
          ),
        );
        if (result == null) return;
        if (!mounted) return;
        if ((result['code'] as String).length < 6) {
          _message(context.tr('Enter the code from your authenticator.'));
          return;
        }
        final enabled = await ref
            .read(apiProvider)
            .request('/api/user/security/totp/enable', body: result);
        await ref.read(sessionProvider.notifier).refreshAccount();
        if (!mounted) return;
        final codes =
            (enabled['recoveryCodes'] as List?)
                ?.map((e) => e.toString())
                .join('\n') ??
            '';
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => _securityDialog(
            dialogContext: dialogContext,
            title: 'Save recovery codes',
            icon: Icons.key_outlined,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'These one-time codes will not be shown again. Keep them somewhere safe.',
                  style: TextStyle(color: _muted, fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 14),
                FrostedCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 12,
                  child: SelectableText(
                    codes,
                    style: TextStyle(
                      color: _fg,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codes));
                    _message('Recovery codes copied.');
                  },
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final saved = await exportPrivateText(
                      dialogContext,
                      fileName: 'oculve-recovery-codes.txt',
                      contents: 'OCULVE RECOVERY CODES\n\n$codes\n',
                    );
                    if (saved && dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Save file'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: Icon(Icons.check, semanticLabel: context.tr('Done')),
              ),
            ],
          ),
        );
      } finally {
        code.dispose();
      }
    });
  }

  Future<void> _deleteAccount() async {
    await _run(() async {
      await ref.read(vpnProvider.notifier).disconnect();
      await ref.read(apiProvider).request('/api/user/me', method: 'DELETE');
      await ref.read(apiProvider).clear();
      ref.read(sessionProvider.notifier).clearLocalSession();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    });
  }

  Future<void> _showDevicesSheet(List<Map<String, dynamic>> devices) async {
    var resetArmed = false;
    var resetBusy = false;
    var resetDone = false;
    Timer? confirmationTimer;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) => FractionallySizedBox(
              heightFactor: .78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FrostedCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${context.tr('Registered devices')} (${devices.length})',
                                style: TextStyle(
                                  color: _fg,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (devices.isNotEmpty)
                              IconButton(
                                onPressed: _busy || resetBusy
                                    ? null
                                    : () async {
                                        if (!resetArmed) {
                                          confirmationTimer?.cancel();
                                          setSheetState(() {
                                            resetArmed = true;
                                            resetDone = false;
                                          });
                                          confirmationTimer = Timer(
                                            const Duration(seconds: 3),
                                            () {
                                              if (sheetContext.mounted) {
                                                setSheetState(
                                                  () => resetArmed = false,
                                                );
                                              }
                                            },
                                          );
                                          return;
                                        }

                                        confirmationTimer?.cancel();
                                        setSheetState(() {
                                          resetArmed = false;
                                          resetBusy = true;
                                          resetDone = true;
                                        });
                                        final success = await _resetDevices();
                                        if (!success && sheetContext.mounted) {
                                          setSheetState(() {
                                            resetBusy = false;
                                            resetDone = false;
                                          });
                                        }
                                      },
                                icon: Icon(
                                  resetArmed
                                      ? Icons.question_mark_rounded
                                      : resetDone
                                      ? Icons.check_rounded
                                      : Icons.restart_alt,
                                  size: 20,
                                  color: resetArmed
                                      ? AppTheme.warningColor
                                      : resetDone
                                      ? AppTheme.successForeground(
                                          isDark:
                                              Theme.of(
                                                sheetContext,
                                              ).brightness ==
                                              Brightness.dark,
                                        )
                                      : null,
                                  semanticLabel: context.tr(
                                    resetArmed
                                        ? 'Reset all devices?'
                                        : resetDone
                                        ? 'Resetting devices'
                                        : 'Reset all devices',
                                  ),
                                ),
                              ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: Icon(
                                Icons.close,
                                size: 19,
                                semanticLabel: context.tr('Close'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: _muted.withValues(alpha: .2)),
                      Expanded(
                        child: devices.isEmpty
                            ? Center(
                                child: Text(
                                  'No registered devices',
                                  style: TextStyle(color: _muted, fontSize: 13),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                itemCount: devices.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  color: _muted.withValues(alpha: .14),
                                ),
                                itemBuilder: (context, index) {
                                  final device = devices[index];
                                  final model = device['deviceModel']
                                      ?.toString()
                                      .trim();
                                  final isTouchDevice =
                                      Platform.isAndroid || Platform.isIOS;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 3,
                                    ),
                                    leading: Icon(
                                      Icons.devices_outlined,
                                      color: _muted,
                                      size: 20,
                                    ),
                                    title: CompactLabel(
                                      model?.isNotEmpty == true
                                          ? model!
                                          : device['deviceOs']?.toString() ??
                                                'Registered device',
                                      alignment: Alignment.centerLeft,
                                      textAlign: TextAlign.left,
                                    ),
                                    subtitle: Text(
                                      '${context.tr(device['deviceOs']?.toString() ?? 'Unknown OS')}${device['osVersion'] == null ? '' : ' v${device['osVersion']}'}',
                                      maxLines: 2,
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    trailing: Tooltip(
                                      triggerMode: isTouchDevice
                                          ? TooltipTriggerMode.tap
                                          : null,
                                      message:
                                          '${context.tr('Last active')}: ${_lastActive(device['lastUsedAt']?.toString())}',
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Center(
                                          child: Icon(
                                            Icons.hourglass_bottom_rounded,
                                            color: _muted,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
    } finally {
      confirmationTimer?.cancel();
    }
  }

  Future<void> _showSecuritySheet({
    required bool totpConfigured,
    required bool totpEnabled,
    required bool passkeysEnabled,
    required List<Map<String, dynamic>> passkeys,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: .82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: FrostedCard(
              padding: EdgeInsets.zero,
              borderRadius: 20,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Security methods',
                            style: TextStyle(
                              color: _fg,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(
                            Icons.close,
                            size: 19,
                            semanticLabel: context.tr('Close'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _muted.withValues(alpha: .2)),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      children: [
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.verified_user_outlined,
                            size: 20,
                          ),
                          title: Text(context.tr('2FA / TOTP')),
                          subtitle: Text(
                            totpEnabled
                                ? context.tr('Active')
                                : totpConfigured
                                ? context.tr('Paused')
                                : context.tr('Not set up'),
                          ),
                          trailing: !totpConfigured
                              ? const Icon(Icons.add)
                              : null,
                          onTap: _busy
                              ? null
                              : !totpConfigured
                              ? _startTotpSetup
                              : () async {
                                  final action = totpEnabled
                                      ? 'disable'
                                      : 'resume';
                                  if (await _confirm(
                                    context.tr(
                                      totpEnabled
                                          ? 'Pause 2FA?'
                                          : 'Resume 2FA?',
                                    ),
                                    context.tr(
                                      'This changes the authenticator requirement for future sign-ins.',
                                    ),
                                    context.tr('Confirm'),
                                  )) {
                                    await _securityAction(
                                      '/api/user/security/totp/$action',
                                      '2FA updated.',
                                    );
                                  }
                                },
                        ),
                        if (totpConfigured)
                          Padding(
                            padding: const EdgeInsets.only(left: 52),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        if (await _confirm(
                                          context.tr('Remove authenticator?'),
                                          context.tr(
                                            'This removes your authenticator secret and recovery codes.',
                                          ),
                                          context.tr('Remove'),
                                        )) {
                                          await _securityAction(
                                            '/api/user/security/totp/delete',
                                            'Authenticator removed.',
                                          );
                                        }
                                      },
                                child: const Text('Remove TOTP'),
                              ),
                            ),
                          ),
                        Divider(height: 1, color: _muted.withValues(alpha: .2)),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.fingerprint, size: 21),
                          title: Text(context.tr('Passkeys')),
                          subtitle: Text(
                            passkeys.isEmpty
                                ? context.tr('No passkeys')
                                : '${passkeys.length} ${context.tr('registered')} · ${passkeysEnabled ? context.tr('Active') : context.tr('Paused')}',
                          ),
                          trailing: passkeys.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    passkeysEnabled
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
                                    semanticLabel: context.tr(
                                      passkeysEnabled
                                          ? 'Pause passkeys'
                                          : 'Resume passkeys',
                                    ),
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          final action = passkeysEnabled
                                              ? 'disable'
                                              : 'resume';
                                          if (await _confirm(
                                            context.tr(
                                              passkeysEnabled
                                                  ? 'Pause passkeys?'
                                                  : 'Resume passkeys?',
                                            ),
                                            context.tr(
                                              'This affects passkey sign-in on your account.',
                                            ),
                                            context.tr('Confirm'),
                                          )) {
                                            await _securityAction(
                                              '/api/user/security/passkeys/$action',
                                              'Passkeys updated.',
                                            );
                                          }
                                        },
                                )
                              : null,
                        ),
                        for (final key in passkeys)
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.only(left: 38),
                            title: CompactLabel(
                              key['label']?.toString() ?? 'Passkey',
                            ),
                            subtitle: Text(
                              '${context.tr(key['authenticatorAttachment'] == 'platform' ? 'This device' : 'Security key')} · ${context.tr(key['backedUp'] == true ? 'Synced' : 'Device only')}\n${context.tr('Added')} ${_date(key['createdAt']?.toString())}${key['lastUsedAt'] == null ? '' : ' · ${context.tr('Last used')} ${_date(key['lastUsedAt']?.toString())}'}',
                              style: TextStyle(color: _muted, fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                semanticLabel: context.tr('Remove passkey'),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      if (await _confirm(
                                        context.tr('Remove passkey?'),
                                        context.tr(
                                          'This passkey will no longer sign in to your account.',
                                        ),
                                        context.tr('Remove'),
                                      )) {
                                        await _securityAction(
                                          '/api/user/security/passkeys/remove',
                                          'Passkey removed.',
                                          body: {
                                            'credentialId': key['credentialId'],
                                          },
                                        );
                                      }
                                    },
                            ),
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
    );
  }

  Widget _accountShortcut({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              children: [
                Icon(icon, color: _muted, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: _muted, size: 17),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(sessionProvider).valueOrNull;
    final security = account?.security ?? const <String, dynamic>{};
    final passkeys =
        (security['passkeys'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final totpConfigured = security['totpConfigured'] == true;
    final totpEnabled = security['totpEnabled'] == true;
    final passkeysEnabled = passkeys.any((key) => key['enabled'] != false);
    final status = account?.status ?? 'unknown';
    final isActive = status == 'active';
    final usage = account?.usage ?? const <String, dynamic>{};
    final usedValue = (usage['usedGB'] as num?)?.toDouble() ?? 0;
    final limitValue = (usage['limitGB'] as num?)?.toDouble();
    final used = _decimal(usedValue);
    final limit = limitValue == null ? null : _decimal(limitValue);
    final usageFraction = limitValue == null || limitValue <= 0
        ? 0.0
        : (usedValue / limitValue).clamp(0.0, 1.0);
    final remaining = limitValue == null
        ? context.tr('Unlimited')
        : '${_decimal((limitValue - usedValue).clamp(0, double.infinity))} ${context.tr('GB left')}';
    final devices = account?.devices ?? const <Map<String, dynamic>>[];
    final statusLabel = switch (status) {
      'active' => context.tr('Active'),
      'limited' => context.tr('Limited'),
      'expired' => context.tr('Expired'),
      'on_hold' => context.tr('On hold'),
      _ => context.tr('Unknown'),
    };
    final securitySummary = [
      totpEnabled ? context.tr('2FA enabled') : context.tr('2FA off'),
      if (passkeys.isNotEmpty)
        '${passkeys.length} ${context.tr(passkeys.length == 1 ? 'passkey' : 'passkeys')}',
    ].join(' · ');
    final expiry = DateTime.tryParse(account?.expiresAt ?? '');
    final duration = expiry?.difference(DateTime.now());
    final timeLeft = duration == null
        ? '—'
        : duration > Duration.zero
        ? context.daysRemaining(
            (duration.inMicroseconds / Duration.microsecondsPerDay).ceil(),
          )
        : context.tr('Expired');

    return AppPage(
      title: context.tr('Account'),
      child: DefaultTextStyle.merge(
        style: const TextStyle(height: 1.25, letterSpacing: 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 14).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _accountCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          borderRadius: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    key: const ValueKey('account-status-dot'),
                                    size: 6,
                                    color: isActive
                                        ? AppTheme.successForeground(
                                            isDark:
                                                Theme.of(context).brightness ==
                                                Brightness.dark,
                                          )
                                        : status == 'limited'
                                        ? AppTheme.warningColor
                                        : AppTheme.dangerColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        color: _fg,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          context.tr('Created on'),
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _date(account?.createdAt),
                                          style: TextStyle(
                                            color: _fg,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: _muted.withValues(alpha: .2),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('Data usage'),
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '$used GB',
                                          style: TextStyle(
                                            color: _fg,
                                            fontSize: 18,
                                            height: 1.15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: .5,
                                    height: 36,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    color: _muted.withValues(alpha: .25),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('Time left'),
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          timeLeft,
                                          key: const ValueKey(
                                            'account-time-left',
                                          ),
                                          style: TextStyle(
                                            color: _fg,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (limitValue != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  '$remaining · $limit GB',
                                  style: TextStyle(color: _muted, fontSize: 10),
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: usageFraction,
                                  minHeight: 3,
                                  borderRadius: BorderRadius.circular(3),
                                  color: usageFraction >= .9
                                      ? AppTheme.errorColor
                                      : AppTheme.successForeground(
                                          isDark:
                                              Theme.of(context).brightness ==
                                              Brightness.dark,
                                        ),
                                  backgroundColor: _muted.withValues(
                                    alpha: .16,
                                  ),
                                ),
                              ],
                              if (account?.billing['balanceEur'] is num) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${context.tr('Balance')} €${_decimal(account!.billing['balanceEur'] as num)}',
                                  style: TextStyle(color: _muted, fontSize: 10),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 7),
                          child: _label(context.tr('ACCESS CODE')),
                        ),
                        _accountCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          borderRadius: 14,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _showCode
                                      ? (account?.authCode ?? '—')
                                      : '••••••••••',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _showCode ? _fg : _muted,
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              Semantics(
                                label: context.tr(
                                  _showCode
                                      ? 'Hide access code'
                                      : 'Show access code',
                                ),
                                button: true,
                                child: IconButton(
                                  key: const ValueKey(
                                    'account-code-visibility',
                                  ),
                                  style: IconButton.styleFrom().copyWith(
                                    overlayColor: _quietOverlay,
                                    splashFactory: NoSplash.splashFactory,
                                  ),
                                  onPressed:
                                      account?.authCode.isNotEmpty != true
                                      ? null
                                      : () => setState(
                                          () => _showCode = !_showCode,
                                        ),
                                  icon: Icon(
                                    _showCode
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: _muted,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 22,
                                child: VerticalDivider(
                                  width: 1,
                                  color: _muted.withValues(alpha: .2),
                                ),
                              ),
                              Semantics(
                                label: context.tr('Copy access code'),
                                button: true,
                                child: IconButton(
                                  key: const ValueKey('account-code-copy'),
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  style: IconButton.styleFrom().copyWith(
                                    overlayColor: _quietOverlay,
                                    splashFactory: NoSplash.splashFactory,
                                  ),
                                  onPressed:
                                      account?.authCode.isNotEmpty != true
                                      ? null
                                      : () async {
                                          await Clipboard.setData(
                                            ClipboardData(
                                              text: account!.authCode,
                                            ),
                                          );
                                          _message('Access code copied.');
                                        },
                                  icon: Icon(
                                    Icons.copy_outlined,
                                    size: 19,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 7),
                          child: _label(context.tr('ACCOUNT SETTINGS')),
                        ),
                        _accountCard(
                          padding: EdgeInsets.zero,
                          borderRadius: 14,
                          child: Column(
                            children: [
                              _accountShortcut(
                                icon: Icons.devices_outlined,
                                title: 'Devices',
                                subtitle:
                                    '${devices.length} ${context.tr('registered')}',
                                onTap: () => _showDevicesSheet(devices),
                              ),
                              Divider(
                                height: 1,
                                color: _muted.withValues(alpha: .16),
                              ),
                              _accountShortcut(
                                icon: Icons.shield_outlined,
                                title: 'Security',
                                subtitle: securitySummary,
                                onTap: () => _showSecuritySheet(
                                  totpConfigured: totpConfigured,
                                  totpEnabled: totpEnabled,
                                  passkeysEnabled: passkeysEnabled,
                                  passkeys: passkeys,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _fg,
                              minimumSize: const Size.fromHeight(48),
                              side: BorderSide(
                                color: _muted.withValues(alpha: .65),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    await ref
                                        .read(vpnProvider.notifier)
                                        .disconnect();
                                    await ref
                                        .read(sessionProvider.notifier)
                                        .logout();
                                    if (context.mounted) {
                                      Navigator.popUntil(
                                        context,
                                        (route) => route.isFirst,
                                      );
                                    }
                                  }),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: Text(
                              context.tr('Log out'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          InlineAccountDelete(
                            enabled: !_busy,
                            onDelete: _deleteAccount,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _accountCard({
    required Widget child,
    required EdgeInsetsGeometry padding,
    required double borderRadius,
  }) {
    return FrostedCard(
      padding: EdgeInsets.zero,
      borderRadius: borderRadius,
      child: Padding(
        padding: padding,
        child: DefaultTextStyle.merge(
          style: const TextStyle(height: 1.25, letterSpacing: 0),
          child: child,
        ),
      ),
    );
  }

  WidgetStateProperty<Color?> get _quietOverlay => AppTheme.interactionOverlay(
    isDark: Theme.of(context).brightness == Brightness.dark,
  );

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      color: _muted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    ),
  );
}
