import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/settings/presentation/startup_setting.dart';
import 'package:oculve/features/settings/presentation/lan_sharing_screen.dart';
import 'package:oculve/features/settings/presentation/xray_core_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  testWidgets(
    'startup reflects OS approval instead of claiming it is enabled',
    (tester) async {
      const channel = MethodChannel('oculve/startup');
      final calls = <MethodCall>[];
      var approval = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'setEnabled') approval = call.arguments == true;
            return {'enabled': false, 'requiresApproval': approval};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: ListView(children: const [StartupSetting()])),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Off'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('startup-mode')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('On'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(
        calls.where((c) => c.method == 'setEnabled').last.arguments,
        isTrue,
      );
      expect(
        find.text('Approve Oculve in System Settings → General → Login Items.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('startup-mode')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Connect'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('startup-mode')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        calls.where((c) => c.method == 'setEnabled').last.arguments,
        isFalse,
      );
      expect(find.text('Off'), findsOneWidget);
    },
  );
  for (final locale in ['en', 'tr', 'es']) {
    for (final screen in [
      Scaffold(body: ListView(children: const [StartupSetting()])),
      const LanSharingScreen(),
      const FragmentationSettingsScreen(),
      const SplitTunnelingScreen(),
    ]) {
      testWidgets('${screen.runtimeType} fits compact viewport in $locale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: Locale(locale),
              supportedLocales: const [
                Locale('en'),
                Locale('tr'),
                Locale('es'),
              ],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: AppTheme.darkTheme,
              home: screen,
            ),
          ),
        );
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
