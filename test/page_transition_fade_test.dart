import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/widgets/app_backdrop.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:oculve/features/home/presentation/home_screen.dart';
import 'package:oculve/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first page must fade out under a pushed page. A MaterialPageRoute as
/// first route cannot transition to a Cupertino route, so it got no secondary
/// animation, stayed fully opaque and its content showed through the new page.
void main() {
  testWidgets('first page fades out under a pushed page and back in', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: key,
          theme: AppTheme.darkTheme,
          builder: (_, child) => AppBackdrop(child: child ?? const SizedBox()),
          onGenerateRoute: (_) => appRoute(const HomeScreen()),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    double homeOpacity() {
      final fades = tester.widgetList<FadeTransition>(
        find.ancestor(
          of: find.byType(HomeScreen),
          matching: find.byType(FadeTransition),
        ),
      );
      return fades.map((f) => f.opacity.value).reduce((a, b) => a * b);
    }

    expect(homeOpacity(), 1);

    key.currentState!.push(appRoute(const SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(homeOpacity(), lessThan(1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(homeOpacity(), 0, reason: 'covered page must be gone by 40%');
    await tester.pump(const Duration(milliseconds: 300));

    key.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(homeOpacity(), 1);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
