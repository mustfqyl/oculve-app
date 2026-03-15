import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VpnProtocol {
  wireguard('WireGuard'),
  vless('VLESS'),
  byedpi('ByeDPI');

  final String displayName;
  const VpnProtocol(this.displayName);
}

// 0: Speed (WireGuard), 1: Privacy (VLESS), 2: Bypass (ByeDPI)
final protocolProvider = StateProvider<VpnProtocol>(
  (ref) => VpnProtocol.wireguard,
);
