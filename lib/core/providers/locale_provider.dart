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

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_key);
    if (code != null && ['en', 'es', 'tr'].contains(code)) {
      state = Locale(code);
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (!['en', 'es', 'tr'].contains(languageCode)) return;
    state = Locale(languageCode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, languageCode);
  }
}
