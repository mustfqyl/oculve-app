import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/desktop/startup_service.dart';

class FakeStartupBackend extends StartupBackend {
  bool enabled = false, approval = false, fail = false;
  final changes = <bool>[];
  @override
  Future<({bool enabled, bool requiresApproval})> status() async =>
      (enabled: enabled, requiresApproval: approval);
  @override
  Future<void> setEnabled(bool value) async {
    if (fail) throw StateError('OS registration failed');
    changes.add(value);
    enabled = value;
  }

  @override
  Future<bool> launchedAtLogin(List<String> arguments) async =>
      arguments.contains(DesktopStartupBackend.loginArgument);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Windows and Linux show the app on a regular launch', () {
    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      expect(
        shouldShowDesktopWindowAtLaunch(loginLaunch: false, platform: platform),
        isTrue,
      );
    }
    expect(
      shouldShowDesktopWindowAtLaunch(
        loginLaunch: false,
        platform: TargetPlatform.macOS,
      ),
      isFalse,
    );
    expect(
      shouldShowDesktopWindowAtLaunch(
        loginLaunch: true,
        platform: TargetPlatform.macOS,
      ),
      isTrue,
    );
  });
  test(
    'legacy enabled startup migrates to Open without registration changes',
    () async {
      final backend = FakeStartupBackend()..enabled = true;
      expect((await StartupService(backend).read()).mode, StartupMode.open);
      expect(backend.changes, isEmpty);
    },
  );
  test('three modes persist and toggle only login registration', () async {
    final backend = FakeStartupBackend();
    final service = StartupService(backend);
    for (final mode in [
      StartupMode.open,
      StartupMode.connect,
      StartupMode.off,
    ]) {
      expect((await service.setMode(mode)).mode, mode);
      expect((await StartupService(backend).read()).mode, mode);
    }
    expect(backend.changes, [true, true, false]);
    expect(
      (await SharedPreferences.getInstance()).getString(StartupService.modeKey),
      'off',
    );
  });
  test('failed native update retains the previous mode', () async {
    final backend = FakeStartupBackend();
    final service = StartupService(backend);
    await service.setMode(StartupMode.open);
    backend.fail = true;
    await expectLater(service.setMode(StartupMode.connect), throwsStateError);
    expect((await service.read()).mode, StartupMode.open);
  });
  for (final mode in StartupMode.values) {
    for (final login in [true, false]) {
      test('$mode login=$login connects only at login and once', () async {
        SharedPreferences.setMockInitialValues({
          StartupService.modeKey: mode.name,
        });
        final backend = FakeStartupBackend()..enabled = mode != StartupMode.off;
        final service = StartupService(backend);
        var calls = 0;
        Future<void> connect() async {
          calls++;
        }

        for (var i = 0; i < 2; i++) {
          await service.connectAfterRestore(
            loginLaunch: login,
            hasAccount: true,
            connect: connect,
          );
        }
        expect(calls, login && mode == StartupMode.connect ? 1 : 0);
      });
    }
  }
  test('missing session or pending OS approval never connects', () async {
    SharedPreferences.setMockInitialValues({StartupService.modeKey: 'connect'});
    var calls = 0;
    final backend = FakeStartupBackend()..enabled = true;
    await StartupService(backend).connectAfterRestore(
      loginLaunch: true,
      hasAccount: false,
      connect: () async {
        calls++;
      },
    );
    backend.approval = true;
    await StartupService(backend).connectAfterRestore(
      loginLaunch: true,
      hasAccount: true,
      connect: () async {
        calls++;
      },
    );
    expect(calls, 0);
  });
  test('externally disabled OS entry wins over saved Connect mode', () async {
    SharedPreferences.setMockInitialValues({StartupService.modeKey: 'connect'});
    expect(
      (await StartupService(FakeStartupBackend()).read()).mode,
      StartupMode.off,
    );
  });
  test('Linux entry quotes paths and passes a distinct login argument', () {
    final entry = DesktopStartupBackend.linuxEntry('/opt/Oculve App/oculve');
    expect(entry, contains('Exec="/opt/Oculve App/oculve" --oculve-login'));
    expect(
      DesktopStartupBackend.linuxEntry('/opt/100%/oculve'),
      contains('100%%'),
    );
  });
}
