import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/haptics/app_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
          }
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppHaptics.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('each kind of event has its own strength', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppHaptics.tap();
    AppHaptics.selection();
    AppHaptics.success();
    AppHaptics.warning();
    AppHaptics.error();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });

  test('desktops and a disabled switch stay silent', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    AppHaptics.error();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppHaptics.enabled = false;
    AppHaptics.error();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
  });
}
