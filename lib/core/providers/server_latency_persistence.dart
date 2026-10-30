import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connection/server_latency_store.dart';
import '../vpn/server_latency.dart';

/// Writes the measured pings to disk shortly after they change. Several servers
/// finish within moments of each other, so writes are combined. A failed write
/// is ignored: not remembering a ping must never break the list.
void persistServerLatencies(
  ProviderContainer container, {
  Duration debounce = const Duration(seconds: 2),
}) {
  Timer? pending;
  void schedule() {
    pending?.cancel();
    pending = Timer(debounce, () {
      ServerLatencyStore.write(
        container.read(serverLatencyLastKnownProvider),
        container.read(serverLatencyLastMeasuredAtProvider),
      ).catchError((Object _) {});
    });
  }

  container.listen<Map<String, int>>(
    serverLatencyLastKnownProvider,
    (previous, next) => schedule(),
  );
  container.listen<Map<String, DateTime>>(
    serverLatencyLastMeasuredAtProvider,
    (previous, next) => schedule(),
  );
}
