import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/vpn/android_app_catalog.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_feedback.dart';

class AndroidAppRoutingScreen extends StatefulWidget {
  const AndroidAppRoutingScreen({super.key});

  @override
  State<AndroidAppRoutingScreen> createState() =>
      _AndroidAppRoutingScreenState();
}

class _AndroidAppRoutingScreenState extends State<AndroidAppRoutingScreen> {
  late Future<List<AndroidVpnApp>> _apps;
  final Set<String> _selected = {};
  bool _loaded = false;
  bool _saving = false;

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
      setState(() => _loaded = true);
      AppFeedback.showError(
        context,
        error,
        fallback: 'Could not load app routing settings.',
        placement: AppFeedbackPlacement.pageBottom,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _apps = AndroidAppCatalog.listLaunchableApps();
    unawaited(_loadSelection());
  }

  void _retryLoadingApps() =>
      setState(() => _apps = AndroidAppCatalog.listLaunchableApps());

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });
    try {
      await XrayPreferences.setBlockedApps(_selected.toList());
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(
          context,
          error,
          placement: AppFeedbackPlacement.pageBottom,
        );
      }
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
          return AppErrorState(
            title: 'Could not load installed apps.',
            message: AppFeedback.errorMessage(
              snapshot.error!,
              fallback: 'Could not load installed apps.',
            ),
            primaryLabel: 'Try again',
            onPrimary: _retryLoadingApps,
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
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: CompactLabel(
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
