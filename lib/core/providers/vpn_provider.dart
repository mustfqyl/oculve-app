import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:singbox_native/singbox_native.dart';
import 'dart:io';
import 'package:mobile_flutter/core/models/vpn_state.dart';

class VpnNotifier extends StateNotifier<VpnState> {
  final SingboxNative _singbox;

  VpnNotifier(this._singbox) : super(VpnState.disconnected);

  Future<void> initialize() async {
    // Check if setup is needed
    // In a real app, check version/checksum
    try {
      String assetName = 'sing-box-android-arm64';
      if (Platform.isIOS) assetName = 'sing-box-ios';
      if (Platform.isMacOS) assetName = 'sing-box-macos';
      if (Platform.isWindows) assetName = 'sing-box-windows.exe';

      await _singbox.setup(assetName);
    } catch (e) {
      state = VpnState.error;
    }
  }

  Future<void> connect() async {
    try {
      state = VpnState.connecting;

      // TODO: Generate or fetch real config
      const config =
          '{"log": {"level": "info"}, "inbounds": [], "outbounds": []}';

      await _singbox.start(config);
      state = VpnState.connected;
    } catch (e) {
      state = VpnState.error;
    }
  }

  Future<void> disconnect() async {
    try {
      state = VpnState.disconnecting;
      await _singbox.stop();
      state = VpnState.disconnected;
    } catch (e) {
      state = VpnState.error;
    }
  }

  Future<void> toggle() async {
    final currentState = state;
    if (currentState == VpnState.connected ||
        currentState == VpnState.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }
}

final singboxNativeProvider = Provider((ref) => SingboxNative());

final vpnProvider = StateNotifierProvider<VpnNotifier, VpnState>((ref) {
  return VpnNotifier(ref.watch(singboxNativeProvider));
});
