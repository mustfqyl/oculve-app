import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../localization/app_strings.dart';
import '../models/vpn_state.dart';
import '../providers/locale_provider.dart';
import '../providers/vpn_provider.dart';

const desktopWindowSize = Size(320, 568);

class DesktopTrayController with TrayListener, WindowListener {
  DesktopTrayController(this.container);

  final ProviderContainer container;
  bool _quitting = false;
  bool _ready = false;
  ProviderSubscription<Locale>? _localeSubscription;

  Future<void> initialize() async {
    windowManager.addListener(this);
    trayManager.addListener(this);
    try {
      await windowManager.setPreventClose(true);
      await windowManager.setResizable(false);
      await trayManager.setIcon(
        switch (Platform.operatingSystem) {
          'macos' => 'assets/tray_icon_macos.png',
          'linux' => 'assets/tray_icon_linux.png',
          _ => 'assets/tray_icon_windows.ico',
        },
        isTemplate: Platform.isMacOS,
        iconSize: 18,
      );
      await trayManager.setToolTip('Oculve VPN');
      _localeSubscription = container.listen(localeProvider, (_, locale) {
        unawaited(_setContextMenu(locale.languageCode));
      });
      await _setContextMenu(container.read(localeProvider).languageCode);
      await windowManager.hide();
      _ready = true;
    } catch (_) {
      _localeSubscription?.close();
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      try {
        await trayManager.destroy();
      } catch (_) {}
      await windowManager.setPreventClose(false);
      rethrow;
    }
  }

  Future<void> _setContextMenu(String languageCode) =>
      trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(
              key: 'open',
              label: AppStrings.translate('Open Oculve', languageCode),
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'quit',
              label: AppStrings.translate('Quit Oculve', languageCode),
            ),
          ],
        ),
      );

  @override
  void onTrayIconMouseDown() => unawaited(toggleWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'open') unawaited(showWindow());
    if (menuItem.key == 'quit') unawaited(quit());
  }

  @override
  void onWindowClose() {
    if (!_quitting) unawaited(windowManager.hide());
  }

  @override
  void onWindowBlur() {
    if (_ready && !_quitting) unawaited(windowManager.hide());
  }

  Future<void> toggleWindow() async {
    if (!_ready) return;
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await showWindow();
    }
  }

  Future<void> showWindow() async {
    if (!_ready) return;
    await _positionBesideTray();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _positionBesideTray() async {
    try {
      final tray = await trayManager.getBounds();
      if (tray == null) {
        await windowManager.center();
        return;
      }
      final displays = await screenRetriever.getAllDisplays();
      final center = tray.center;
      final display = displays.firstWhere(
        (display) => _usableArea(display).contains(center),
        orElse: () => displays.first,
      );
      final area = _usableArea(display);
      await windowManager.setPosition(
        trayWindowPosition(tray, area, menuBar: Platform.isMacOS),
      );
    } catch (_) {
      await windowManager.center();
    }
  }

  Rect _usableArea(Display display) {
    final position = display.visiblePosition ?? Offset.zero;
    final size = display.visibleSize ?? display.size;
    return position & size;
  }

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    try {
      final state = container.read(vpnProvider);
      if (state == VpnState.connected || state == VpnState.connecting) {
        await container.read(vpnProvider.notifier).disconnect();
      }
    } catch (_) {
      _quitting = false;
      await showWindow();
      return;
    }
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _localeSubscription?.close();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    container.dispose();
    exit(0);
  }
}

Offset trayWindowPosition(Rect tray, Rect area, {required bool menuBar}) {
  final center = tray.center;
  final x = (center.dx - desktopWindowSize.width / 2).clamp(
    area.left,
    math.max(area.left, area.right - desktopWindowSize.width),
  );
  final below = tray.bottom + 8;
  final above = tray.top - desktopWindowSize.height - 8;
  final preferredY = menuBar
      ? below
      : (center.dy >= area.center.dy ? above : below);
  final y = preferredY.clamp(
    area.top,
    math.max(area.top, area.bottom - desktopWindowSize.height),
  );
  return Offset(x.toDouble(), y.toDouble());
}
