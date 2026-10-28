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
  bool nativeSnapshotSucceeded = true,
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
  // Apple native diagnostics reach this report as timestamped tunnel provider
  // lines ("<ISO8601> <message>") or app-process store lines ("[x] <message>").
  // Both are mapped onto one fixed code vocabulary. Raw native text never
  // crosses this boundary: anything unmapped is counted and omitted verbatim.
  const appleRuntimeEvents = {
    'Xray startup failed: privacy configuration': 'XRAY_START_FAILED',
    'Xray startup failed: decode configuration': 'XRAY_START_FAILED',
    'Xray startup failed: build configuration': 'XRAY_START_FAILED',
    'Xray startup failed: create core': 'XRAY_START_FAILED',
    'Xray startup failed: start core': 'XRAY_START_FAILED',
    'Xray configuration error': 'XRAY_CONFIG_ERROR',
    'Xray configuration warning': 'XRAY_CONFIG_WARNING',
    'Xray configuration info': 'XRAY_CONFIG_INFO',
    'Xray configuration debug': 'XRAY_CONFIG_DEBUG',
    'Xray runtime error': 'XRAY_RUNTIME_ERROR',
    'Xray runtime warning': 'XRAY_RUNTIME_WARNING',
    'Xray runtime info': 'XRAY_RUNTIME_INFO',
    'Xray runtime debug': 'XRAY_RUNTIME_DEBUG',
    'Xray diagnostic details omitted': 'XRAY_DIAGNOSTIC_OMITTED',
  };
  const appleTunnelEvents = {
    'Starting Xray packet tunnel': 'TUNNEL_START',
    'On-demand recovery armed for tunnel session': 'ON_DEMAND_ARMED',
    'Unable to arm on-demand recovery for tunnel session':
        'ON_DEMAND_ARM_FAILED',
    'Tunnel preparation failed before route installation':
        'TUNNEL_PREPARE_FAILED',
    'Tunnel preparation failed at configuration parse stage':
        'TUNNEL_PREPARE_CONFIG_PARSE',
    'Tunnel preparation failed at access policy stage':
        'TUNNEL_PREPARE_ACCESS_POLICY',
    'Tunnel preparation failed at privacy policy stage':
        'TUNNEL_PREPARE_PRIVACY_POLICY',
    'Tunnel preparation failed at DNS resolver policy stage':
        'TUNNEL_PREPARE_DNS_RESOLVER',
    'Tunnel preparation failed at proxy endpoint stage':
        'TUNNEL_PREPARE_PROXY_ENDPOINT',
    'Tunnel preparation failed at tag collision stage':
        'TUNNEL_PREPARE_TAG_COLLISION',
    'Tunnel preparation failed at address-port strategy stage':
        'TUNNEL_PREPARE_ADDRESS_PORT_STRATEGY',
    'Tunnel preparation failed at endpoint resolution stage':
        'TUNNEL_PREPARE_ENDPOINT_RESOLUTION',
    'Tunnel preparation failed at IPv6 policy stage':
        'TUNNEL_PREPARE_IPV6_POLICY',
    'Tunnel preparation failed at configuration encoding stage':
        'TUNNEL_PREPARE_CONFIG_ENCODING',
    'Tunnel preparation was cancelled before route installation':
        'TUNNEL_PREPARE_CANCELLED',
    'Protected tunnel routes and virtual DNS installed': 'ROUTES_INSTALLED',
    'System stop preserves on-demand recovery': 'SYSTEM_STOP_ON_DEMAND',
    'User stop: on-demand recovery disabled': 'USER_STOP',
    'User stop: unable to disable on-demand recovery; use Disconnect in the app':
        'USER_STOP_ON_DEMAND_FAILED',
    'Automatic DPI strategy passed authenticated HTTPS connectivity':
        'DPI_CONNECTIVITY_PASSED',
    'Xray TUN and DPI runtime passed authenticated HTTPS connectivity':
        'DPI_CONNECTIVITY_PASSED',
    'Native shutdown pending; protected traffic remains blocked':
        'SHUTDOWN_PENDING',
    'Native restart failed; protected traffic remains blocked':
        'RESTART_FAILED',
    'Native restart failed at DPI interface stage; protected traffic remains blocked':
        'RESTART_DPI_INTERFACE',
    'Native restart failed at TUN descriptor stage; protected traffic remains blocked':
        'RESTART_TUN_DESCRIPTOR',
    'Native restart failed at DPI profile stage; protected traffic remains blocked':
        'RESTART_DPI_PROFILE',
    'Native restart failed at DPI connectivity stage; protected traffic remains blocked':
        'RESTART_DPI_CONNECTIVITY',
    'Native restart failed at Xray asset stage; protected traffic remains blocked':
        'RESTART_XRAY_ASSETS',
    'Native restart failed at Xray startup stage; protected traffic remains blocked':
        'RESTART_XRAY_START',
    'Native restart failed at Xray stage; protected traffic remains blocked':
        'RESTART_XRAY_STAGE',
    'Native restart failed at native stage; protected traffic remains blocked':
        'RESTART_NATIVE_STAGE',
    'Server replaced inside protected tunnel': 'SERVER_REPLACED',
    'Server switch rejected; existing tunnel protection retained':
        'SERVER_SWITCH_REJECTED',
    'Server switch rejected at metadata stage; existing tunnel protection retained':
        'SWITCH_REJECTED_METADATA',
    'Server switch rejected at tunnel state stage; existing tunnel protection retained':
        'SWITCH_REJECTED_TUNNEL_STATE',
    'Server switch rejected at route exclusion stage; existing tunnel protection retained':
        'SWITCH_REJECTED_ROUTE_EXCLUSION',
    'Server switch rejected at preparation stage; existing tunnel protection retained':
        'SWITCH_REJECTED_PREPARATION',
    'Server switch rejected at worker stop stage; existing tunnel protection retained':
        'SWITCH_REJECTED_WORKER_STOP',
    'Server switch rejected at configuration parse stage; existing tunnel protection retained':
        'SWITCH_REJECTED_CONFIG_PARSE',
    'Server switch rejected at access policy stage; existing tunnel protection retained':
        'SWITCH_REJECTED_ACCESS_POLICY',
    'Server switch rejected at privacy policy stage; existing tunnel protection retained':
        'SWITCH_REJECTED_PRIVACY_POLICY',
    'Server switch rejected at DNS resolver policy stage; existing tunnel protection retained':
        'SWITCH_REJECTED_DNS_RESOLVER',
    'Server switch rejected at proxy endpoint stage; existing tunnel protection retained':
        'SWITCH_REJECTED_PROXY_ENDPOINT',
    'Server switch rejected at tag collision stage; existing tunnel protection retained':
        'SWITCH_REJECTED_TAG_COLLISION',
    'Server switch rejected at address-port strategy stage; existing tunnel protection retained':
        'SWITCH_REJECTED_ADDRESS_PORT_STRATEGY',
    'Server switch rejected at endpoint resolution stage; existing tunnel protection retained':
        'SWITCH_REJECTED_ENDPOINT_RESOLUTION',
    'Server switch rejected at IPv6 policy stage; existing tunnel protection retained':
        'SWITCH_REJECTED_IPV6_POLICY',
    'Server switch rejected at configuration encoding stage; existing tunnel protection retained':
        'SWITCH_REJECTED_CONFIG_ENCODING',
    'Server switch cancelled; existing tunnel protection retained':
        'SWITCH_CANCELLED',
    'Protected server switch started': 'SWITCH_STARTED',
    'Protected switch preparation succeeded': 'SWITCH_PREPARED',
    'Protected switch stopped old workers': 'SWITCH_WORKERS_STOPPED',
    'Protected switch route installation failed': 'SWITCH_ROUTE_INSTALL_FAILED',
    'Protected switch routes reinstalled': 'SWITCH_ROUTES_REINSTALLED',
    'Packet tunnel sleep; suspending watchdog': 'TUNNEL_SLEEP',
    'Packet tunnel wake; scheduling health check': 'TUNNEL_WAKE',
    'HEV remained running through startup grace period': 'HEV_RUNNING',
    'Xray asset configuration failed': 'XRAY_ASSET_FAILED',
    'Using Xray default geo asset lookup': 'GEO_ASSETS_DEFAULT',
    'XRay started successfully': 'XRAY_STARTED',
    'Failed to start XRay with unknown error': 'XRAY_START_FAILED',
    'Managed DPI engine exited; restarting inside the protected tunnel':
        'DPI_ENGINE_EXITED',
    'HEV packet bridge exited; restarting inside the protected tunnel':
        'HEV_BRIDGE_EXITED',
    'Protected tunnel forwarding restored': 'FORWARDING_RESTORED',
    'Protected tunnel waiting for transport recovery':
        'TRANSPORT_RECOVERY_WAIT',
    'Restarting native workers inside the protected tunnel': 'NATIVE_RESTART',
    'Physical interface changed; restarting automatic DPI selection':
        'DPI_INTERFACE_CHANGED',
    'Network path changed; revalidating automatic DPI selection':
        'DPI_INTERFACE_CHANGED',
    'Resolving VPN transport endpoint': 'ENDPOINT_RESOLVE',
    'System endpoint DNS unavailable; trying encrypted endpoint bootstrap':
        'ENDPOINT_DNS_UNAVAILABLE',
    'Encrypted endpoint bootstrap completed': 'ENDPOINT_BOOTSTRAP_OK',
    'Encrypted endpoint bootstrap unavailable':
        'ENDPOINT_BOOTSTRAP_UNAVAILABLE',
    'Packet flow bridge failed; restarting protected native workers':
        'PACKET_BRIDGE_FAILED',
    'Public packetFlow bridge ready for HEV': 'PACKET_BRIDGE_READY',
    'Xray TUN descriptor configuration failed': 'TUN_DESCRIPTOR_FAILED',
    'Unable to clear Xray TUN descriptor after shutdown':
        'TUN_DESCRIPTOR_CLEAR_FAILED',
  };
  final appleTimestamp = RegExp(
    r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z) (.+)$',
  );
  final appleStoreLine = RegExp(r'^\[([a-z]{2,12})\] (.+)$');
  // Native interpolation renders non-scalar values as "<redacted>"; only
  // these closed, numeric-free parameter shapes below are pattern-matched.
  final applePatterns = <RegExp, String>{
    RegExp(r'^Stopping Xray packet tunnel, reason=<redacted>$'): 'TUNNEL_STOP',
    RegExp(
      r'^Starting HEV socks5 tunnel on 127\.0\.0\.1:\d{1,5}, log=<redacted>$',
    ): 'HEV_START',
    RegExp(r'^HEV socks5 tunnel exited with code (-?[0-9]{1,6})$'):
        'HEV_EXITED',
    RegExp(r'^Using Xray geo assets from <redacted>$'): 'GEO_ASSETS_CUSTOM',
    RegExp(r'^Failed to start XRay: <redacted>$'): 'XRAY_START_FAILED',
    RegExp(r'^Network path changed status=<redacted>$'): 'PATH_CHANGED',
    RegExp(
      r'^Native restart failed at HEV startup stage \(code (-?[0-9]{1,6})\); protected traffic remains blocked$',
    ): 'RESTART_HEV_STARTUP',
    RegExp(
      r'^Native restart failed at native stage \(code (-?[0-9]{1,6})\); protected traffic remains blocked$',
    ): 'RESTART_NATIVE_STAGE',
    RegExp(
      r'^Watchdog <redacted>: success=(true|false) inbound=\[<redacted>\] connect=\[<redacted>\] http=\[<redacted>\]$',
    ): 'WATCHDOG',
    RegExp(r'^Proxy-only start failed: <redacted>$'): 'PROXY_START_FAILED',
    RegExp(r'^Proxy-only start failed: .+$'): 'PROXY_START_FAILED',
  };
  final appleIgnored = <RegExp>{
    // Periodic health counters, not failure phases; numbers stay unexported.
    RegExp(
      r'^Traffic <redacted>: upPackets=\d+ upBytes=\d+ downPackets=\d+ downBytes=\d+$',
    ),
    RegExp(
      r'^Packet bridge: upPackets=\d+ downPackets=\d+ backpressureWaits=\d+ queuedBytes=\d+ peakQueuedBytes=\d+ receiveBufferBytes=\d+$',
    ),
  };
  final appleHeaders = {
    '--- iOS app-process Xray diagnostics ---',
    '--- macOS app-process Xray diagnostics ---',
  };
  final hevFileLine = RegExp(
    r'^HEV diagnostic file bytes=(\d{1,12}); raw contents omitted$',
  );
  final safeNative = <String>[];
  var snapshotLines = 0;
  var unrecognized = 0;
  for (final rawLine in nativeDiagnostics.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    snapshotLines++;
    if (appleHeaders.contains(line)) continue;
    if (eventPattern.hasMatch(line)) {
      if (safeNative.length < 300) safeNative.add(line);
      continue;
    }
    final hevFile = hevFileLine.firstMatch(line);
    if (hevFile != null) {
      final present = int.tryParse(hevFile.group(1)!);
      if (safeNative.length < 300) {
        safeNative.add(
          present != null && present > 0 ? 'HEV_LOG_PRESENT' : 'HEV_LOG_EMPTY',
        );
      }
      continue;
    }
    if (appleIgnored.any((pattern) => pattern.hasMatch(line))) continue;
    var message = line;
    var timestamp = '';
    final stamp = appleTimestamp.firstMatch(line);
    if (stamp != null) {
      timestamp = stamp.group(1)!;
      message = stamp.group(2)!;
    } else {
      final store = appleStoreLine.firstMatch(line);
      if (store != null) message = store.group(2)!;
    }
    var code = appleRuntimeEvents[message] ?? appleTunnelEvents[message];
    String? value;
    if (code == null) {
      for (final pattern in applePatterns.entries) {
        final match = pattern.key.firstMatch(message);
        if (match == null) continue;
        code = pattern.value;
        if (code == 'HEV_EXITED' ||
            code == 'RESTART_HEV_STARTUP' ||
            code == 'RESTART_NATIVE_STAGE') {
          value = match.group(1);
        }
        if (code == 'WATCHDOG') {
          code = match.group(1) == 'true'
              ? 'WATCHDOG_PASSED'
              : 'WATCHDOG_FAILED';
        }
        break;
      }
    }
    if (code == null) {
      unrecognized++;
      continue;
    }
    if (safeNative.length < 300) {
      safeNative.add(
        '${timestamp.isEmpty ? '' : '$timestamp '}$code'
        '${value == null ? '' : ' value=$value'}',
      );
    }
  }
  String nativeSection;
  if (!nativeSnapshotSucceeded) {
    nativeSection = 'Native diagnostics snapshot could not be retrieved.';
  } else if (snapshotLines == 0) {
    nativeSection = 'No native events recorded.';
  } else if (safeNative.isEmpty) {
    nativeSection =
        'Native events were recorded but none matched the privacy filter.';
  } else {
    nativeSection = safeNative.join('\n');
  }
  if (nativeSnapshotSucceeded && snapshotLines > 0 && unrecognized > 0) {
    nativeSection += '\nUnrecognized native lines omitted: $unrecognized.';
  }
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
      'NATIVE VPN EVENTS\n$nativeSection\n';
}
