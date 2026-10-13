import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vless/flutter_vless.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'unsupported replacement fails closed without start or stop fallback',
    () async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_vless'), (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'getSecurityCapabilities') return <String, bool>{};
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_vless'),
          null,
        ),
      );
      await expectLater(
        VlessMethodChannelAdapter().replaceVless(
          remark: 'New location',
          config: '{}',
          notificationDisconnectButtonName: 'Disconnect',
        ),
        throwsUnsupportedError,
      );
      expect(calls, ['getSecurityCapabilities']);
    },
  );
  test(
    'supported replacement invokes only the protected native command',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_vless'), (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'getSecurityCapabilities') {
          return {'protectedServerSwitch': true};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_vless'),
          null,
        ),
      );
      await VlessMethodChannelAdapter().replaceVless(
        remark: 'New location',
        config: '{}',
        notificationDisconnectButtonName: 'Disconnect',
      );
      expect(calls.map((call) => call.method), [
        'getSecurityCapabilities',
        'replaceVless',
      ]);
      expect(calls.last.arguments, containsPair('config', '{}'));
      expect(calls.last.arguments, containsPair('proxy_only', false));
    },
  );
}
