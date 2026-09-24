import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/account/private_text_export.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
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
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  String _lastActive(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toUtc();
    if (date == null) return '—';
    String two(int part) => part.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)} UTC';
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _message(error.toString());
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
              child: Text(context.tr('Cancel')),
            );
            final confirm = cupertino.CupertinoDialogAction(
              isDestructiveAction: title == 'Permanently delete?',
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr(action)),
            );
            if (Platform.isMacOS || Platform.isIOS) {
              return cupertino.CupertinoAlertDialog(
                title: Text(context.tr(title)),
                content: Text(context.tr(description)),
                actions: [cancel, confirm],
              );
            }
            return AlertDialog(
              title: Text(context.tr(title)),
              content: Text(context.tr(description)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.tr('Cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.tr(action)),
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
                      tooltip: context.tr('Close'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, size: 18),
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

  Future<void> _resetDevices() async {
    if (!await _confirm(
      'Sign out all devices?',
      'This clears registered devices and rotates your subscription link. VPN connections will stop until they sign in again.',
      'Reset devices',
    )) {
      return;
    }
    await _run(() async {
      await ref.read(vpnProvider.notifier).disconnect();
      await ref.read(apiProvider).request('/api/user/devices/reset', body: {});
      // Fetch account metadata only. Downloading the new subscription here
      // would immediately register this same device again after reset.
      await ref.read(sessionProvider.notifier).refreshAccount();
      _message('Devices reset. Your subscription link has changed.');
    });
  }

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
                        tooltip: context.tr('Copy setup key'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: key));
                          _message(context.tr('Setup key copied.'));
                        },
                        icon: const Icon(Icons.copy_outlined, size: 17),
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
                tooltip: context.tr('Done'),
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.check),
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
    final phraseAccepted =
        await showDialog<bool>(
          context: context,
          builder: (_) => const _DeleteAccountConfirmationDialog(),
        ) ??
        false;
    if (!phraseAccepted || !mounted) return;
    final finalConfirmed = await _confirm(
      'Permanently delete?',
      'Your account and VPN access cannot be restored.',
      'Delete permanently',
    );
    if (!finalConfirmed || !mounted) return;
    await _run(() async {
      await ref.read(vpnProvider.notifier).disconnect();
      await ref.read(apiProvider).request('/api/user/me', method: 'DELETE');
      await ref.read(apiProvider).clear();
      ref.read(sessionProvider.notifier).clearLocalSession();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    });
  }

  Future<void> _showDevicesSheet(List<Map<String, dynamic>> devices) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: FractionallySizedBox(
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
                            tooltip: context.tr('Reset all devices'),
                            onPressed: _busy ? null : _resetDevices,
                            icon: const Icon(Icons.restart_alt, size: 20),
                          ),
                        IconButton(
                          tooltip: context.tr('Close'),
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, size: 19),
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
                                title: Text(
                                  model?.isNotEmpty == true
                                      ? model!
                                      : device['deviceOs']?.toString() ??
                                            'Registered device',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${context.tr(device['deviceOs']?.toString() ?? 'Unknown OS')}${device['osVersion'] == null ? '' : ' v${device['osVersion']}'} · ${context.tr('Last active')} ${_lastActive(device['lastUsedAt']?.toString())}',
                                  maxLines: 2,
                                  style: TextStyle(color: _muted, fontSize: 11),
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
    );
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
                          tooltip: context.tr('Close'),
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, size: 19),
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
                                  tooltip: context.tr(
                                    passkeysEnabled
                                        ? 'Pause passkeys'
                                        : 'Resume passkeys',
                                  ),
                                  icon: Icon(
                                    passkeysEnabled
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
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
                            title: Text(
                              key['label']?.toString() ?? 'Passkey',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${context.tr(key['authenticatorAttachment'] == 'platform' ? 'This device' : 'Security key')} · ${context.tr(key['backedUp'] == true ? 'Synced' : 'Device only')}\n${context.tr('Added')} ${_date(key['createdAt']?.toString())}${key['lastUsedAt'] == null ? '' : ' · ${context.tr('Last used')} ${_date(key['lastUsedAt']?.toString())}'}',
                              style: TextStyle(color: _muted, fontSize: 11),
                            ),
                            trailing: IconButton(
                              tooltip: context.tr('Remove passkey'),
                              icon: const Icon(Icons.delete_outline, size: 18),
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
    return FrostedCard(
      padding: EdgeInsets.zero,
      borderRadius: 14,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              children: [
                Icon(icon, color: _muted, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
    final expiry = DateTime.tryParse(account?.expiresAt ?? '');
    final daysRemaining = expiry == null
        ? null
        : (expiry.difference(DateTime.now()).inMilliseconds /
                  Duration.millisecondsPerDay)
              .ceil()
              .clamp(0, 9999);
    final usage = account?.usage ?? const <String, dynamic>{};
    final billing = account?.billing ?? const <String, dynamic>{};
    final usedValue = (usage['usedGB'] as num?)?.toDouble() ?? 0;
    final limitValue = (usage['limitGB'] as num?)?.toDouble();
    final used = usedValue.toStringAsFixed(2);
    final limit = limitValue?.toStringAsFixed(2);
    final usageFraction = limitValue == null || limitValue <= 0
        ? 0.0
        : (usedValue / limitValue).clamp(0.0, 1.0);
    final remaining = limitValue == null
        ? context.tr('Unlimited data')
        : '${(limitValue - usedValue).clamp(0, double.infinity).toStringAsFixed(2)} ${context.tr('GB left')}';
    final devices = account?.devices ?? const <Map<String, dynamic>>[];
    final statusLabel = switch (status) {
      'active' => context.tr('Active'),
      'limited' => context.tr('Limited'),
      'expired' => context.tr('Expired'),
      'on_hold' => context.tr('On hold'),
      _ => context.tr('Unknown'),
    };
    final securitySummary = [
      totpEnabled ? context.tr('2FA active') : context.tr('2FA off'),
      if (passkeys.isNotEmpty) '${passkeys.length} ${context.tr('passkeys')}',
    ].join(' · ');
    final billingSummary = [
      if (billing['nextBillingAt'] != null)
        '${context.tr('Next billing')} ${_date(billing['nextBillingAt']?.toString())}',
      if (billing['balanceEur'] is num)
        '${context.tr('Balance')} €${(billing['balanceEur'] as num).toStringAsFixed(2)}',
    ].join(' · ');

    return AppPage(
      title: context.tr('Account'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gap = constraints.maxHeight < 430 ? 5.0 : 7.0;
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FrostedCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  borderRadius: 13,
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: isActive
                            ? AppTheme.successColor
                            : status == 'limited'
                            ? AppTheme.warningColor
                            : AppTheme.dangerColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: _fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: _muted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _date(account?.expiresAt ?? account?.createdAt),
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: gap),
                FrostedCard(
                  padding: const EdgeInsets.fromLTRB(11, 7, 7, 7),
                  borderRadius: 13,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(context.tr('ACCESS CODE')),
                            const SizedBox(height: 2),
                            Semantics(
                              button: true,
                              label: _showCode
                                  ? context.tr(
                                      'Access code visible. Tap to copy.',
                                    )
                                  : context.tr(
                                      'Access code hidden. Tap to reveal.',
                                    ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: account?.authCode.isNotEmpty != true
                                      ? null
                                      : () async {
                                          if (!_showCode) {
                                            setState(() => _showCode = true);
                                            return;
                                          }
                                          await Clipboard.setData(
                                            ClipboardData(
                                              text: account!.authCode,
                                            ),
                                          );
                                          _message('Access code copied.');
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        end: _showCode ? 0 : 6.5,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, blur, child) =>
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                              child: ImageFiltered(
                                                imageFilter: ImageFilter.blur(
                                                  sigmaX: blur,
                                                  sigmaY: blur,
                                                ),
                                                child: child,
                                              ),
                                            ),
                                          ),
                                      child: ExcludeSemantics(
                                        child: Text(
                                          account?.authCode.isNotEmpty == true
                                              ? account!.authCode
                                              : '—',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: _fg,
                                            fontFamily: 'monospace',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: gap),
                FrostedCard(
                  padding: const EdgeInsets.fromLTRB(11, 7, 7, 8),
                  borderRadius: 13,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account?.plan ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _fg,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (daysRemaining != null)
                                  Text(
                                    context.daysRemaining(daysRemaining),
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: context.tr('Manage plan'),
                            constraints: const BoxConstraints.tightFor(
                              width: 30,
                              height: 30,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.open_in_new, size: 16),
                            onPressed: () => launchUrl(
                              Uri.parse('https://www.oculve.com/billing'),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              limit == null
                                  ? '$used GB used'
                                  : '$used / $limit GB',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            remaining,
                            style: TextStyle(color: _muted, fontSize: 9),
                          ),
                        ],
                      ),
                      if (limitValue != null) ...[
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: usageFraction,
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(3),
                          color: usageFraction >= .9
                              ? AppTheme.errorColor
                              : AppTheme.successColor,
                          backgroundColor: _muted.withValues(alpha: .16),
                        ),
                      ],
                      if (billingSummary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          billingSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 9),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: gap),
                Row(
                  children: [
                    Expanded(
                      child: _accountShortcut(
                        icon: Icons.devices_outlined,
                        title: 'Devices',
                        subtitle: '${devices.length} registered',
                        onTap: () => _showDevicesSheet(devices),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _accountShortcut(
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
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.dangerColor,
                        minimumSize: const Size.fromHeight(53),
                        side: BorderSide(
                          color: AppTheme.dangerColor.withValues(alpha: .42),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _busy ? null : _deleteAccount,
                      icon: const Icon(Icons.delete_outline, size: 17),
                      label: Text(
                        context.tr('Delete account'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(53),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              await ref.read(vpnProvider.notifier).disconnect();
                              await ref.read(sessionProvider.notifier).logout();
                              if (context.mounted) {
                                Navigator.popUntil(
                                  context,
                                  (route) => route.isFirst,
                                );
                              }
                            }),
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: Text(
                        context.tr('Log out'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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

class _DeleteAccountConfirmationDialog extends StatefulWidget {
  const _DeleteAccountConfirmationDialog();

  @override
  State<_DeleteAccountConfirmationDialog> createState() =>
      _DeleteAccountConfirmationDialogState();
}

class _DeleteAccountConfirmationDialogState
    extends State<_DeleteAccountConfirmationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phrase = context.tr('DELETE MY ACCOUNT');
    final canDelete =
        _controller.text.trim().toUpperCase() == phrase.trim().toUpperCase();
    final appleStyle = Platform.isMacOS || Platform.isIOS;
    final confirmationInput = appleStyle
        ? cupertino.CupertinoTextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            placeholder: phrase,
          )
        : TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.tr('Confirmation phrase'),
              hintText: phrase,
              isDense: true,
            ),
          );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            'This permanently deletes your Oculve account and VPN access.',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'This action cannot be undone. Type the phrase below to confirm.',
          ),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.foregroundMuted
                : AppTheme.lightForegroundMuted,
          ),
        ),
        const SizedBox(height: 16),
        confirmationInput,
      ],
    );

    if (appleStyle) {
      return cupertino.CupertinoAlertDialog(
        title: Text(context.tr('Delete account?')),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: content,
        ),
        actions: [
          cupertino.CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          cupertino.CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: canDelete ? () => Navigator.pop(context, true) : null,
            child: Text(context.tr('Delete account')),
          ),
        ],
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      icon: const Icon(
        Icons.delete_forever_outlined,
        color: AppTheme.dangerColor,
      ),
      title: Text(context.tr('Delete account?')),
      content: SizedBox(width: 340, child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.dangerColor,
            foregroundColor: Colors.white,
          ),
          onPressed: canDelete ? () => Navigator.pop(context, true) : null,
          child: Text(context.tr('Delete account')),
        ),
      ],
      backgroundColor: dark ? const Color(0xFF17191D) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    );
  }
}
