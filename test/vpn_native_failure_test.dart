import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/models/user_facing_failure.dart';
import 'package:oculve/core/connection/diagnostic_report.dart';
import 'package:oculve/features/settings/presentation/client_logs_screen.dart';

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

  test('Apple timestamped provider lines export fixed phase codes in order', () {
    final report = diagnosticReport(
      state: 'connecting',
      events: const [],
      pingChecks: 0,
      sharing: false,
      reconnect: true,
      nativeDiagnostics: [
        '2026-10-28T10:00:01Z Starting Xray packet tunnel',
        '2026-10-28T10:00:02Z On-demand recovery armed for tunnel session',
        '2026-10-28T10:00:03Z Tunnel preparation failed before route installation',
        '2026-10-28T10:00:04Z Protected tunnel routes and virtual DNS installed',
        '2026-10-28T10:00:05Z Using Xray default geo asset lookup',
        '2026-10-28T10:00:06Z XRay started successfully',
        '2026-10-28T10:00:07Z Starting HEV socks5 tunnel on 127.0.0.1:41790, log=<redacted>',
        '2026-10-28T10:00:08Z HEV remained running through startup grace period',
        '2026-10-28T10:00:09Z Watchdog <redacted>: success=true inbound=[<redacted>] connect=[<redacted>] http=[<redacted>]',
        '2026-10-28T10:00:10Z Protected tunnel forwarding restored',
        '2026-10-28T10:00:11Z Stopping Xray packet tunnel, reason=<redacted>',
        '2026-10-28T10:00:12Z Failed to start XRay: <redacted>',
        '2026-10-28T10:00:13Z HEV socks5 tunnel exited with code -1',
        '2026-10-28T10:00:14Z Managed DPI engine exited; restarting inside the protected tunnel',
        '2026-10-28T10:00:15Z Native restart failed; protected traffic remains blocked',
        '2026-10-28T10:00:16Z Server replaced inside protected tunnel',
      ].join('\n'),
    );
    expect(
      report,
      contains(
        'NATIVE VPN EVENTS\n'
        '2026-10-28T10:00:01Z TUNNEL_START\n'
        '2026-10-28T10:00:02Z ON_DEMAND_ARMED\n'
        '2026-10-28T10:00:03Z TUNNEL_PREPARE_FAILED\n'
        '2026-10-28T10:00:04Z ROUTES_INSTALLED\n'
        '2026-10-28T10:00:05Z GEO_ASSETS_DEFAULT\n'
        '2026-10-28T10:00:06Z XRAY_STARTED\n'
        '2026-10-28T10:00:07Z HEV_START\n'
        '2026-10-28T10:00:08Z HEV_RUNNING\n'
        '2026-10-28T10:00:09Z WATCHDOG_PASSED\n'
        '2026-10-28T10:00:10Z FORWARDING_RESTORED\n'
        '2026-10-28T10:00:11Z TUNNEL_STOP\n'
        '2026-10-28T10:00:12Z XRAY_START_FAILED\n'
        '2026-10-28T10:00:13Z HEV_EXITED value=-1\n'
        '2026-10-28T10:00:14Z DPI_ENGINE_EXITED\n'
        '2026-10-28T10:00:15Z RESTART_FAILED\n'
        '2026-10-28T10:00:16Z SERVER_REPLACED',
      ),
    );
  });

  test('restart failures export per-stage codes with safe numeric values only', () {
    final report = diagnosticReport(
      state: 'connecting',
      events: const [],
      pingChecks: 0,
      sharing: false,
      reconnect: true,
      nativeDiagnostics: [
        '2026-10-28T11:00:00Z Native restart failed at DPI interface stage; protected traffic remains blocked',
        '2026-10-28T11:00:01Z Native restart failed at TUN descriptor stage; protected traffic remains blocked',
        '2026-10-28T11:00:02Z Native restart failed at DPI profile stage; protected traffic remains blocked',
        '2026-10-28T11:00:03Z Native restart failed at DPI connectivity stage; protected traffic remains blocked',
        '2026-10-28T11:00:04Z Native restart failed at Xray asset stage; protected traffic remains blocked',
        '2026-10-28T11:00:05Z Native restart failed at Xray startup stage; protected traffic remains blocked',
        '2026-10-28T11:00:06Z Native restart failed at HEV startup stage (code 3); protected traffic remains blocked',
        '2026-10-28T11:00:07Z Native restart failed at native stage (code -2); protected traffic remains blocked',
        '2026-10-28T11:00:08Z Native restart failed at native stage; protected traffic remains blocked',
      ].join('\n'),
    );
    expect(
      report,
      contains(
        'RESTART_DPI_INTERFACE\n'
        '2026-10-28T11:00:01Z RESTART_TUN_DESCRIPTOR\n'
        '2026-10-28T11:00:02Z RESTART_DPI_PROFILE\n'
        '2026-10-28T11:00:03Z RESTART_DPI_CONNECTIVITY\n'
        '2026-10-28T11:00:04Z RESTART_XRAY_ASSETS\n'
        '2026-10-28T11:00:05Z RESTART_XRAY_START\n'
        '2026-10-28T11:00:06Z RESTART_HEV_STARTUP value=3\n'
        '2026-10-28T11:00:07Z RESTART_NATIVE_STAGE value=-2\n'
        '2026-10-28T11:00:08Z RESTART_NATIVE_STAGE',
      ),
    );
  });

  test('Apple preparation failures export per-stage codes', () {
    final report = diagnosticReport(
      state: 'connecting',
      events: const [],
      pingChecks: 0,
      sharing: false,
      reconnect: true,
      nativeDiagnostics: [
        '2026-10-28T12:00:00Z Tunnel preparation failed at DNS resolver policy stage',
        '2026-10-28T12:00:01Z Tunnel preparation failed at endpoint resolution stage',
        '2026-10-28T12:00:02Z Tunnel preparation failed at proxy endpoint stage',
        '2026-10-28T12:00:03Z Tunnel preparation was cancelled before route installation',
        '2026-10-28T12:00:04Z Tunnel preparation failed before route installation',
      ].join('\n'),
    );
    expect(
      report,
      contains(
        'TUNNEL_PREPARE_DNS_RESOLVER\n'
        '2026-10-28T12:00:01Z TUNNEL_PREPARE_ENDPOINT_RESOLUTION\n'
        '2026-10-28T12:00:02Z TUNNEL_PREPARE_PROXY_ENDPOINT\n'
        '2026-10-28T12:00:03Z TUNNEL_PREPARE_CANCELLED\n'
        '2026-10-28T12:00:04Z TUNNEL_PREPARE_FAILED',
      ),
    );
  });

  test('Apple protected switch stages export fixed codes', () {
    final report = diagnosticReport(
      state: 'connected',
      events: const [],
      pingChecks: 0,
      sharing: false,
      reconnect: true,
      nativeDiagnostics: [
        '2026-10-28T13:00:00Z Protected server switch started',
        '2026-10-28T13:00:01Z Protected switch preparation succeeded',
        '2026-10-28T13:00:02Z Protected switch stopped old workers',
        '2026-10-28T13:00:03Z Protected switch routes reinstalled',
        '2026-10-28T13:00:04Z Server replaced inside protected tunnel',
        '2026-10-28T13:01:00Z Server switch rejected at endpoint resolution stage; existing tunnel protection retained',
        '2026-10-28T13:01:01Z Server switch rejected at worker stop stage; existing tunnel protection retained',
      ].join('\n'),
    );
    expect(
      report,
      contains(
        'SWITCH_STARTED\n'
        '2026-10-28T13:00:01Z SWITCH_PREPARED\n'
        '2026-10-28T13:00:02Z SWITCH_WORKERS_STOPPED\n'
        '2026-10-28T13:00:03Z SWITCH_ROUTES_REINSTALLED\n'
        '2026-10-28T13:00:04Z SERVER_REPLACED\n'
        '2026-10-28T13:01:00Z SWITCH_REJECTED_ENDPOINT_RESOLUTION\n'
        '2026-10-28T13:01:01Z SWITCH_REJECTED_WORKER_STOP',
      ),
    );
  });

  test(
    'Apple app-process store lines map without timestamps or redactions',
    () {
      final report = diagnosticReport(
        state: 'error',
        events: const [],
        pingChecks: 0,
        sharing: false,
        reconnect: false,
        nativeDiagnostics: [
          '--- iOS app-process Xray diagnostics ---',
          '[xray] Xray startup failed: start core',
          '[runtime] Proxy-only start failed: Native operation failed (code 1)',
        ].join('\n'),
      );
      expect(
        report,
        contains('NATIVE VPN EVENTS\nXRAY_START_FAILED\nPROXY_START_FAILED'),
      );
      expect(report, isNot(contains('app-process')));
    },
  );

  test(
    'Apple HEV log presence marker distinguishes empty from present logs',
    () {
      final empty = diagnosticReport(
        state: 'connecting',
        events: const [],
        pingChecks: 0,
        sharing: false,
        reconnect: false,
        nativeDiagnostics: 'HEV diagnostic file bytes=0; raw contents omitted',
      );
      final present = diagnosticReport(
        state: 'connecting',
        events: const [],
        pingChecks: 0,
        sharing: false,
        reconnect: false,
        nativeDiagnostics:
            'HEV diagnostic file bytes=2048; raw contents omitted',
      );
      expect(empty, contains('NATIVE VPN EVENTS\nHEV_LOG_EMPTY'));
      expect(present, contains('NATIVE VPN EVENTS\nHEV_LOG_PRESENT'));
    },
  );

  test('unrecognized Apple lines are counted and never exported verbatim', () {
    final report = diagnosticReport(
      state: 'connecting',
      events: const [],
      pingChecks: 0,
      sharing: false,
      reconnect: false,
      nativeDiagnostics: [
        '2026-10-28T10:00:01Z Starting Xray packet tunnel',
        '2026-10-28T10:00:02Z Failed to dial 203.0.113.7:443 token=private-token',
        'xray output: private-secret',
      ].join('\n'),
    );
    expect(report, contains('TUNNEL_START'));
    expect(report, contains('Unrecognized native lines omitted: 2.'));
    for (final secret in ['203.0.113.7', 'private-token', 'private-secret']) {
      expect(report, isNot(contains(secret)));
    }
  });

  test(
    'a non-empty Apple snapshot with no matching lines is reported distinctly',
    () {
      final report = diagnosticReport(
        state: 'connecting',
        events: const [],
        pingChecks: 0,
        sharing: false,
        reconnect: false,
        nativeDiagnostics: '2026-10-28T10:00:01Z Unknown native line',
      );
      expect(
        report,
        contains(
          'Native events were recorded but none matched the privacy filter.',
        ),
      );
      expect(report, isNot(contains('No native events recorded.')));
    },
  );

  test('a failed snapshot is distinct from an empty snapshot', () {
    final failed = diagnosticReport(
      state: 'connecting',
      events: const [],
      pingChecks: 0,
      sharing: false,
      reconnect: false,
      nativeSnapshotSucceeded: false,
    );
    final empty = diagnosticReport(
      state: 'connecting',
      events: const [],
      pingChecks: 0,
      sharing: false,
      reconnect: false,
    );
    expect(
      failed,
      contains('Native diagnostics snapshot could not be retrieved.'),
    );
    expect(failed, isNot(contains('No native events recorded.')));
    expect(empty, contains('NATIVE VPN EVENTS\nNo native events recorded.'));
  });

  test('Apple and Android native events coexist in one snapshot', () {
    final report = diagnosticReport(
      state: 'connecting',
      events: const [],
      pingChecks: 0,
      sharing: false,
      reconnect: false,
      nativeDiagnostics:
          '2026-10-28T10:00:01Z Starting Xray packet tunnel\nWORKER_EXIT value=-1\nTUN_ESTABLISHED',
    );
    expect(
      report,
      contains(
        'NATIVE VPN EVENTS\n'
        '2026-10-28T10:00:01Z TUNNEL_START\n'
        'WORKER_EXIT value=-1\n'
        'TUN_ESTABLISHED',
      ),
    );
  });

  test('diagnostics screen separates unavailable from empty snapshots', () {
    expect(
      nativeDiagnosticsDisplayText(const NativeSnapshotResult('', false)),
      contains('could not be retrieved'),
    );
    expect(
      nativeDiagnosticsDisplayText(const NativeSnapshotResult('', true)),
      'No native diagnostics have been recorded.',
    );
    expect(
      nativeDiagnosticsDisplayText(const NativeSnapshotResult('ok', true)),
      'ok',
    );
  });
}
