import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/desktop/startup_service.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'connection_settings_widgets.dart';

class StartupSetting extends ConsumerStatefulWidget {
  const StartupSetting({super.key});
  @override
  ConsumerState<StartupSetting> createState() => _StartupSettingState();
}

class _StartupSettingState extends ConsumerState<StartupSetting> {
  StartupStatus? _status;
  bool _busy = true, _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([StartupMode? mode]) async {
    setState(() => _busy = true);
    try {
      final service = ref.read(startupServiceProvider);
      final next = mode == null
          ? await service.read()
          : await service.setMode(mode);
      if (mounted) {
        setState(() {
          _status = next;
          _failed = false;
        });
      }
    } catch (error) {
      if (mounted) {
        if (mode != null) {
          AppFeedback.showError(
            context,
            error,
            fallback: 'Could not update startup settings.',
          );
        }
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cycle() async {
    if (_status == null) {
      await _load();
      return;
    }
    final current = _status!.mode;
    await _load(
      StartupMode.values[(current.index + 1) % StartupMode.values.length],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SettingsCycleRow(
        key: const ValueKey('startup-mode'),
        title: 'When your computer starts',
        label: switch (_status?.mode ?? StartupMode.off) {
          StartupMode.off => 'Off',
          StartupMode.open => 'On',
          StartupMode.connect => 'Connect',
        },
        options: const ['Off', 'On', 'Connect'],
        onTap: _busy ? null : _cycle,
      ),
      if (_status?.requiresApproval == true)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SettingRow(
            title: 'Approve Oculve in System Settings → General → Login Items.',
            onTap: _busy ? null : () => _load(),
          ),
        ),
      if (_failed)
        SettingRow(
          title: 'Could not load startup settings. Tap to retry.',
          onTap: _busy ? null : () => _load(),
        ),
    ],
  );
}
