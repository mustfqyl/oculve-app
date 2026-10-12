import 'dart:io';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:oculve/core/connection/connection_preferences.dart';
import 'package:oculve/core/connection/lan_proxy_service.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'connection_settings_widgets.dart';
import 'package:oculve/core/theme/app_theme.dart';

class LanSharingScreen extends ConsumerStatefulWidget {
  const LanSharingScreen({super.key});
  @override
  ConsumerState<LanSharingScreen> createState() => _LanSharingScreenState();
}

class _LanSharingScreenState extends ConsumerState<LanSharingScreen> {
  final _port = TextEditingController(),
      _user = TextEditingController(),
      _password = TextEditingController();
  bool _loading = true, _busy = false, _enabled = false, _reveal = false;
  List<String> _addresses = [];
  String? _address;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await ConnectionPreferences.read();
      final password = await ConnectionPreferences.password();
      final addresses = await LanProxyService.addresses();
      if (!mounted) return;
      setState(() {
        _enabled = settings.shareLan;
        _port.text = '${settings.port}';
        _user.text = settings.username;
        _password.text = password.isEmpty
            ? ConnectionPreferences.newPassword()
            : password;
        _addresses = addresses;
        _address = addresses.contains(settings.address)
            ? settings.address
            : addresses.firstOrNull;
      });
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(
          context,
          error,
          fallback: 'Could not load LAN sharing settings.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(bool enabled, {bool persistCredentials = false}) async {
    setState(() => _busy = true);
    try {
      if (enabled && (_address == null || !_addresses.contains(_address))) {
        throw StateError('Choose a local network address.');
      }
      if (!enabled && !persistCredentials) {
        await ConnectionPreferences.disableLan();
      } else {
        await ConnectionPreferences.saveLan(
          enabled: enabled,
          port: int.tryParse(_port.text) ?? 0,
          username: _user.text.trim(),
          address: _address ?? '',
          password: _password.text,
        );
      }
      if (!mounted) return;
      setState(() => _enabled = enabled);
      await ref.read(vpnProvider.notifier).syncLanSharing();
      if (mounted) {
        AppFeedback.showMessage(
          context,
          enabled
              ? 'LAN sharing saved. Reconnect to apply these settings.'
              : 'LAN sharing stopped.',
        );
      }
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(
          context,
          error,
          fallback:
              'Check your LAN address, port, username and password. Use at least 12 characters for the password.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _port.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(lanProxyProvider);
    return AppPage(
      title: 'LAN proxy sharing',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SettingsCaption('LOCAL NETWORK'),
                SettingsGroup(
                  children: [
                    SettingRow(
                      title: 'Share VPN connection',
                      subtitle:
                          'HTTP and SOCKS5 proxy with password authentication.',
                      trailing: Switch(
                        activeTrackColor: AppTheme.successColor,
                        activeThumbColor: Colors.white,
                        value: _enabled,
                        onChanged: _busy || !Platform.isMacOS ? null : _save,
                        overlayColor: quietOverlay,
                      ),
                    ),
                  ],
                ),
                if (!Platform.isMacOS)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'LAN proxy sharing is currently available on macOS.',
                    ),
                  ),
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    SettingsCycleRow(
                      options: _addresses,
                      title: 'Local address',
                      label: _address ?? 'Unavailable',
                      onTap: _busy || _addresses.length < 2
                          ? null
                          : () async {
                              if (_addresses.isNotEmpty && mounted) {
                                setState(
                                  () => _address =
                                      _addresses[(_addresses.indexOf(
                                                _address ?? '',
                                              ) +
                                              1) %
                                          _addresses.length],
                                );
                              }
                            },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          _field(
                            _port,
                            'Proxy port',
                            keyboard: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          _field(_user, 'Username'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: !_reveal,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: context.tr('Password'),
                              suffixIcon: IconButton(
                                style: IconButton.styleFrom().copyWith(
                                  overlayColor: quietOverlay,
                                ),
                                onPressed: () =>
                                    setState(() => _reveal = !_reveal),
                                icon: Icon(
                                  _reveal
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 12,
                            children: [
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _password.text =
                                            ConnectionPreferences.newPassword(),
                                      ),
                                child: const Text('New password'),
                              ),
                              TextButton(
                                onPressed: _busy || !Platform.isMacOS
                                    ? null
                                    : () => _save(
                                        _enabled,
                                        persistCredentials: true,
                                      ),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  service.running
                      ? 'Sharing is active.'
                      : _enabled
                      ? 'Sharing starts after the VPN connects. Reconnect after changes.'
                      : 'Sharing is off.',
                  style: TextStyle(color: settingsMuted(context), fontSize: 12),
                ),
                if (service.running)
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: '${service.address}:${service.port}',
                        ),
                      );
                      if (context.mounted) {
                        AppFeedback.showMessage(
                          context,
                          'Proxy address copied.',
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: Text('${service.address}:${service.port}'),
                  ),
                if (service.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(service.error!),
                  ),
                const SizedBox(height: 14),
                Text(
                  'Set this address and port as the proxy on your other device. Both devices must be on the same local network. TCP traffic only; this does not create a Wi-Fi hotspot.',
                  style: TextStyle(
                    color: settingsMuted(context),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
  }) => TextField(
    controller: controller,
    keyboardType: keyboard,
    autocorrect: false,
    enableSuggestions: false,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(labelText: context.tr(label)),
  );
}
