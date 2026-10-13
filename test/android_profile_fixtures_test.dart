import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'native startup fixtures use the real Oculve import and default settings',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dnsSettings = await XrayPreferences.userDnsSettings();
      const transports = {
        'tcp': 'type=tcp&security=none',
        'tls': 'type=tcp&security=tls&sni=example.test',
        'reality':
            'type=tcp&security=reality&sni=example.test&fp=chrome&pbk=AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA&sid=12345678&flow=xtls-rprx-vision',
      };
      for (final entry in transports.entries) {
        final profile = VpnProfile.parseSubscription(
          'vless://11111111-1111-4111-8111-111111111111@192.0.2.10:443?${entry.value}#Synthetic',
        ).single;
        final configured = XrayPreferences.configure(
          profile.config,
          RealityFingerprint.serverDefault,
          dnsSettings: dnsSettings,
        );
        final fixture = File(
          'vendor/flutter_vless/packages/flutter_vless_android/android/src/androidTest/assets/oculve-vless-${entry.key}.json',
        );
        expect(
          jsonDecode(fixture.readAsStringSync()),
          jsonDecode(configured),
          reason: entry.key,
        );
      }
    },
  );
}
