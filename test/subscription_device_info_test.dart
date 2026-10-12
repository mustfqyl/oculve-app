import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/network/device_hwid.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/network/subscription_device_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Oculve',
      packageName: 'com.oculve.app',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  test('subscription identity follows the installed app version', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Oculve',
      packageName: 'com.oculve.app',
      version: '2.8.3',
      buildNumber: '42',
      buildSignature: '',
    );
    final api = OculveApi(
      deviceHwid: DeviceHwid(read: () async => 'stable-hardware-id'),
      deviceInfo: SubscriptionDeviceInfo(read: () async => {}),
    );
    addTearDown(api.close);
    final agent = (await api.subscriptionRequestHeaders())['user-agent']!;
    expect(agent, 'oculve/2.8.3');
    expect(RegExp(r'^([Hh]app)').hasMatch(agent), isFalse);
    expect(RegExp(r'^[Oo]culve/').hasMatch(agent), isTrue);
  });

  test('invalid package metadata cannot impersonate another client', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Oculve',
      packageName: 'com.oculve.app',
      version: '1.0\r\nUser-Agent: Happ/1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final api = OculveApi(
      deviceHwid: DeviceHwid(read: () async => 'stable-hardware-id'),
      deviceInfo: SubscriptionDeviceInfo(read: () async => {}),
    );
    addTearDown(api.close);
    expect(
      (await api.subscriptionRequestHeaders())['user-agent'],
      'oculve/unknown',
    );
  });

  test('subscription carries all four provider device headers', () async {
    final api = OculveApi(
      deviceHwid: DeviceHwid(
        read: () async => '12345678-1234-5678-9ABC-123456789ABC',
      ),
      deviceInfo: SubscriptionDeviceInfo(
        read: () async => {
          'X-Device-OS': 'iOS',
          'X-Ver-OS': '18.2.1',
          'X-Device-Model': 'iPhone15,3',
          'serialNumber': 'must-not-send',
        },
      ),
    );
    addTearDown(api.close);
    expect(await api.subscriptionRequestHeaders(), {
      'user-agent': 'oculve/0.1.0',
      'X-HWID': '12345678-1234-5678-9ABC-123456789ABC',
      'X-Device-OS': 'iOS',
      'X-Ver-OS': '18.2.1',
      'X-Device-Model': 'iPhone15,3',
    });
  });

  test(
    'unavailable optional metadata does not break subscription identity',
    () async {
      final api = OculveApi(
        deviceHwid: DeviceHwid(read: () async => 'stable-hardware-id'),
        deviceInfo: SubscriptionDeviceInfo(
          read: () async => throw StateError('unavailable'),
        ),
      );
      addTearDown(api.close);
      final headers = await api.subscriptionRequestHeaders();
      expect(headers['X-HWID'], 'stable-hardware-id');
      expect(headers['X-Device-OS'], isNotEmpty);
      expect(headers.containsKey('X-Ver-OS'), isFalse);
      expect(headers.containsKey('X-Device-Model'), isFalse);
    },
  );

  test('native values cannot insert extra HTTP headers', () async {
    final info = SubscriptionDeviceInfo(
      read: () async => {
        'X-Ver-OS': '27.0.1',
        'X-Device-Model': 'Model\r\nInjected: value',
        'X-HWID': 'not-allowed-to-override',
      },
    );
    final headers = await info.headers();
    expect(headers['X-Ver-OS'], '27.0.1');
    expect(headers['X-Device-Model'], 'Model  Injected: value');
    expect(headers.containsKey('X-HWID'), isFalse);
  });

  test('normalizes OS names expected by subscription panels', () {
    expect(SubscriptionDeviceInfo.osName('macos'), 'macOS');
    expect(SubscriptionDeviceInfo.osName('ios'), 'iOS');
    expect(SubscriptionDeviceInfo.osName('android'), 'Android');
    expect(SubscriptionDeviceInfo.osName('windows'), 'Windows');
    expect(SubscriptionDeviceInfo.osName('linux'), 'Linux');
  });
}
