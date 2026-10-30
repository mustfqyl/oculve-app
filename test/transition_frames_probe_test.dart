// TEMPORARY probe: captures route-transition frames for visual inspection.
// Run: flutter test --no-pub test/transition_frames_probe_test.dart
import 'dart:io';
import 'dart:ui' as ui;

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

const _captureKey = ValueKey('capture');
final _outDir = Directory('build/transition_frames');

Future<ui.Image> _capture(WidgetTester tester) async {
  // Same order as the golden comparator: start the capture inside the test
  // zone, await it in real async.
  final future = captureImage(tester.element(find.byKey(_captureKey)));
  final image = await tester.runAsync(() => future);
  return image!;
}

Future<void> _save(WidgetTester tester, String name) async {
  final image = await _capture(tester);
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  );
  image.dispose();
  await tester.runAsync(() async {
    await _outDir.create(recursive: true);
    await File(
      '${_outDir.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
  });
}

/// Mean luma of the frame, and of the bottom band that no page content covers.
Future<({double mean, double band, int hash})> _metrics(
  WidgetTester tester,
) async {
  final image = await _capture(tester);
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final bytes = data!.buffer.asUint8List();
  final width = image.width;
  final height = image.height;
  image.dispose();
  var sum = 0.0;
  var count = 0;
  var bandSum = 0.0;
  var bandCount = 0;
  var hash = 17;
  final bandTop = height - 40; // last 20 logical px at dpr 2
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final luma =
          0.2126 * bytes[i] + 0.7152 * bytes[i + 1] + 0.0722 * bytes[i + 2];
      sum += luma;
      count++;
      if (y >= bandTop) {
        bandSum += luma;
        bandCount++;
        hash =
            (hash * 31 + bytes[i] + bytes[i + 1] * 3 + bytes[i + 2] * 7) %
            1000000007;
      }
    }
  }
  return (mean: sum / count, band: bandSum / bandCount, hash: hash);
}

Widget _host({required bool dark}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  return ProviderScope(
    child: RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (context, child) =>
            AppBackdrop(child: child ?? const SizedBox.shrink()),
        onGenerateRoute: (_) => appRoute(const HomeScreen()),
      ),
    ),
  );
}

GlobalKey<NavigatorState> _navigator(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).navigatorKey!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final dark in [true, false]) {
    final tag = dark ? 'dark' : 'light';

    testWidgets('ios push/pop frames ($tag)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(dark: dark));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await _save(tester, '${tag}_00_home');
      final homeFrame = await _metrics(tester);

      final navigator = _navigator(tester);
      // ignore: avoid_print
      print(
        '[$tag] platform=$defaultTargetPlatform route=${appRoute(const SizedBox()).runtimeType}',
      );
      navigator.currentState!.push(appRoute(const SettingsScreen()));
      await tester.pump();

      final pushMetrics = <({double mean, double band, int hash})>[];
      for (var step = 1; step <= 9; step++) {
        await tester.pump(const Duration(milliseconds: 40));
        final m = await _metrics(tester);
        pushMetrics.add(m);
        if (step == 2 || step == 4 || step == 5 || step == 7) {
          await _save(
            tester,
            '${tag}_push_${(step * 40 / 360 * 100).round().toString().padLeft(2, '0')}pct',
          );
        }
      }
      await tester.pump(const Duration(milliseconds: 40));
      await _save(tester, '${tag}_01_settings');
      final settingsFrame = await _metrics(tester);

      // Back swipe from the left edge, finger by finger.
      final gesture = await tester.startGesture(const Offset(2, 420));
      final popMetrics = <({double mean, double band, int hash})>[];
      for (var step = 1; step <= 10; step++) {
        await gesture.moveBy(const Offset(39, 0));
        await tester.pump();
        // ignore: avoid_print
        print(
          '[$tag] step $step value=${ModalRoute.of(tester.element(find.byType(SettingsScreen)))?.animation?.value}',
        );
        final m = await _metrics(tester);
        popMetrics.add(m);
        if (step == 3 || step == 5 || step == 7) {
          await _save(tester, '${tag}_swipe_${step * 10}pct');
        }
      }
      await gesture.up();
      for (var step = 1; step <= 10; step++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await _save(tester, '${tag}_02_home_again');

      String fmt(List<({double mean, double band, int hash})> list) =>
          list.map((m) => m.mean.toStringAsFixed(2)).join(' ');

      // ignore: avoid_print
      print(
        '[$tag] home mean=${homeFrame.mean.toStringAsFixed(2)} '
        'settings mean=${settingsFrame.mean.toStringAsFixed(2)}',
      );
      // ignore: avoid_print
      print('[$tag] push means: ${fmt(pushMetrics)}');
      // ignore: avoid_print
      print('[$tag] swipe means: ${fmt(popMetrics)}');
      final bands = {
        homeFrame.hash,
        settingsFrame.hash,
        ...pushMetrics.map((m) => m.hash),
        ...popMetrics.map((m) => m.hash),
      };
      // ignore: avoid_print
      print('[$tag] distinct bottom-band hashes: ${bands.length}');
      // ignore: avoid_print
      print(
        '[$tag] band means: ${pushMetrics.map((m) => m.band.toStringAsFixed(2)).join(' ')}',
      );
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox());
    });
  }
}
