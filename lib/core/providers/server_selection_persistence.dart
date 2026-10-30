import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connection/server_selection_store.dart';
import 'vpn_provider.dart';

/// The location to start with: the one the user picked last time.
Future<String> loadInitialServerSelection() async =>
    await ServerSelectionStore.readSelected() ?? optimalServerId;

/// Writes every later change of the selection to disk. Failures are ignored on
/// purpose: not remembering a location must never break connecting.
void persistServerSelection(ProviderContainer container) {
  container.listen<String?>(selectedServerProvider, (previous, next) {
    if (previous != next) {
      ServerSelectionStore.saveSelected(next).catchError((Object _) {});
    }
  });
  container.listen<String?>(optimalServerProfileProvider, (previous, next) {
    if (previous != next) {
      ServerSelectionStore.saveOptimal(next).catchError((Object _) {});
    }
  });
}
