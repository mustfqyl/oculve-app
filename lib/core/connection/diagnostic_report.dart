import 'dart:io';
import '../models/user_facing_failure.dart';

/// Export an allowlisted summary, never raw configuration or native logs.
/// Tokens, account codes, proxy credentials, destinations and client IPs cannot
/// enter the report because those source objects are never serialized.
String diagnosticReport({
  required String state,
  required Iterable<String> events,
  required int pingChecks,
  required bool sharing,
  required bool reconnect,
  String coreVersion = 'Unavailable',
  String nativeDiagnostics = '',
  DateTime? now,
}) {
  final exactVersion = RegExp(
    r'^(?:Xray )?v?\d{1,4}\.\d{1,4}\.\d{1,4}(?:[-+][a-zA-Z0-9.]{1,20})?$',
  );
  // Android's CLI returns a verbose banner. Export only its version token.
  final bannerVersion = RegExp(
    r'^Xray (\d{1,4}\.\d{1,4}\.\d{1,4})(?:\s|$)',
  ).firstMatch(coreVersion);
  final version = exactVersion.hasMatch(coreVersion)
      ? coreVersion
      : bannerVersion == null
      ? 'Unavailable'
      : 'Xray ${bannerVersion.group(1)}';
  const nativeEvents = {
    'SESSION_START',
    'SESSION_STOP',
    'CONFIG_REJECTED',
    'PROFILE_UNAVAILABLE',
    'PROFILE_SAVE_FAILED',
    'WORKERS_START',
    'WORKERS_STOP',
    'WORKER_EXIT',
    'WORKER_START_FAILED',
    'PROTECT_FAILED',
    'TUN_ESTABLISHED',
    'TUN_RETAINED',
    'TUN_FAILED',
    'FD_SENT',
    'FD_FAILED',
    'AUTH_PROBE_FAILED',
    'PATH_PROBE_FAILED',
    'CONNECTED',
    'RECOVERING',
    'XRAY_DEBUG',
    'XRAY_INFO',
    'XRAY_WARNING',
    'XRAY_ERROR',
    'OUTPUT_DISCARDED',
    'IO_FAILED',
    'NATIVE_VALIDATION_FAILED',
    'ENDPOINT_RESOLUTION_FAILED',
  };
  final eventPattern = RegExp(
    '^(?:${nativeEvents.join('|')})(?: value=-?[0-9]{1,6})?\$',
  );
  final safeNative = nativeDiagnostics
      .split('\n')
      .where(eventPattern.hasMatch)
      .take(300)
      .join('\n');
  const states = {
    'connected',
    'connecting',
    'disconnecting',
    'disconnected',
    'error',
    'error dismissed',
  };
  final safeEvents = <String>[];
  for (final event in events.take(100)) {
    final split = event.indexOf(' ');
    if (split < 0) continue;
    final time = DateTime.tryParse(event.substring(0, split));
    if (time == null) continue;
    final message = event.substring(split + 1);
    final safe =
        states.contains(message) ||
            RegExp(r'^automatic reconnect attempt [1-5]$').hasMatch(message)
        ? message
        : UserFacingFailure.message(
            message,
            fallback: 'Event details omitted.',
          );
    safeEvents.add('${time.toUtc().toIso8601String()} $safe');
  }
  return 'OCULVE TROUBLESHOOTING REPORT\n'
      'Generated: ${(now ?? DateTime.now()).toUtc().toIso8601String()}\n'
      'Platform: ${Platform.operatingSystem}\n'
      'Xray: $version\n'
      'VPN state: ${states.contains(state) ? state : 'unknown'}\n'
      'Automatic reconnect: $reconnect\nLAN sharing configured: $sharing\n'
      'Ping checks recorded: $pingChecks\n\n'
      'Account codes, credentials, configuration, IP addresses and browsing destinations are excluded.\n\n'
      'CONNECTION EVENTS\n${safeEvents.isEmpty ? 'No events recorded.' : safeEvents.join('\n')}\n\n'
      'NATIVE VPN EVENTS\n${safeNative.isEmpty ? 'No native events recorded.' : safeNative}\n';
}
