import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/network/device_hwid.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nativeId = '12345678-1234-5678-9ABC-123456789ABC';

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Oculve',
      packageName: 'com.oculve.app',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({
      'oculve.device.hwid.v1': 'legacy-random-installation-secret',
    });
    FlutterSecureStorage.setMockInitialValues({
      'oculve.device.hwid.v1': 'legacy-random-installation-secret',
    });
  });

  test('subscription uses native identity despite persisted random ID', () async {
    var reads = 0;
    final api = OculveApi(
      deviceHwid: DeviceHwid(
        read: () async {
          reads++;
          return nativeId;
        },
      ),
    );
    addTearDown(api.close);
    final registrationBefore = await api.registrationHeaders();
    final headers = await api.subscriptionRequestHeaders();
    expect(headers['X-HWID'], nativeId);
    expect(headers['user-agent'], 'oculve/0.1.0');
    expect(RegExp(r'^([Hh]app)').hasMatch(headers['user-agent']!), isFalse);
    expect((await api.subscriptionRequestHeaders())['X-HWID'], nativeId);
    expect(reads, 1);
    // Subscription migration must not change the account-registration identity.
    expect(await api.registrationHeaders(), registrationBefore);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('oculve.device.hwid.v1'),
      'legacy-random-installation-secret',
    );
  });

  test('native channel returns the system value without hashing it', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceHwid.channel, (call) async {
          expect(call.method, 'getHwid');
          return nativeId;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceHwid.channel, null);
    });
    expect(
      await DeviceHwid(
        read: () => DeviceHwid.channel.invokeMethod<String>('getHwid'),
      ).get(),
      nativeId,
    );
  });

  test(
    'unavailable native ID stops subscription before any network call',
    () async {
      final api = OculveApi(deviceHwid: DeviceHwid(read: () async => null));
      addTearDown(api.close);
      await expectLater(
        api.subscription('https://unused.invalid/sub/test'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            contains('device identity'),
          ),
        ),
      );
    },
  );

  test(
    'a failed read can be retried and concurrent calls share one read',
    () async {
      var reads = 0;
      final hwid = DeviceHwid(
        read: () async {
          reads++;
          if (reads == 1) throw PlatformException(code: 'HWID_UNAVAILABLE');
          return nativeId;
        },
      );
      await expectLater(hwid.get(), throwsA(isA<DeviceHwidUnavailable>()));
      expect(await Future.wait([hwid.get(), hwid.get()]), [nativeId, nativeId]);
      expect(reads, 2);
    },
  );

  test('a synchronously failing native reader can also be retried', () async {
    var reads = 0;
    final hwid = DeviceHwid(
      read: () {
        if (++reads == 1) throw const DeviceHwidUnavailable();
        return Future.value(nativeId);
      },
    );
    await expectLater(hwid.get(), throwsA(isA<DeviceHwidUnavailable>()));
    expect(await hwid.get(), nativeId);
  });

  for (final invalid in [
    '',
    '00000000-0000-0000-0000-000000000000',
    'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF',
    'bad\r\nInjected: value',
  ]) {
    test(
      'rejects invalid native identity: ${invalid.length} characters',
      () async {
        final hwid = DeviceHwid(read: () async => invalid);
        await expectLater(hwid.get(), throwsA(isA<DeviceHwidUnavailable>()));
      },
    );
  }
}
