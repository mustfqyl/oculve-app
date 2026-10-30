import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';

/// Measures the delay of the live connection: a request that goes through the
/// tunnel to the Internet and back. This is what the user actually feels, and
/// unlike the list's TCP connect time it can be measured while the tunnel is up.
abstract class ConnectedLatencyProbe {
  /// Median delay in milliseconds, or null when the path did not answer.
  Future<int?> measure();
}

class HttpConnectedLatencyProbe implements ConnectedLatencyProbe {
  const HttpConnectedLatencyProbe({
    this.url = 'https://www.gstatic.com/generate_204',
    this.timeout = const Duration(seconds: 4),
    this.samples = 3,
  });

  final String url;
  final Duration timeout;
  final int samples;

  @override
  Future<int?> measure() async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout * 2;
    try {
      // The first request pays for DNS, TCP and TLS and keeps the connection
      // open. Only the following ones are timed, on that same connection, so
      // each sample is one round trip through the whole path.
      if (!await _request(client)) return null;
      final times = <int>[];
      for (var index = 0; index < samples; index++) {
        final timer = Stopwatch()..start();
        if (await _request(client)) times.add(timer.elapsedMilliseconds);
      }
      if (times.isEmpty) return null;
      times.sort();
      return times[times.length ~/ 2];
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _request(HttpClient client) async {
    final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
    final response = await request.close().timeout(timeout);
    await response.drain<void>().timeout(timeout);
    return response.statusCode == 204;
  }
}

final connectedLatencyProbeProvider = Provider<ConnectedLatencyProbe>(
  (ref) => const HttpConnectedLatencyProbe(),
);

/// The live delay of the current connection, or null when there is no
/// connection or it has not been measured yet. Measured only while something
/// is watching it (the home card or the location list), a few seconds after
/// connecting and then every [interval].
class ConnectedLatencyNotifier extends StateNotifier<int?> {
  ConnectedLatencyNotifier(
    this._ref,
    this._probe, {
    this.firstDelay = const Duration(seconds: 3),
    this.interval = const Duration(seconds: 30),
  }) : super(null) {
    _ref.listen<VpnState>(
      vpnProvider,
      (previous, next) => _onState(next),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  final ConnectedLatencyProbe _probe;
  final Duration firstDelay;
  final Duration interval;
  Timer? _timer;
  bool _measuring = false;
  // Bumped whenever the connection changes, so a slow measurement that started
  // on an earlier connection can never publish its result for a later one.
  int _generation = 0;

  void _onState(VpnState next) {
    if (next == VpnState.connected) {
      if (_timer != null) return;
      final generation = _generation;
      _timer = Timer(firstDelay, () => _tick(generation));
      return;
    }
    _generation++;
    _timer?.cancel();
    _timer = null;
    if (state != null) state = null;
  }

  Future<void> _tick(int generation) async {
    if (!mounted || generation != _generation) return;
    if (!_measuring) {
      _measuring = true;
      try {
        final measured = await _probe.measure();
        if (mounted && generation == _generation && measured != null) {
          state = measured;
        }
      } finally {
        _measuring = false;
      }
    }
    if (mounted && generation == _generation) {
      _timer = Timer(interval, () => _tick(generation));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final connectedLatencyProvider =
    StateNotifierProvider.autoDispose<ConnectedLatencyNotifier, int?>(
      (ref) => ConnectedLatencyNotifier(
        ref,
        ref.watch(connectedLatencyProbeProvider),
      ),
    );
