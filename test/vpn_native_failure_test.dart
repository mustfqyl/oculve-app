import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/models/user_facing_failure.dart';
import 'package:oculve/core/connection/diagnostic_report.dart';

void main() {
  test('Android startup failures identify the failing stage without native data', () {
    const messages = {
      'ENDPOINT_RESOLUTION_FAILED':
          'Could not resolve the VPN server. Check your internet connection and try again.',
      'NATIVE_VALIDATION_FAILED':
          'The VPN profile is incompatible. Refresh your server list or try another location.',
      'PROFILE_SAVE_FAILED':
          'Could not securely save the VPN profile. Restart the app and try again.',
      'SERVICE_START_FAILED':
          'Android could not start the VPN. Keep the app open and try again.',
      'PERMISSION_REQUEST_IN_PROGRESS':
          'Complete the Android permission prompt before trying again.',
    };
    for (final entry in messages.entries) {
      final error = PlatformException(
        code: entry.key,
        message: 'secret-server-payload',
        details: {'token': 'private'},
      );
      expect(UserFacingFailure.message(error), entry.value);
      expect(UserFacingFailure.message(error), isNot(contains('secret')));
    }
  });

  test(
    'unrecognized platform failures cannot display arbitrary native messages',
    () {
      expect(
        UserFacingFailure.message(
          PlatformException(code: 'UNKNOWN', message: 'secret-server-payload'),
          fallback: 'Please try again.',
        ),
        'Please try again.',
      );
    },
  );

  test(
    'real Xray banner and native stages are exportable without sensitive suffixes',
    () {
      final report = diagnosticReport(
        state: 'disconnected',
        events: [
          '2026-10-13T12:00:00Z Could not resolve the VPN server. Check your internet connection and try again.',
        ],
        pingChecks: 0,
        sharing: false,
        reconnect: true,
        coreVersion:
            'Xray 26.9.9 (Xray, Penetrates Everything.) v26.9.9 (go1.27.0 android/arm64)',
        nativeDiagnostics:
            'ENDPOINT_RESOLUTION_FAILED\nWORKER_EXIT value=1\nsecret-payload\nXRAY_ERROR private.example\nCONNECTED',
      );
      expect(report, contains('Xray: Xray 26.9.9'));
      expect(report, contains('Could not resolve the VPN server.'));
      expect(
        report,
        contains(
          'NATIVE VPN EVENTS\nENDPOINT_RESOLUTION_FAILED\nWORKER_EXIT value=1\nCONNECTED',
        ),
      );
      expect(report, isNot(contains('private.example')));
      expect(report, isNot(contains('secret-payload')));
      expect(report, isNot(contains('go1.27.0')));
    },
  );
}
