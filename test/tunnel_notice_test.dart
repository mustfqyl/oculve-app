import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/features/auth/presentation/widgets/tunnel_active_notice.dart';

// Signing out never stops the tunnel, so the sign-in screens must still show
// that it is on and offer the only action available without a session.

class _NoticeVpn extends VpnNotifier {
  _NoticeVpn(super.ref, VpnState initial) {
    state = initial;
  }

  int disconnects = 0;

  @override
  Future<void> disconnect() async {
    disconnects++;
  }
}

void main() {
  Future<_NoticeVpn> pump(WidgetTester tester, VpnState state) async {
    late _NoticeVpn vpn;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vpnProvider.overrideWith((ref) => vpn = _NoticeVpn(ref, state)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: TunnelActiveNotice())),
        ),
      ),
    );
    return vpn;
  }

  testWidgets('a live tunnel without a session is shown and can be stopped', (
    tester,
  ) async {
    final vpn = await pump(tester, VpnState.connected);

    expect(find.text('VPN is on'), findsOneWidget);
    await tester.tap(find.text('Turn off'));
    await tester.pump();

    expect(vpn.disconnects, 1);
  });

  testWidgets('a connecting tunnel is shown too', (tester) async {
    await pump(tester, VpnState.connecting);

    expect(find.text('VPN is on'), findsOneWidget);
  });

  testWidgets('nothing is shown while the tunnel is down', (tester) async {
    await pump(tester, VpnState.disconnected);

    expect(find.text('VPN is on'), findsNothing);
    expect(find.text('Turn off'), findsNothing);
  });
}
