import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TrayClickAction {
  toggleWindow,
  toggleConnection,
  chooseServer,
  showMenu,
  quit,
}

class TrayClickPreferences {
  const TrayClickPreferences({
    this.left = TrayClickAction.toggleWindow,
    this.right = TrayClickAction.showMenu,
  });

  final TrayClickAction left;
  final TrayClickAction right;

  TrayClickPreferences copyWith({
    TrayClickAction? left,
    TrayClickAction? right,
  }) =>
      TrayClickPreferences(left: left ?? this.left, right: right ?? this.right);
}

final trayClickPreferencesProvider =
    StateNotifierProvider<TrayClickPreferencesNotifier, TrayClickPreferences>(
      (ref) => TrayClickPreferencesNotifier(),
    );

class TrayClickPreferencesNotifier extends StateNotifier<TrayClickPreferences> {
  TrayClickPreferencesNotifier() : super(const TrayClickPreferences()) {
    _load();
  }

  static const _leftKey = 'tray.left_click_action.v1';
  static const _rightKey = 'tray.right_click_action.v1';

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      state = TrayClickPreferences(
        left: _parse(
          preferences.getString(_leftKey),
          TrayClickAction.toggleWindow,
        ),
        right: _parse(
          preferences.getString(_rightKey),
          TrayClickAction.showMenu,
        ),
      );
    } catch (_) {
      // The defaults remain usable if the preference store is unavailable.
    }
  }

  Future<void> setLeft(TrayClickAction action) async {
    state = state.copyWith(left: action);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_leftKey, action.name);
  }

  Future<void> setRight(TrayClickAction action) async {
    state = state.copyWith(right: action);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_rightKey, action.name);
  }

  static TrayClickAction _parse(String? value, TrayClickAction fallback) =>
      TrayClickAction.values.firstWhere(
        (action) => action.name == value,
        orElse: () => fallback,
      );
}
