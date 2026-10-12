import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pageAnimationsProvider =
    StateNotifierProvider<PageAnimationsNotifier, bool>(
      (ref) => PageAnimationsNotifier(),
    );

class PageAnimationsNotifier extends StateNotifier<bool> {
  PageAnimationsNotifier() : super(true) {
    _load();
  }

  static const _key = 'app_page_animations_enabled';

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    state = preferences.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, enabled);
  }
}
