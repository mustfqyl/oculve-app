import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    testWidgets(
      'settings fits the compact $platform window',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme.copyWith(platform: platform),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(
          tester.getSize(find.byType(SettingsScreen)),
          const Size(320, 568),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
