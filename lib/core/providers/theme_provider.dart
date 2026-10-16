import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { auto, light, dark }

AppThemeMode resolveThemeMode(AppThemeMode mode, DateTime now) =>
    switch (mode) {
      AppThemeMode.auto =>
        now.hour >= 18 || now.hour < 6 ? AppThemeMode.dark : AppThemeMode.light,
      _ => mode,
    };

/// Riverpod provider for theme
final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier({
    AppThemeMode initialMode = AppThemeMode.auto,
    bool restorePreferences = true,
  }) : super(initialMode) {
    if (restorePreferences) _load();
  }

  static const _key = 'app_theme_mode';
  static AppThemeMode modeFromPreference(Object? saved) => saved is String
      ? AppThemeMode.values.firstWhere(
          (mode) => mode.name == saved,
          orElse: () => AppThemeMode.auto,
        )
      : AppThemeMode.auto;

  static Future<AppThemeMode> loadInitialMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return modeFromPreference(prefs.get(_key));
    } catch (_) {
      return AppThemeMode.auto;
    }
  }

  int _revision = 0;
  Future<void> _writes = Future<void>.value();

  Future<void> _load() async {
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || revision != _revision) return;
    state = modeFromPreference(prefs.get(_key));
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
