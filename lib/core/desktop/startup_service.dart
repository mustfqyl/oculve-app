import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StartupMode { off, open, connect }

class StartupStatus {
  const StartupStatus(this.mode, {this.requiresApproval = false});
  final StartupMode mode;
  final bool requiresApproval;
}

abstract class StartupBackend {
  Future<({bool enabled, bool requiresApproval})> status();
  Future<void> setEnabled(bool enabled);
  Future<bool> launchedAtLogin(List<String> arguments);
}

final startupServiceProvider = Provider(
  (ref) => StartupService(DesktopStartupBackend()),
);
final loginLaunchProvider = Provider<bool>((ref) => false);

class StartupService {
  StartupService(this.backend);
  final StartupBackend backend;
  static const modeKey = 'startup.mode.v1';
  bool _attempted = false;
  bool _saving = false;

  Future<StartupStatus> read() async {
    final native = await backend.status();
    if (!native.enabled && !native.requiresApproval) {
      return const StartupStatus(StartupMode.off);
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(modeKey);
    // Preserve the old native launch-at-login toggle as Open.
    final mode = saved == StartupMode.connect.name
        ? StartupMode.connect
        : StartupMode.open;
    return StartupStatus(mode, requiresApproval: native.requiresApproval);
  }

  Future<StartupStatus> setMode(StartupMode mode) async {
    if (_saving) throw StateError('Startup settings are being saved.');
    _saving = true;
    try {
      final previous = await read();
      await backend.setEnabled(mode != StartupMode.off);
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(modeKey, mode.name)) {
          throw StateError('Could not save startup settings.');
        }
      } catch (_) {
        await backend.setEnabled(previous.mode != StartupMode.off);
        rethrow;
      }
      return await read();
    } finally {
      _saving = false;
    }
  }

  Future<void> connectAfterRestore({
    required bool loginLaunch,
    required bool hasAccount,
    required Future<void> Function() connect,
  }) async {
    if (_attempted) return;
    _attempted = true;
    if (!loginLaunch || !hasAccount) return;
    final status = await read();
    if (status.mode == StartupMode.connect && !status.requiresApproval) {
      await connect();
    }
  }
}

class DesktopStartupBackend extends StartupBackend {
  static const channel = MethodChannel('oculve/startup');
  static const loginArgument = '--oculve-login';
  static const runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  File get _desktopFile {
    final config = Platform.environment['XDG_CONFIG_HOME'];
    final home = Platform.environment['HOME'];
    if ((config == null || !config.startsWith('/')) && home == null) {
      throw StateError('Could not locate startup settings.');
    }
    return File(
      '${config != null && config.startsWith('/') ? config : '$home/.config'}/autostart/oculve.desktop',
    );
  }

  static String linuxEntry(String executable) {
    // Desktop Entry quoting has two escaping layers; percent introduces field codes.
    final escaped = executable
        .replaceAll('\\', r'\\\\')
        .replaceAll('"', r'\\"')
        .replaceAll('`', r'\\`')
        .replaceAll(r'$', r'\\$')
        .replaceAll('%', '%%');
    return '[Desktop Entry]\nType=Application\nName=Oculve\nExec="$escaped" $loginArgument\nTerminal=false\n';
  }

  @override
  Future<({bool enabled, bool requiresApproval})> status() async {
    if (Platform.isMacOS) {
      final result = await channel.invokeMapMethod<String, dynamic>('status');
      if (result == null) throw StateError('Could not load startup settings.');
      return (
        enabled: result['enabled'] == true,
        requiresApproval: result['requiresApproval'] == true,
      );
    }
    if (Platform.isWindows) {
      final result = await Process.run('reg.exe', [
        'query',
        runKey,
        '/v',
        'Oculve',
      ]);
      return (enabled: result.exitCode == 0, requiresApproval: false);
    }
    if (Platform.isLinux) {
      final file = _desktopFile;
      final content = await file.exists() ? await file.readAsString() : '';
      return (
        enabled: content.contains('Exec=') && !content.contains('Hidden=true'),
        requiresApproval: false,
      );
    }
    return (enabled: false, requiresApproval: false);
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (Platform.isMacOS) {
      await channel.invokeMethod('setEnabled', enabled);
    } else if (Platform.isWindows) {
      if (!enabled && !(await status()).enabled) return;
      final result = await Process.run(
        'reg.exe',
        enabled
            ? [
                'add',
                runKey,
                '/v',
                'Oculve',
                '/t',
                'REG_SZ',
                '/d',
                '"${Platform.resolvedExecutable}" $loginArgument',
                '/f',
              ]
            : ['delete', runKey, '/v', 'Oculve', '/f'],
      );
      if (result.exitCode != 0) {
        throw StateError('Could not update startup settings.');
      }
    } else if (Platform.isLinux) {
      final file = _desktopFile;
      if (enabled) {
        await file.parent.create(recursive: true);
        await file.writeAsString(
          linuxEntry(Platform.resolvedExecutable),
          flush: true,
        );
      } else if (await file.exists()) {
        await file.delete();
      }
    } else {
      throw UnsupportedError('Startup is available on desktop.');
    }
  }

  @override
  Future<bool> launchedAtLogin(List<String> arguments) async {
    if (Platform.isMacOS) {
      return await channel.invokeMethod<bool>('launchContext') ?? false;
    }
    return arguments.contains(loginArgument);
  }
}
