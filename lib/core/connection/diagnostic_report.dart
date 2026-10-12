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
  DateTime? now,
}) {
  final version =
      RegExp(
        r'^(?:Xray )?v?\d{1,4}\.\d{1,4}\.\d{1,4}(?:[-+][a-zA-Z0-9.]{1,20})?$',
      ).hasMatch(coreVersion)
      ? coreVersion
      : 'Unavailable';
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
      'CONNECTION EVENTS\n${safeEvents.isEmpty ? 'No events recorded.' : safeEvents.join('\n')}\n';
}
