import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme modes: system, light, dark
enum AppThemeMode { system, light, dark }

/// Riverpod provider for theme
final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.system) {
    _load();
  }

  static const _key = 'app_theme_mode';
  int _revision = 0;
  Future<void> _writes = Future<void>.value();

  Future<void> _load() async {
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || revision != _revision) return;
    final saved = prefs.get(_key);
    if (saved is String) {
      state = AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.system,
      );
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    _revision++;
    state = mode;
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    });
    _writes = write.catchError((Object _) {});
    await write;
  }
}
