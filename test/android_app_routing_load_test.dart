import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/settings/presentation/android_app_routing_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('failed routing restore cannot overwrite saved exclusions', (
    tester,
  ) async {
    const key = 'xray.routing.android_blocked_apps.v1';
    SharedPreferences.setMockInitialValues({key: 42});
    const channel = MethodChannel('com.oculve/vpn_app_catalog');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => [
        {'packageName': 'com.example.app', 'label': 'Example'},
      ],
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const AndroidAppRoutingScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Save 0 apps'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.get(key), 42);
    await prefs.setStringList(key, ['com.example.app']);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Save 1 app'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
