import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/features/home/presentation/widgets/connect_button.dart';

class _FakeVpn extends VpnNotifier {
  _FakeVpn(super.ref);
  void emit(VpnState next) => state = next;
}

/// The shake moves the label block sideways on purpose; nothing may move
/// vertically or change size.
void expectSameBox(Rect actual, Rect expected) {
  expect(actual.top, expected.top);
  expect(actual.height, expected.height);
  expect(actual.width, expected.width);
}

void main() {
  late _FakeVpn vpn;
  late ProviderContainer container;

  Widget host({bool reduceMotion = false}) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          disableAnimations: reduceMotion,
        ),
        child: const Scaffold(
          body: Column(
            children: [
              Text('above', key: ValueKey('above')),
              Expanded(child: Center(child: ConnectButton())),
              Text('below', key: ValueKey('below')),
            ],
          ),
        ),
      ),
    ),
  );

  setUp(() {
    container = ProviderContainer(
      overrides: [vpnProvider.overrideWith((ref) => vpn = _FakeVpn(ref))],
    );
    addTearDown(container.dispose);
  });

  const hintSlot = ValueKey('vpn-connect-hint-slot');

  testWidgets('a failure appears in the button without moving anything', (
    tester,
  ) async {
    expect(kInlineFeedback, isTrue);
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));
    final slotBefore = tester.getRect(find.byKey(hintSlot));
    final aboveBefore = tester.getRect(find.byKey(const ValueKey('above')));
    final belowBefore = tester.getRect(find.byKey(const ValueKey('below')));
    final controlBefore = tester.getRect(
      find.byKey(const ValueKey('vpn-connect-control')),
    );

    container.read(vpnErrorProvider.notifier).state =
        'Could not resolve the VPN server. Check your internet connection and try again.';
    vpn.emit(VpnState.error);
    await tester.pump();
    // Mid-shake and mid-fade: still no layout movement.
    await tester.pump(const Duration(milliseconds: 120));
    expectSameBox(tester.getRect(find.byKey(hintSlot)), slotBefore);
    expect(tester.getRect(find.byKey(const ValueKey('above'))), aboveBefore);
    expect(tester.getRect(find.byKey(const ValueKey('below'))), belowBefore);
    expectSameBox(
      tester.getRect(find.byKey(const ValueKey('vpn-connect-control'))),
      controlBefore,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.textContaining('Could not resolve the VPN server'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expectSameBox(tester.getRect(find.byKey(hintSlot)), slotBefore);
  });

  testWidgets('the message fades out instead of vanishing', (tester) async {
    await tester.pumpWidget(host());
    container.read(vpnErrorProvider.notifier).state =
        'Could not resolve the VPN server. Check your internet connection and try again.';
    vpn.emit(VpnState.error);
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.textContaining('Could not resolve the VPN server'),
      findsOneWidget,
    );

    container.read(vpnErrorProvider.notifier).state = null;
    vpn.emit(VpnState.disconnected);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Halfway through the cross-fade both are still on screen, partly faded.
    final fading = tester.widgetList<FadeTransition>(
      find.descendant(
        of: find.byKey(hintSlot),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(
      fading.any((f) => f.opacity.value > 0 && f.opacity.value < 1),
      isTrue,
      reason: 'opacity must pass through intermediate values',
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.textContaining('Could not resolve the VPN server'),
      findsNothing,
    );
  });

  testWidgets('reduce motion swaps text without shaking or fading', (
    tester,
  ) async {
    await tester.pumpWidget(host(reduceMotion: true));
    container.read(vpnErrorProvider.notifier).state =
        'Could not resolve the VPN server. Check your internet connection and try again.';
    vpn.emit(VpnState.error);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(
      find.textContaining('Could not resolve the VPN server'),
      findsOneWidget,
    );
    final shifted = tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(ConnectButton),
        matching: find.byType(Transform),
      ),
    );
    for (final t in shifted) {
      expect(t.transform.getTranslation().x, 0);
    }
  });
}
