import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TrayClickAction {
  toggleWindow,
  toggleConnection,
  chooseServer,
  showMenu,
  quit,
}

enum TrayCloseAction { hide, quit }

enum TrayStatusIndicator { connection, appIcon }

class TrayClickPreferences {
  const TrayClickPreferences({
    this.left = TrayClickAction.toggleWindow,
    this.right = TrayClickAction.showMenu,
    this.hideOnBlur = true,
    this.closeAction = TrayCloseAction.hide,
    this.indicator = TrayStatusIndicator.connection,
  });
  final TrayClickAction left, right;
  final bool hideOnBlur;
  final TrayCloseAction closeAction;
  final TrayStatusIndicator indicator;
  TrayClickPreferences copyWith({
    TrayClickAction? left,
    TrayClickAction? right,
    bool? hideOnBlur,
    TrayCloseAction? closeAction,
    TrayStatusIndicator? indicator,
  }) => TrayClickPreferences(
    left: left ?? this.left,
    right: right ?? this.right,
    hideOnBlur: hideOnBlur ?? this.hideOnBlur,
    closeAction: closeAction ?? this.closeAction,
    indicator: indicator ?? this.indicator,
  );
}

final trayClickPreferencesProvider =
    StateNotifierProvider<TrayClickPreferencesNotifier, TrayClickPreferences>(
      (ref) => TrayClickPreferencesNotifier(),
    );

class TrayClickPreferencesNotifier extends StateNotifier<TrayClickPreferences> {
  TrayClickPreferencesNotifier() : super(const TrayClickPreferences()) {
    _loaded = _load();
  }
  late final Future<void> _loaded;
  Future<void> get ready => _loaded;
  static const _leftKey = 'tray.left_click_action.v1';
  static const _rightKey = 'tray.right_click_action.v1';
  static const _blurKey = 'tray.hide_on_blur.v1';
  static const _closeKey = 'tray.close_action.v1';
  static const _indicatorKey = 'tray.status_indicator.v1';
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      state = TrayClickPreferences(
        left: _parse(
          p.getString(_leftKey),
          TrayClickAction.values,
          TrayClickAction.toggleWindow,
        ),
        right: _parse(
          p.getString(_rightKey),
          TrayClickAction.values,
          TrayClickAction.showMenu,
        ),
        hideOnBlur: p.getBool(_blurKey) ?? true,
        closeAction: _parse(
          p.getString(_closeKey),
          TrayCloseAction.values,
          TrayCloseAction.hide,
        ),
        indicator: _parse(
          p.getString(_indicatorKey),
          TrayStatusIndicator.values,
          TrayStatusIndicator.connection,
        ),
      );
    } catch (_) {
      /* Keep the existing usable defaults. */
    }
  }

  Future<void> _save(
    String key,
    Object value,
    TrayClickPreferences Function(TrayClickPreferences) update,
  ) async {
    await _loaded;
    final p = await SharedPreferences.getInstance();
    final saved = value is bool
        ? await p.setBool(key, value)
        : await p.setString(key, value as String);
    if (!saved) {
      throw StateError('Could not save tray settings. Please try again.');
    }
    if (mounted) state = update(state);
  }

  Future<void> setLeft(TrayClickAction action) =>
      _save(_leftKey, action.name, (p) => p.copyWith(left: action));
  Future<void> setRight(TrayClickAction action) =>
      _save(_rightKey, action.name, (p) => p.copyWith(right: action));
  Future<void> setHideOnBlur(bool value) =>
      _save(_blurKey, value, (p) => p.copyWith(hideOnBlur: value));
  Future<void> setCloseAction(TrayCloseAction value) =>
      _save(_closeKey, value.name, (p) => p.copyWith(closeAction: value));
  Future<void> setIndicator(TrayStatusIndicator value) =>
      _save(_indicatorKey, value.name, (p) => p.copyWith(indicator: value));
  Future<void> reset() async {
    await _loaded;
    final p = await SharedPreferences.getInstance();
    for (final key in [
      _leftKey,
      _rightKey,
      _blurKey,
      _closeKey,
      _indicatorKey,
    ]) {
      if (!await p.remove(key)) {
        throw StateError('Could not save tray settings. Please try again.');
      }
    }
    if (mounted) state = const TrayClickPreferences();
  }

  static T _parse<T extends Enum>(String? value, List<T> values, T fallback) =>
      values.firstWhere((item) => item.name == value, orElse: () => fallback);
}
