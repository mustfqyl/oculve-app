import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/connection/server_latency_store.dart';
import 'package:oculve/core/providers/server_latency_persistence.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Pings cannot be measured while a tunnel is up, and the tunnel outlives the
// app. Reopening the app on a live connection must still show the last pings.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  final now = DateTime.utc(2026, 10, 31, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing saved means no remembered pings', () async {
    final read = await ServerLatencyStore.read(now: now);
    expect(read.latency, isEmpty);
    expect(read.measuredAt, isEmpty);
  });

  test('pings round-trip with the time they were measured', () async {
    await ServerLatencyStore.write(
      {'istanbul': 38, 'frankfurt': 71},
      {'istanbul': now, 'frankfurt': now.subtract(const Duration(hours: 3))},
    );
    final read = await ServerLatencyStore.read(now: now);
    expect(read.latency, {'istanbul': 38, 'frankfurt': 71});
    expect(read.measuredAt['istanbul'], now);
    expect(
      read.measuredAt['frankfurt'],
      now.subtract(const Duration(hours: 3)),
    );
  });

  test('stale, non-positive and unreadable entries are dropped', () async {
    await ServerLatencyStore.write(
      {'fresh': 40, 'ancient': 50, 'zero': 0, 'untimed': 60},
      {
        'fresh': now.subtract(const Duration(days: 2)),
        'ancient': now.subtract(const Duration(days: 30)),
        'zero': now,
      },
    );
    final read = await ServerLatencyStore.read(now: now);
    expect(read.latency.keys, ['fresh']);

    SharedPreferences.setMockInitialValues({ServerLatencyStore.key: '{bad'});
    expect((await ServerLatencyStore.read(now: now)).latency, isEmpty);
    SharedPreferences.setMockInitialValues({ServerLatencyStore.key: '[1,2]'});
    expect((await ServerLatencyStore.read(now: now)).latency, isEmpty);
    SharedPreferences.setMockInitialValues({
      ServerLatencyStore.key: '{"a":{"ms":"x","at":"nope"},"b":5}',
    });
    expect((await ServerLatencyStore.read(now: now)).latency, isEmpty);
  });

  test(
    'new measurements are written to disk, combined into one write',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      persistServerLatencies(
        container,
        debounce: const Duration(milliseconds: 10),
      );

      container.read(serverLatencyLastKnownProvider.notifier).state = {
        'istanbul': 38,
      };
      container.read(serverLatencyLastMeasuredAtProvider.notifier).state = {
        'istanbul': DateTime.now(),
      };
      container.read(serverLatencyLastKnownProvider.notifier).state = {
        'istanbul': 38,
        'frankfurt': 71,
      };
      container.read(serverLatencyLastMeasuredAtProvider.notifier).state = {
        'istanbul': DateTime.now(),
        'frankfurt': DateTime.now(),
      };
      await settle();

      final read = await ServerLatencyStore.read();
      expect(read.latency, {'istanbul': 38, 'frankfurt': 71});
    },
  );

  test('a relaunch on a live tunnel still shows the remembered ping', () async {
    await ServerLatencyStore.write(
      {'istanbul': 38},
      {'istanbul': DateTime.now().subtract(const Duration(hours: 1))},
    );
    final remembered = await ServerLatencyStore.read();
    final container = ProviderContainer(
      overrides: [
        serverLatencyLastKnownProvider.overrideWith(
          (ref) => remembered.latency,
        ),
        serverLatencyLastMeasuredAtProvider.overrideWith(
          (ref) => remembered.measuredAt,
        ),
      ],
    );
    addTearDown(container.dispose);
    // The app was reopened while the tunnel is up: no new probe may run.
    container.read(vpnTunnelMayBeActiveProvider.notifier).state = true;

    expect(await container.read(serverLatencyProvider('istanbul').future), 38);
    expect(container.read(serverLatencyLastKnownProvider)['istanbul'], 38);
  });
}
