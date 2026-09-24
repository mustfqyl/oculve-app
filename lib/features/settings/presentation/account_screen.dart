import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/account/private_text_export.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'usage_statistics_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen>
    with WidgetsBindingObserver {
  bool _showCode = false;
  bool _securityExpanded = false;
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
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(description),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
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
          builder: (dialogContext) => AlertDialog(
            title: const Text('Set up authenticator'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scan the QR code or copy the key to an authenticator app.',
                  ),
                  if (qr.startsWith('data:image/png;base64,')) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Image.memory(
                        base64Decode(qr.split(',').last),
                        width: 160,
                        height: 160,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SelectableText(
                    key,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: key)),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy key'),
                  ),
                  TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '6-digit authenticator code',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, {
                  'setupToken': token,
                  'code': code.text.trim(),
                }),
                child: const Text('Enable'),
              ),
            ],
          ),
        );
        if (result == null) return;
        if ((result['code'] as String).length < 6) {
          _message('Enter the code from your authenticator.');
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
          builder: (dialogContext) => AlertDialog(
            title: const Text('Save recovery codes'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'These one-time codes will not be shown again. Save them before closing.',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    codes,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: codes)),
                child: const Text('Copy codes'),
              ),
              TextButton(
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
                child: const Text('Save file'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('I saved them'),
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
    final input = TextEditingController();
    try {
      final phraseAccepted =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'This permanently deletes your VPN account and access. Type DELETE MY ACCOUNT to continue.',
                  ),
                  TextField(
                    controller: input,
                    decoration: const InputDecoration(
                      hintText: 'DELETE MY ACCOUNT',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    input.text == 'DELETE MY ACCOUNT',
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ),
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
    } finally {
      input.dispose();
    }
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
    final devices = account?.devices ?? const <Map<String, dynamic>>[];

    return AppPage(
      title: 'Account',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          FrostedCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            borderRadius: 14,
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: isActive
                      ? AppTheme.successColor
                      : status == 'limited'
                      ? AppTheme.warningColor
                      : AppTheme.dangerColor,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(color: _fg, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: 15, color: _muted),
                const SizedBox(width: 6),
                Text(
                  _date(account?.expiresAt ?? account?.createdAt),
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FrostedCard(
            padding: const EdgeInsets.all(14),
            borderRadius: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('ACCESS CODE'),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showCode
                            ? (account?.authCode ?? '—')
                            : '••••-••••-••••',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _showCode ? 'Hide code' : 'Show code',
                      icon: Icon(
                        _showCode
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                      ),
                      onPressed: () => setState(() => _showCode = !_showCode),
                    ),
                    IconButton(
                      tooltip: 'Copy access code',
                      icon: const Icon(Icons.copy_outlined, size: 19),
                      onPressed: account?.authCode.isNotEmpty == true
                          ? () async {
                              await Clipboard.setData(
                                ClipboardData(text: account!.authCode),
                              );
                              _message('Access code copied.');
                            }
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Download access code',
                      icon: const Icon(Icons.download_outlined, size: 19),
                      onPressed: account?.authCode.isNotEmpty == true
                          ? () => _run(() async {
                              final saved = await exportPrivateText(
                                context,
                                fileName: 'oculve-access-code.txt',
                                contents: accessCodeFileContents(
                                  account!.authCode,
                                ),
                              );
                              if (saved) _message('Access code exported.');
                            })
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FrostedCard(
            padding: const EdgeInsets.all(14),
            borderRadius: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('SUBSCRIPTION'),
                const SizedBox(height: 7),
                Text(
                  account?.plan ?? '—',
                  style: TextStyle(
                    color: _fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Expires ${_date(account?.expiresAt)}  ·  $used${limit == null ? '' : ' / $limit'} GB used',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                if (daysRemaining != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} remaining',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (daysRemaining / 365).clamp(0.0, 1.0),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                    color: daysRemaining <= 3
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                    backgroundColor: _muted.withValues(alpha: .16),
                  ),
                ],
                if (billing['nextBillingAt'] != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Next billing ${_date(billing['nextBillingAt']?.toString())}',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
                if (billing['balanceEur'] is num) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Balance €${(billing['balanceEur'] as num).toStringAsFixed(2)}',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: usageFraction,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                  color: usageFraction >= .9
                      ? AppTheme.errorColor
                      : AppTheme.successColor,
                  backgroundColor: _muted.withValues(alpha: .16),
                ),
                const SizedBox(height: 8),
                Text(
                  limitValue == null
                      ? 'Unlimited data'
                      : '${(limitValue - usedValue).clamp(0, double.infinity).toStringAsFixed(2)} GB remaining',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.oculve.com/billing'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 15),
                    label: const Text('Manage plan'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FrostedCard(
            padding: const EdgeInsets.all(14),
            borderRadius: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _label('REGISTERED DEVICES (${devices.length})'),
                    ),
                    IconButton(
                      tooltip: 'Reset all devices',
                      onPressed: _busy || devices.isEmpty
                          ? null
                          : _resetDevices,
                      icon: const Icon(Icons.restart_alt, size: 20),
                    ),
                  ],
                ),
                if (devices.isEmpty)
                  Text(
                    'No registered devices',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                for (final device in devices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      Icons.devices_outlined,
                      color: _muted,
                      size: 19,
                    ),
                    title: Text(
                      device['deviceModel']?.toString().trim().isNotEmpty ==
                              true
                          ? device['deviceModel'].toString()
                          : device['deviceOs']?.toString() ??
                                'Registered device',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${device['deviceOs'] ?? 'Unknown OS'}${device['osVersion'] == null ? '' : ' v${device['osVersion']}'} · Last active ${_lastActive(device['lastUsedAt']?.toString())}',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FrostedCard(
            padding: EdgeInsets.zero,
            borderRadius: 14,
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.shield_outlined, size: 21),
                  title: Text(
                    'Security methods',
                    style: TextStyle(color: _fg, fontWeight: FontWeight.w700),
                  ),
                  trailing: Icon(
                    _securityExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _muted,
                  ),
                  onTap: () =>
                      setState(() => _securityExpanded = !_securityExpanded),
                ),
                if (_securityExpanded) ...[
                  Divider(height: 1, color: _muted.withValues(alpha: 0.2)),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.verified_user_outlined, size: 20),
                    title: const Text('2FA / TOTP'),
                    subtitle: Text(
                      totpEnabled
                          ? 'Active'
                          : totpConfigured
                          ? 'Paused'
                          : 'Not set up',
                    ),
                    trailing: !totpConfigured ? const Icon(Icons.add) : null,
                    onTap: _busy
                        ? null
                        : !totpConfigured
                        ? _startTotpSetup
                        : () async {
                            final action = totpEnabled ? 'disable' : 'resume';
                            if (await _confirm(
                              '${totpEnabled ? 'Pause' : 'Resume'} 2FA?',
                              'This changes the authenticator requirement for future sign-ins.',
                              'Confirm',
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
                      padding: const EdgeInsets.only(left: 54, right: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (await _confirm(
                                    'Remove authenticator?',
                                    'This removes your authenticator secret and recovery codes.',
                                    'Remove',
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
                  Divider(height: 1, color: _muted.withValues(alpha: 0.2)),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.fingerprint, size: 21),
                    title: const Text('Passkeys'),
                    subtitle: Text(
                      passkeys.isEmpty
                          ? 'No passkeys'
                          : '${passkeys.length} registered · ${passkeysEnabled ? 'Active' : 'Paused'}',
                    ),
                    trailing: passkeys.isNotEmpty
                        ? IconButton(
                            tooltip: passkeysEnabled
                                ? 'Pause passkeys'
                                : 'Resume passkeys',
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
                                      '${passkeysEnabled ? 'Pause' : 'Resume'} passkeys?',
                                      'This affects passkey sign-in on your account.',
                                      'Confirm',
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
                    Padding(
                      padding: const EdgeInsets.only(left: 52),
                      child: ListTile(
                        dense: true,
                        isThreeLine: true,
                        title: Text(
                          key['label']?.toString() ?? 'Passkey',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${key['authenticatorAttachment'] == 'platform' ? 'This device' : 'Security key'} · ${key['backedUp'] == true ? 'Synced' : 'Device only'}\nAdded ${_date(key['createdAt']?.toString())}${key['lastUsedAt'] == null ? '' : ' · Last used ${_date(key['lastUsedAt']?.toString())}'}',
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove passkey',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (await _confirm(
                                    'Remove passkey?',
                                    'This passkey will no longer sign in to your account.',
                                    'Remove',
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
                    ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 54,
                      right: 12,
                      bottom: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse('https://www.oculve.com/dashboard'),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 15),
                        label: const Text('Add passkey on website'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          FrostedCard(
            padding: EdgeInsets.zero,
            borderRadius: 14,
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.bar_chart_outlined, size: 19),
                  title: const Text('Statistics'),
                  trailing: const Icon(Icons.chevron_right, size: 19),
                  onTap: () => Navigator.push(
                    context,
                    appRoute(const UsageStatisticsScreen()),
                  ),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.download_outlined, size: 19),
                  title: const Text('Downloads'),
                  trailing: const Icon(Icons.open_in_new, size: 17),
                  onTap: () => launchUrl(
                    Uri.parse('https://www.oculve.com/download'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.support_agent, size: 19),
                  title: const Text('Support'),
                  trailing: const Icon(Icons.open_in_new, size: 17),
                  onTap: () => launchUrl(
                    Uri.parse('https://www.oculve.com/contact'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await ref.read(vpnProvider.notifier).disconnect();
                    await ref.read(sessionProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    }
                  }),
            child: const Text('Log out'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : _deleteAccount,
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            child: const Text('Delete account'),
          ),
        ],
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
