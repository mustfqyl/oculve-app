import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which location the user picked, and which server "Optimal" had
/// resolved to, across app launches. The tunnel outlives the app, so without
/// this a relaunch shows a live connection with the default location selected.
class ServerSelectionStore {
  ServerSelectionStore._();

  static const selectedKey = 'server.selected.v1';
  static const optimalKey = 'server.optimal.v1';

  /// The last picked location id, or null when nothing was ever picked.
  static Future<String?> readSelected() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(selectedKey);
  }

  /// The server Optimal last resolved to, or null.
  static Future<String?> readOptimal() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(optimalKey);
  }

  static Future<void> saveSelected(String? id) => _save(selectedKey, id);

  static Future<void> saveOptimal(String? id) => _save(optimalKey, id);

  static Future<void> _save(String key, String? value) async {
    final preferences = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value);
    }
  }
}
