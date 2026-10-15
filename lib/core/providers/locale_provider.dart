import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const supportedAppLocales = [Locale('en'), Locale('es'), Locale('tr')];

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _load();
  }

  static const _key = 'app_language';
  int _revision = 0;
  Future<void> _writes = Future<void>.value();

  Future<void> _load() async {
    final revision = _revision;
    final preferences = await SharedPreferences.getInstance();
    if (!mounted || revision != _revision) return;
    final code = preferences.get(_key);
    if (code is String && ['en', 'es', 'tr'].contains(code)) {
      state = Locale(code);
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (!['en', 'es', 'tr'].contains(languageCode)) return;
    _revision++;
    state = Locale(languageCode);
    final write = _writes.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key, languageCode);
    });
    _writes = write.catchError((Object _) {});
    await write;
  }
}
