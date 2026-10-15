import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vless/flutter_vless.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'malformed native status and errors never print their payload',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final method = const MethodChannel('privacy.control');
      final events = const EventChannel('privacy.events');
      final adapter = VlessMethodChannelAdapter(
        methodChannel: method,
        eventChannel: events,
      );
      final messages = <String>[];
      final statuses = <VlessStatus>[];
      final originalPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) messages.add(message);
      };
      messenger.setMockMethodCallHandler(method, (_) async => null);
      messenger.setMockMethodCallHandler(
        const MethodChannel('privacy.events'),
        (_) async => null,
      );
      try {
        await adapter.initializeVless(
          onStatusChanged: statuses.add,
          notificationIconResourceType: '',
          notificationIconResourceName: '',
          providerBundleIdentifier: '',
          groupIdentifier: '',
        );
        Future<void> send(ByteData data) async {
          final done = Completer<void>();
          messenger.handlePlatformMessage(
            'privacy.events',
            data,
            (_) => done.complete(),
          );
          await done.future;
          await Future<void>.delayed(Duration.zero);
        }

        const codec = StandardMethodCodec();
        await send(codec.encodeSuccessEnvelope('private-fixture-payload'));
        await send(
          codec.encodeErrorEnvelope(
            code: 'NATIVE',
            message: 'private-fixture-payload',
            details: {'token': 'private-fixture-payload'},
          ),
        );
        await send(codec.encodeSuccessEnvelope([1, 2, 3, 4, 5, 'CONNECTED']));
        await send(
          codec.encodeSuccessEnvelope([0, 0, 0, 0, 0, 'PERMISSION_REQUIRED']),
        );
        expect(statuses, hasLength(2));
        expect(statuses.first.connectionState, VlessConnectionState.connected);
        expect(statuses.last.state, 'PERMISSION_REQUIRED');
        expect(statuses.last.connectionState, VlessConnectionState.unknown);
        expect(messages, hasLength(2));
        expect(messages.join(), isNot(contains('private-fixture-payload')));
      } finally {
        debugPrint = originalPrint;
        messenger.setMockMethodCallHandler(method, null);
        messenger.setMockMethodCallHandler(
          const MethodChannel('privacy.events'),
          null,
        );
      }
    },
  );
}
