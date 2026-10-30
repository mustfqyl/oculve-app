import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final buzz = <String>[];
  late _FakeVpn vpn;
  late ProviderContainer container;

  setUp(() {
    buzz.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            buzz.add(
              (call.arguments as String).replaceAll('HapticFeedbackType.', ''),
            );
          }
          return null;
        });
    container = ProviderContainer(
      overrides: [vpnProvider.overrideWith((ref) => vpn = _FakeVpn(ref))],
    );
  });
  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpButton(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(400, 800)),
          child: Scaffold(body: Center(child: ConnectButton())),
        ),
      ),
    ),
  );

  testWidgets('a new failure buzzes once, strongly', (tester) async {
    await pumpButton(tester);
    container.read(vpnErrorProvider.notifier).state =
        'Could not resolve the VPN server. Check your internet connection and try again.';
    vpn.emit(VpnState.error);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(buzz, ['heavyImpact']);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('finishing a connection the user started gives a light buzz', (
    tester,
  ) async {
    await pumpButton(tester);
    vpn.emit(VpnState.connecting);
    await tester.pump();
    vpn.emit(VpnState.connected);
    await tester.pump(const Duration(milliseconds: 400));
    expect(buzz, ['lightImpact']);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a tunnel that was already up when the app opened is silent', (
    tester,
  ) async {
    await pumpButton(tester);
    vpn.emit(VpnState.connected);
    await tester.pump(const Duration(milliseconds: 400));
    expect(buzz, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });
}
