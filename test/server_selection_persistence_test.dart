import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:oculve/core/connection/server_selection_store.dart';
import 'package:oculve/core/providers/server_selection_persistence.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vpn_state_test.dart' show TestApi, TestPlatform;

// The tunnel outlives the app. A relaunch must show the location the user
// picked, not the default, next to a connection that is still up.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing saved starts on Optimal', () async {
    expect(await loadInitialServerSelection(), optimalServerId);
  });

  test('a picked location is remembered for the next launch', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    persistServerSelection(container);

    container.read(selectedServerProvider.notifier).state = 'copenhagen';
    await settle();

    expect(await ServerSelectionStore.readSelected(), 'copenhagen');
    expect(await loadInitialServerSelection(), 'copenhagen');

    container.read(selectedServerProvider.notifier).state = dpiBypassServerId;
    await settle();
    expect(await loadInitialServerSelection(), dpiBypassServerId);
  });

  test('the server Optimal resolved to is remembered, and cleared', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    persistServerSelection(container);

    container.read(optimalServerProfileProvider.notifier).state = 'frankfurt';
    await settle();
    expect(await ServerSelectionStore.readOptimal(), 'frankfurt');

    container.read(optimalServerProfileProvider.notifier).state = null;
    await settle();
    expect(await ServerSelectionStore.readOptimal(), isNull);
  });

  test('a relaunch with a live tunnel shows the remembered server', () async {
    SharedPreferences.setMockInitialValues({
      ServerSelectionStore.optimalKey: 'frankfurt',
    });
    final platform = TestPlatform()..tunnelStatus = 'CONNECTED';
    VlessPlatform.instance = platform;
    final container = ProviderContainer(
      overrides: [apiProvider.overrideWithValue(TestApi())],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.notifier).refresh();
    expect(container.read(selectedServerProvider), optimalServerId);
    expect(container.read(optimalServerProfileProvider), isNull);

    await container.read(vpnProvider.notifier).restoreTunnel();

    expect(container.read(optimalServerProfileProvider), 'frankfurt');
  });

  test(
    'a remembered Optimal choice is not applied to a picked location',
    () async {
      SharedPreferences.setMockInitialValues({
        ServerSelectionStore.optimalKey: 'frankfurt',
      });
      final platform = TestPlatform()..tunnelStatus = 'CONNECTED';
      VlessPlatform.instance = platform;
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(TestApi()),
          selectedServerProvider.overrideWith((ref) => 'copenhagen'),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionProvider.notifier).refresh();

      await container.read(vpnProvider.notifier).restoreTunnel();

      expect(container.read(selectedServerProvider), 'copenhagen');
      expect(container.read(optimalServerProfileProvider), isNull);
    },
  );
}
