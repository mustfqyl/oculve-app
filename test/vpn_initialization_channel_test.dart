import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vpn_state_test.dart' show TestApi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Oculve initializes Android through the real adapter without requiring iOS Keychain',
    () async {
      SharedPreferences.setMockInitialValues({});
      final original = VlessPlatform.instance;
      final adapter = VlessMethodChannelAdapter();
      VlessPlatform.instance = adapter;
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_vless'), (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'getSecurityCapabilities') {
          // Exactly the capabilities returned by the packaged Android plugin.
          return {'androidProxyDns': true, 'iosKeychainReference': false};
        }
        if (call.method == 'requestPermission') return true;
        return null;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter_vless/status'),
        (_) async => null,
      );
      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(TestApi())],
      );
      try {
        await container.read(vpnProvider.notifier).initialize();
        expect(calls.map((call) => call.method), contains('initializeVless'));
        final initialization = calls.singleWhere(
          (call) => call.method == 'initializeVless',
        );
        expect(
          initialization.arguments,
          isNot(contains('keychainAccessGroup')),
        );
        await container.read(sessionProvider.notifier).refresh();
        await container.read(vpnProvider.notifier).connect();
        expect(calls.map((call) => call.method), contains('requestPermission'));
        final start = calls.singleWhere((call) => call.method == 'startVless');
        if (Platform.isAndroid) {
          expect(start.arguments, containsPair('android_dns_policy', 'proxy'));
        } else {
          expect(start.arguments, isNot(contains('android_dns_policy')));
        }
      } finally {
        container.dispose();
        VlessPlatform.instance = original;
        messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_vless'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_vless/status'),
          null,
        );
      }
    },
  );
}
