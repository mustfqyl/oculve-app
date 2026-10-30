import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/home/presentation/widgets/connect_button.dart';

class _FakeVpn extends VpnNotifier {
  _FakeVpn(super.ref);

  void emit(VpnState next) => state = next;
}

void main() {
  late _FakeVpn vpn;

  Widget host({bool reduceMotion = false, bool tickerEnabled = true}) {
    return ProviderScope(
      overrides: [vpnProvider.overrideWith((ref) => vpn = _FakeVpn(ref))],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            disableAnimations: reduceMotion,
          ),
          child: TickerMode(
            enabled: tickerEnabled,
            child: const Scaffold(body: Center(child: ConnectButton())),
          ),
        ),
      ),
    );
  }

  test('idle flame is gated to the disconnected state', () {
    expect(
      flameFlickerEnabled(VpnState.disconnected, reduceMotion: false),
      isTrue,
    );
    for (final state in [
      VpnState.connecting,
      VpnState.connected,
      VpnState.disconnecting,
      VpnState.error,
    ]) {
      expect(flameFlickerEnabled(state, reduceMotion: false), isFalse);
    }
    expect(
      flameFlickerEnabled(VpnState.disconnected, reduceMotion: true),
      isFalse,
    );
  });

  testWidgets('reduce motion stops the flame', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a covered screen stops the flame', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(host(tickerEnabled: false));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('state changes keep the control stable', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));

    for (final state in [
      VpnState.connecting,
      VpnState.connected,
      VpnState.disconnecting,
      VpnState.error,
      VpnState.disconnected,
    ]) {
      vpn.emit(state);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
    expect(find.byKey(const ValueKey('vpn-connect-control')), findsOneWidget);
  });
}
