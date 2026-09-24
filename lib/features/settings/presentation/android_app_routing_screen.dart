import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/vpn/android_app_catalog.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'package:oculve/core/widgets/app_page.dart';

class AndroidAppRoutingScreen extends StatefulWidget {
  const AndroidAppRoutingScreen({super.key});

  @override
  State<AndroidAppRoutingScreen> createState() =>
      _AndroidAppRoutingScreenState();
}

class _AndroidAppRoutingScreenState extends State<AndroidAppRoutingScreen> {
  late final Future<List<AndroidVpnApp>> _apps =
      AndroidAppCatalog.listLaunchableApps();
  final Set<String> _selected = {};
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  Future<void> _loadSelection() async {
    try {
      final apps = await XrayPreferences.blockedApps();
      if (!mounted) return;
      setState(() {
        _selected.addAll(apps);
        _loaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loaded = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadSelection());
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await XrayPreferences.setBlockedApps(_selected.toList());
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Apps outside the VPN',
    child: FutureBuilder<List<AndroidVpnApp>>(
      future: _apps,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load installed apps. ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.errorColor),
              ),
            ),
          );
        }
        if (!snapshot.hasData || !_loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final apps = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: FrostedCard(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Selected apps use your regular connection. All other apps stay protected by Oculve. Changes apply after the next connection.',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.foregroundMuted
                        : AppTheme.lightForegroundMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FrostedCard(
                      padding: EdgeInsets.zero,
                      child: SwitchListTile.adaptive(
                        secondary: app.icon == null
                            ? const Icon(Icons.apps_outlined)
                            : Image.memory(app.icon!, width: 32, height: 32),
                        title: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          app.packageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: _selected.contains(app.packageName),
                        onChanged: _saving
                            ? null
                            : (enabled) => setState(() {
                                if (enabled) {
                                  _selected.add(app.packageName);
                                } else {
                                  _selected.remove(app.packageName);
                                }
                              }),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 12,
                  ),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? 'Saving…' : 'Save ${_selected.length} apps',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
