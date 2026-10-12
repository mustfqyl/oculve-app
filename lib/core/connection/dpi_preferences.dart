import 'package:shared_preferences/shared_preferences.dart';

/// Engine profile 4 uses native per-destination automatic fallback;
/// 0..3 are pinned manual strategies, never selected by readiness probes.
enum DpiStrategy {
  automatic(4, 'Automatic'),
  profile1(0, 'Split'),
  profile2(1, 'Split & reorder'),
  profile3(2, 'Reorder'),
  profile4(3, 'Reorder & split');

  const DpiStrategy(this.engineProfile, this.label);
  final int engineProfile;
  final String label;
}

class DpiPreferences {
  static const key = 'connection.dpi.strategy.v1';
  static Future<DpiStrategy> read() async {
    final value = (await SharedPreferences.getInstance()).getInt(key);
    return DpiStrategy.values
            .where((item) => item.engineProfile == value)
            .firstOrNull ??
        DpiStrategy.automatic;
  }

  static Future<void> save(DpiStrategy strategy) async {
    if (!await (await SharedPreferences.getInstance()).setInt(
      key,
      strategy.engineProfile,
    )) {
      throw StateError('Could not save DPI strategy.');
    }
  }
}
