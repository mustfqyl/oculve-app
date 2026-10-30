import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/inline_feedback.dart';
import 'package:oculve/core/desktop/startup_service.dart';
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
      final backend = _ApprovalStartupBackend();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupServiceProvider.overrideWith(
              (ref) => StartupService(backend),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ListView(
                children: [StartupSetting(errors: InlineErrorController())],
              ),
            ),
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
      expect(backend.enabledChanges.last, isTrue);
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
      expect(backend.enabledChanges.last, isFalse);
      expect(find.text('Off'), findsOneWidget);
    },
  );
  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    testWidgets('kill switch explains the $platform system traffic guard', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme.copyWith(platform: platform),
            home: const XrayCoreSettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.text('Kill switch'));
      expect(find.text('System-managed'), findsOneWidget);
      await tester.tap(find.text('Kill switch'));
      // AppPage's background intentionally animates forever; advance the
      // dialog transition without waiting for every ticker to stop.
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text(
          platform == TargetPlatform.windows
              ? 'Windows installs system traffic protection before the VPN starts. It stays active during tunnel recovery and ends when you disconnect.'
              : 'Linux installs a firewall guard before VPN routing starts. It stays active during recovery and is removed when you stop the VPN.',
        ),
        findsOneWidget,
      );
    });
  }
  for (final locale in ['en', 'tr', 'es']) {
    for (final screen in [
      Scaffold(
        body: ListView(
          children: [StartupSetting(errors: InlineErrorController())],
        ),
      ),
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

class _ApprovalStartupBackend extends StartupBackend {
  final enabledChanges = <bool>[];
  bool requiresApproval = false;

  @override
  Future<({bool enabled, bool requiresApproval})> status() async =>
      (enabled: false, requiresApproval: requiresApproval);

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledChanges.add(enabled);
    requiresApproval = enabled;
  }

  @override
  Future<bool> launchedAtLogin(List<String> arguments) async => false;
}
