import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'vpn_state_test.dart' show TestPlatform;

class _DelayedPlatform extends TestPlatform {
  final initializeGate = Completer<void>();
  final stopGate = Completer<void>();
  int initializations = 0;
  @override
  Future<void> initializeVless({
    required void Function(VlessStatus) onStatusChanged,
    required String notificationIconResourceType,
    required String notificationIconResourceName,
    required String providerBundleIdentifier,
    required String groupIdentifier,
    String? keychainAccessGroup,
  }) async {
    initializations++;
    emit = onStatusChanged;
    await initializeGate.future;
  }

  @override
  Future<void> stopVless() async {
    await stopGate.future;
  }
}

class _DelayedFailureCleanupPlatform extends TestPlatform {
  final cleanupStarted = Completer<void>();
  final cleanupGate = Completer<void>();
  @override
  Future<void> stopVless() async {
    stops++;
    if (stops == 1) {
      cleanupStarted.complete();
      await cleanupGate.future;
    }
  }
}

class _FailedStopPlatform extends TestPlatform {
  @override
  Future<void> stopVless() async => throw StateError('Stop refused');
}

void main() {
  late _DelayedPlatform platform;
  late ProviderContainer container;
  setUp(() {
    platform = _DelayedPlatform();
    VlessPlatform.instance = platform;
    container = ProviderContainer();
  });
  tearDown(() => container.dispose());
  test(
    'simultaneous diagnostics and connect initialize native events once',
    () async {
      final notifier = container.read(vpnProvider.notifier);
      final calls = [notifier.initialize(), notifier.initialize()];
      expect(platform.initializations, 1);
      platform.initializeGate.complete();
      await Future.wait(calls);
      await notifier.initialize();
      expect(platform.initializations, 1);
    },
  );
  test('a new connection waits for native shutdown to finish', () async {
    SharedPreferences.setMockInitialValues({});
    platform.initializeGate.complete();
    final notifier = container.read(vpnProvider.notifier);
    await notifier.initialize();
    container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
    final stopping = notifier.disconnect();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(vpnProvider), VpnState.disconnecting);
    try {
      await notifier.connect();
      expect(platform.starts, 0);
    } finally {
      platform.stopGate.complete();
      await stopping;
    }
    expect(container.read(vpnProvider), VpnState.disconnected);
  });

  test('native stop can finish after its provider is disposed', () async {
    final notifier = container.read(vpnProvider.notifier);
    platform.initializeGate.complete();
    await notifier.initialize();
    final stop = notifier.disconnect();
    await Future<void>.delayed(Duration.zero);
    container.invalidate(vpnProvider);
    platform.stopGate.complete();
    await expectLater(stop, completes);
  });

  test('cancelled failure cleanup cannot republish an old error', () async {
    SharedPreferences.setMockInitialValues({});
    final native = _DelayedFailureCleanupPlatform()..permission = false;
    VlessPlatform.instance = native;
    final notifier = container.read(vpnProvider.notifier);
    container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
    final connect = notifier.connect();
    await native.cleanupStarted.future;
    await notifier.disconnect();
    expect(container.read(vpnProvider), VpnState.disconnected);
    native.cleanupGate.complete();
    await connect;
    expect(container.read(vpnProvider), VpnState.disconnected);
    expect(container.read(vpnErrorProvider), isNull);
    expect(
      notifier.events.where((event) => event.contains('permission')),
      isEmpty,
    );
  });

  testWidgets(
    'a timed out connection reports stop failure without an uncaught error',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      VlessPlatform.instance = _FailedStopPlatform();
      final notifier = container.read(vpnProvider.notifier);
      container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
      final uncaught = <Object>[];
      await runZonedGuarded(
        () => notifier.connect(),
        (error, stack) => uncaught.add(error),
      );
      expect(container.read(vpnProvider), VpnState.connecting);
      await tester.pump(const Duration(seconds: 90));
      await tester.pump();
      expect(uncaught, isEmpty);
      expect(container.read(vpnProvider), VpnState.error);
      expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
      expect(
        container.read(vpnErrorProvider),
        contains('could not be stopped'),
      );
      notifier.dismissError();
    },
  );

  testWidgets('a cancelled timeout cleanup cannot overwrite a newer shutdown', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final native = _DelayedFailureCleanupPlatform();
    VlessPlatform.instance = native;
    final notifier = container.read(vpnProvider.notifier);
    container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
    await notifier.connect();
    await tester.pump(const Duration(seconds: 90));
    await native.cleanupStarted.future;
    await notifier.disconnect();
    native.cleanupGate.complete();
    await tester.pump();
    expect(container.read(vpnProvider), VpnState.disconnected);
    expect(container.read(vpnErrorProvider), isNull);
  });

  testWidgets(
    'revoked permission cancels automatic retries and manual permission can recover',
    (tester) async {
      SharedPreferences.setMockInitialValues({'connection.reconnect': true});
      final native = TestPlatform()
        ..startFailure = PlatformException(code: 'VPN_PERMISSION_REQUIRED');
      VlessPlatform.instance = native;
      final notifier = container.read(vpnProvider.notifier);
      container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
      try {
        await notifier.connect(automatic: true);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(native.starts, 1);
        expect(
          container.read(vpnErrorProvider),
          'VPN permission was not granted.',
        );
        native.startFailure = null;
        await notifier.connect();
        native.emit(VlessStatus(state: 'CONNECTED'));
        expect(container.read(vpnProvider), VpnState.connected);
        expect(native.starts, 2);
      } finally {
        await notifier.disconnect();
        notifier.dismissError();
      }
    },
  );

  testWidgets(
    'permission loss releases protected-switch intent for a manual permission request',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final native = TestPlatform()
        ..replacementFailure = PlatformException(
          code: 'VPN_PERMISSION_REQUIRED',
        );
      VlessPlatform.instance = native;
      final notifier = container.read(vpnProvider.notifier);
      container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
      try {
        await notifier.connect(replacing: true);
        expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
        native.permission = false;
        await notifier.connect();
        expect(native.replacements, 1);
        expect(native.starts, 0);
        native.permission = true;
        native.replacementFailure = null;
        await notifier.connect();
        expect(native.starts, 1);
        expect(native.replacements, 1);
      } finally {
        await notifier.disconnect();
        notifier.dismissError();
      }
    },
  );

  testWidgets(
    'permission loss preserves the traffic barrier if native stop also fails',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final native = _FailedStopPlatform()
        ..startFailure = PlatformException(code: 'VPN_PERMISSION_REQUIRED');
      VlessPlatform.instance = native;
      final notifier = container.read(vpnProvider.notifier);
      container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
      try {
        await notifier.connect(automatic: true);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(native.starts, 1);
        expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
        expect(
          container.read(vpnErrorProvider),
          'VPN permission was not granted.',
        );
      } finally {
        notifier.dismissError();
      }
    },
  );

  testWidgets(
    'OS permission revocation stops retries before queued native teardown',
    (tester) async {
      SharedPreferences.setMockInitialValues({'connection.reconnect': true});
      final native = TestPlatform();
      VlessPlatform.instance = native;
      final notifier = container.read(vpnProvider.notifier);
      container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
      try {
        await notifier.connect();
        native.emit(VlessStatus(state: 'CONNECTED'));
        native.emit(VlessStatus(state: 'PERMISSION_REQUIRED'));
        native.emit(VlessStatus(state: 'CONNECTED')); // Late old worker status.
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(native.starts, 1);
        expect(container.read(vpnProvider), VpnState.error);
        expect(
          container.read(vpnErrorProvider),
          'VPN permission was not granted.',
        );
        expect(container.read(vpnTunnelMayBeActiveProvider), isTrue);
        native.emit(VlessStatus(state: 'DISCONNECTED'));
        expect(container.read(vpnTunnelMayBeActiveProvider), isFalse);
      } finally {
        await notifier.disconnect();
        notifier.dismissError();
      }
    },
  );

  testWidgets(
    'permission revocation invalidates an accepted start still awaiting native completion',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final native = TestPlatform()..startGate = Completer<void>();
      VlessPlatform.instance = native;
      final notifier = container.read(vpnProvider.notifier);
      container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
      await notifier.initialize();
      final connecting = notifier.connect();
    await tester.pump();
      try {
        expect(native.starts, 1);
        native.emit(VlessStatus(state: 'PERMISSION_REQUIRED'));
        native.startGate!.complete();
        await connecting;
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(native.starts, 1);
        expect(native.stops, 1);
        expect(container.read(vpnProvider), VpnState.error);
        expect(
          container.read(vpnErrorProvider),
          'VPN permission was not granted.',
        );
      } finally {
        if (!native.startGate!.isCompleted) native.startGate!.complete();
        await connecting;
        await notifier.disconnect();
        notifier.dismissError();
      }
    },
  );
}
