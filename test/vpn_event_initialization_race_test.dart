import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vless/flutter_vless.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final delayedCapability in [false, true]) {
    test(
      'only newest listener survives overlapping init (capability delay: $delayedCapability)',
      () async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const method = MethodChannel('init-race.control');
        const eventMethod = MethodChannel('init-race.events');
        final adapter = VlessMethodChannelAdapter(
          methodChannel: method,
          eventChannel: const EventChannel('init-race.events'),
        );
        final controls = <MethodCall>[];
        final eventCalls = <String>[];
        final oldStatuses = <VlessStatus>[];
        final latestStatuses = <VlessStatus>[];
        final capability = Completer<Map<String, bool>>();
        messenger.setMockMethodCallHandler(method, (call) async {
          if (call.method == 'getSecurityCapabilities') {
            return capability.future;
          }
          controls.add(call);
          return null;
        });
        messenger.setMockMethodCallHandler(eventMethod, (call) async {
          eventCalls.add(call.method);
          return null;
        });
        Future<void> initialize(
          void Function(VlessStatus) callback,
          String group,
        ) => adapter.initializeVless(
          onStatusChanged: callback,
          notificationIconResourceType: '',
          notificationIconResourceName: '',
          providerBundleIdentifier: '',
          groupIdentifier: group,
          keychainAccessGroup: delayedCapability && group == 'obsolete'
              ? 'fixture.group'
              : null,
        );
        try {
          await initialize(oldStatuses.add, 'initial');
          final obsolete = initialize(oldStatuses.add, 'obsolete');
          final latest = initialize(latestStatuses.add, 'latest');
          if (delayedCapability) {
            await latest;
            capability.complete({'iosKeychainReference': true});
          }
          await Future.wait([obsolete, latest]);
          await Future<void>.delayed(Duration.zero);
          expect(eventCalls.where((call) => call == 'listen'), hasLength(2));
          expect(
            controls.map((call) => (call.arguments as Map)['groupIdentifier']),
            ['initial', 'latest'],
          );
          final received = Completer<void>();
          messenger.handlePlatformMessage(
            'init-race.events',
            const StandardMethodCodec().encodeSuccessEnvelope([
              0,
              0,
              0,
              0,
              0,
              'CONNECTED',
            ]),
            (_) => received.complete(),
          );
          await received.future;
          await Future<void>.delayed(Duration.zero);
          expect(oldStatuses, isEmpty);
          expect(
            latestStatuses.single.connectionState,
            VlessConnectionState.connected,
          );
        } finally {
          messenger.setMockMethodCallHandler(method, null);
          messenger.setMockMethodCallHandler(eventMethod, null);
        }
      },
    );
  }
}
