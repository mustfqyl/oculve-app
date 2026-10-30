import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The last measured ping of every server, kept across launches.
///
/// A tunnel outlives the app, and pings cannot be measured while it is up
/// (a direct probe could be routed through it). Without this, reopening the
/// app on a live connection shows every location with an empty ping.
class ServerLatencyStore {
  ServerLatencyStore._();

  static const key = 'server.latency.v1';

  /// Older entries are dropped: a ping that old says nothing about today.
  static const maxAge = Duration(days: 14);

  static Future<({Map<String, int> latency, Map<String, DateTime> measuredAt})>
  read({DateTime? now}) async {
    final latency = <String, int>{};
    final measuredAt = <String, DateTime>{};
    try {
      final preferences = await SharedPreferences.getInstance();
      final decoded = jsonDecode(preferences.getString(key) ?? '{}');
      if (decoded is Map) {
        final cutoff = (now ?? DateTime.now()).subtract(maxAge);
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (entry.key is! String || value is! Map) continue;
          final ms = value['ms'];
          final at = DateTime.tryParse('${value['at']}');
          if (ms is! int || ms <= 0 || at == null || at.isBefore(cutoff)) {
            continue;
          }
          latency[entry.key as String] = ms;
          measuredAt[entry.key as String] = at;
        }
      }
    } catch (_) {
      // Unreadable data just means starting without remembered pings.
    }
    return (latency: latency, measuredAt: measuredAt);
  }

  static Future<void> write(
    Map<String, int> latency,
    Map<String, DateTime> measuredAt,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = {
      for (final entry in latency.entries)
        if (entry.value > 0 && measuredAt[entry.key] != null)
          entry.key: {
            'ms': entry.value,
            'at': measuredAt[entry.key]!.toUtc().toIso8601String(),
          },
    };
    await preferences.setString(key, jsonEncode(encoded));
  }
}
