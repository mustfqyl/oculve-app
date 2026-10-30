import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One place for the app's touch feedback, so the strength of each kind of
/// event stays consistent. The OS decides whether the phone vibrates at all
/// (the system "haptics" switch is respected); desktops do nothing.
///
/// Meaning: [tap] a deliberate press, [selection] a choice changing,
/// [success] something finished, [warning] needs attention, [error] failed.
/// Strength rises in that order, so the buzz alone tells good from bad.
class AppHaptics {
  AppHaptics._();

  /// Turned off in tests that do not care about vibration.
  @visibleForTesting
  static bool enabled = true;

  static bool get _mobile =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  static void tap() => _run(HapticFeedback.lightImpact);

  static void selection() => _run(HapticFeedback.selectionClick);

  static void success() => _run(HapticFeedback.lightImpact);

  static void warning() => _run(HapticFeedback.mediumImpact);

  /// The strongest pulse: clearly different from a normal tap.
  static void error() => _run(HapticFeedback.heavyImpact);

  static void _run(Future<void> Function() feedback) {
    if (!enabled || !_mobile) return;
    unawaited(feedback().catchError((Object _) {}));
  }
}
