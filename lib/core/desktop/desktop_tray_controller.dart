import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dart_xdg_status_notifier_item/dart_xdg_status_notifier_item.dart'
    as sni;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../localization/app_strings.dart';
import '../models/vpn_state.dart';
import '../navigation/app_navigator.dart';
import '../providers/locale_provider.dart';
import '../providers/vpn_provider.dart';
import 'tray_click_preferences.dart';
import '../../features/auth/data/auth_repository.dart';
import '../vpn/profile.dart';

const desktopWindowSize = Size(320, 568);

class DesktopTrayController with TrayListener, WindowListener {
  DesktopTrayController(this.container);

  final ProviderContainer container;
  bool _quitting = false;
  bool _ready = false;
  String _currentIconPath = 'assets/tray_icon_idle.png';
  sni.StatusNotifierItemClient? _linuxTray;
  List<String> _linuxMenuServerIds = const [];
  Future<void> _menuUpdateQueue = Future<void>.value();
  ProviderSubscription<Locale>? _localeSubscription;
  ProviderSubscription<VpnState>? _vpnSubscription;
  ProviderSubscription<AsyncValue<Account?>>? _sessionSubscription;
  ProviderSubscription<String?>? _selectedServerSubscription;
  final Map<String, Future<sni.StatusNotifierIconPixmap>> _iconCache = {};
  Timer? _breathingTimer;
  int _breathingFrame = 0;
  int _iconRevision = 0;

  static const _connectedIcons = [
    'assets/tray_icon_connected_0.png',
    'assets/tray_icon_connected_1.png',
    'assets/tray_icon_connected_2.png',
    'assets/tray_icon_connected_3.png',
    'assets/tray_icon_connected_4.png',
    'assets/tray_icon_connected_5.png',
    'assets/tray_icon_connected_6.png',
    'assets/tray_icon_connected_7.png',
    'assets/tray_icon_connected_8.png',
    'assets/tray_icon_connected_9.png',
    'assets/tray_icon_connected_10.png',
    'assets/tray_icon_connected_11.png',
  ];

  Future<void> initialize() async {
    windowManager.addListener(this);
    if (!Platform.isLinux) trayManager.addListener(this);
    try {
      await windowManager.setPreventClose(true);
      await windowManager.setResizable(false);
      await _updateStatusIcon(container.read(vpnProvider));
      if (!Platform.isLinux) await trayManager.setToolTip('Oculve VPN');
      _localeSubscription = container.listen(localeProvider, (_, locale) {
        unawaited(_setContextMenu(locale.languageCode));
      });
      _vpnSubscription = container.listen(vpnProvider, (_, state) {
        unawaited(_updateStatusIcon(state));
        unawaited(_setContextMenu(container.read(localeProvider).languageCode));
      });
      _sessionSubscription = container.listen(sessionProvider, (_, _) {
        unawaited(_setContextMenu(container.read(localeProvider).languageCode));
      });
      _selectedServerSubscription = container.listen(
        selectedServerProvider,
        (_, _) => unawaited(
          _setContextMenu(container.read(localeProvider).languageCode),
        ),
      );
      await _setContextMenu(container.read(localeProvider).languageCode);
      await windowManager.hide();
      _ready = true;
    } catch (_) {
      _disposeSubscriptions();
      if (!Platform.isLinux) trayManager.removeListener(this);
      windowManager.removeListener(this);
      try {
        if (Platform.isLinux) {
          await _linuxTray?.close();
          _linuxTray = null;
        } else {
          await trayManager.destroy();
        }
      } catch (_) {}
      await windowManager.setPreventClose(false);
      rethrow;
    }
  }

  String get _baseIcon => 'assets/tray_icon_idle.png';

  Future<void> _updateStatusIcon(VpnState state) async {
    final revision = ++_iconRevision;
    _breathingTimer?.cancel();
    _breathingTimer = null;
    if (state == VpnState.connected) {
      _breathingFrame = 0;
      await _renderIcon(_connectedIcons.first, revision, template: false);
      if (revision != _iconRevision) return;
      _breathingTimer = Timer.periodic(const Duration(milliseconds: 160), (_) {
        if (revision != _iconRevision) return;
        _breathingFrame = (_breathingFrame + 1) % _connectedIcons.length;
        unawaited(
          _renderIcon(
            _connectedIcons[_breathingFrame],
            revision,
            template: false,
          ),
        );
      });
    } else if (state == VpnState.error) {
      await _renderIcon(
        'assets/tray_icon_error.png',
        revision,
        template: false,
      );
    } else {
      await _renderIcon(_baseIcon, revision, template: Platform.isMacOS);
    }
  }

  Future<void> _renderIcon(
    String path,
    int revision, {
    required bool template,
  }) async {
    _currentIconPath = path;
    if (Platform.isLinux) {
      final icon = await _iconCache.putIfAbsent(path, () => _loadIcon(path));
      _linuxTray?.iconPixmap = [icon];
    } else {
      await trayManager.setIcon(path, isTemplate: template, iconSize: 18);
    }
    if (revision != _iconRevision) return;
  }

  Future<sni.StatusNotifierIconPixmap> _loadIcon(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      targetWidth: 24,
      targetHeight: 24,
    );
    final frame = await codec.getNextFrame();
    try {
      final image = frame.image;
      final rgbaData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (rgbaData == null) throw StateError('Could not decode tray icon.');
      final rgba = rgbaData.buffer.asUint8List(
        rgbaData.offsetInBytes,
        rgbaData.lengthInBytes,
      );
      final argb = Uint8List(rgba.length);
      for (var i = 0; i < rgba.length; i += 4) {
        argb[i] = rgba[i + 3];
        argb[i + 1] = rgba[i];
        argb[i + 2] = rgba[i + 1];
        argb[i + 3] = rgba[i + 2];
      }
      return sni.StatusNotifierIconPixmap(
        width: image.width,
        height: image.height,
        pixels: argb,
      );
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  }

  void _disposeSubscriptions() {
    _breathingTimer?.cancel();
    _localeSubscription?.close();
    _vpnSubscription?.close();
    _sessionSubscription?.close();
    _selectedServerSubscription?.close();
    _localeSubscription = null;
    _vpnSubscription = null;
    _sessionSubscription = null;
    _selectedServerSubscription = null;
  }

  Future<void> _setContextMenu(String languageCode) async {
    final operation = _menuUpdateQueue.then(
      (_) => _applyContextMenu(languageCode),
    );
    _menuUpdateQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _applyContextMenu(String languageCode) async {
    final state = container.read(vpnProvider);
    final profiles =
        container.read(sessionProvider).valueOrNull?.profiles ?? [];
    final selected = container.read(selectedServerProvider);
    if (Platform.isLinux) {
      await _setLinuxContextMenu(languageCode, state, profiles, selected);
      return;
    }
    final locations = Menu(
      items: [
        MenuItem(
          key: 'server:$optimalServerId',
          label: AppStrings.translate('Optimal', languageCode),
          checked: selected == optimalServerId,
        ),
        if (profiles.isNotEmpty) MenuItem.separator(),
        for (final profile in profiles)
          MenuItem(
            key: 'server:${profile.id}',
            label: profile.name,
            checked: selected == profile.id,
          ),
      ],
    );
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'open',
            label: AppStrings.translate('Open Oculve', languageCode),
          ),
          MenuItem(
            key: 'connection',
            label: AppStrings.translate(
              state == VpnState.connected ? 'Disconnect VPN' : 'Connect VPN',
              languageCode,
            ),
            disabled:
                state == VpnState.connecting || state == VpnState.disconnecting,
          ),
          MenuItem.submenu(
            key: 'locations',
            label: AppStrings.translate('Choose location', languageCode),
            submenu: locations,
            disabled: profiles.isEmpty,
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'quit',
            label: AppStrings.translate('Quit Oculve', languageCode),
          ),
        ],
      ),
    );
  }

  Future<void> _setLinuxContextMenu(
    String languageCode,
    VpnState state,
    List<VpnProfile> profiles,
    String? selected,
  ) async {
    final serverIds = [
      optimalServerId,
      ...profiles.map((profile) => profile.id),
    ];
    final serverItems = <sni.DBusMenuItem>[
      sni.DBusMenuItem.radio(
        AppStrings.translate('Optimal', languageCode),
        state: selected == optimalServerId,
        onClicked: () => _selectServer(optimalServerId),
      ),
      for (final profile in profiles)
        sni.DBusMenuItem.radio(
          profile.name,
          state: selected == profile.id,
          onClicked: () => _selectServer(profile.id),
        ),
    ];
    final menu = sni.DBusMenuItem(
      children: [
        sni.DBusMenuItem(
          label: AppStrings.translate('Open Oculve', languageCode),
          onClicked: showWindow,
        ),
        sni.DBusMenuItem(
          label: AppStrings.translate(
            state == VpnState.connected ? 'Disconnect VPN' : 'Connect VPN',
            languageCode,
          ),
          enabled:
              state != VpnState.connecting && state != VpnState.disconnecting,
          onClicked: () => container.read(vpnProvider.notifier).toggle(),
        ),
        sni.DBusMenuItem(
          label: AppStrings.translate('Choose location', languageCode),
          children: serverItems,
        ),
        sni.DBusMenuItem.separator(),
        sni.DBusMenuItem(
          label: AppStrings.translate('Quit Oculve', languageCode),
          onClicked: quit,
        ),
      ],
    );

    final client = _linuxTray;
    if (client == null || !_sameList(_linuxMenuServerIds, serverIds)) {
      if (client != null) await client.close();
      _linuxTray = sni.StatusNotifierItemClient(
        id: 'oculve-vpn',
        title: 'Oculve VPN',
        itemIsMenu: false,
        iconPixmap: [
          await _iconCache.putIfAbsent(
            _currentIconPath,
            () => _loadIcon(_currentIconPath),
          ),
        ],
        toolTip: sni.StatusNotifierToolTip(
          iconName: '',
          iconPixmap: const [],
          title: 'Oculve VPN',
          body: AppStrings.translate(
            state == VpnState.connected ? 'Connected' : 'Disconnected',
            languageCode,
          ),
        ),
        menu: menu,
        onActivate: (_, _) async {
          final action = container.read(trayClickPreferencesProvider).left;
          await _runClickAction(action);
        },
        onContextMenu: (_, _) async {
          final action = container.read(trayClickPreferencesProvider).right;
          if (action != TrayClickAction.showMenu) {
            await _runClickAction(action);
          }
        },
      );
      _linuxMenuServerIds = serverIds;
      await _linuxTray!.connect(
        requireWatcher: true,
        enableGnomeExtensionCheck: false,
      );
      if (!await _linuxTray!.isHostRegistered) {
        throw StateError('No Linux status notifier host is available.');
      }
      return;
    }

    client.toolTip = sni.StatusNotifierToolTip(
      iconName: '',
      iconPixmap: const [],
      title: 'Oculve VPN',
      body: AppStrings.translate(
        state == VpnState.connected ? 'Connected' : 'Disconnected',
        languageCode,
      ),
    );
    await client.updateMenu(menu);
  }

  bool _sameList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  @override
  void onTrayIconMouseDown() {
    final action = container.read(trayClickPreferencesProvider).left;
    unawaited(_runClickAction(action));
  }

  @override
  void onTrayIconRightMouseDown() {
    final action = container.read(trayClickPreferencesProvider).right;
    unawaited(_runClickAction(action));
  }

  Future<void> _runClickAction(TrayClickAction action) async {
    switch (action) {
      case TrayClickAction.toggleWindow:
        await toggleWindow();
        break;
      case TrayClickAction.toggleConnection:
        await container.read(vpnProvider.notifier).toggle();
        break;
      case TrayClickAction.chooseServer:
        if (Platform.isLinux) {
          await showWindow();
          await openServerPicker();
        } else {
          await _showQuickServers();
        }
        break;
      case TrayClickAction.showMenu:
        await _setContextMenu(container.read(localeProvider).languageCode);
        if (!Platform.isLinux) await trayManager.popUpContextMenu();
        break;
      case TrayClickAction.quit:
        await quit();
        break;
    }
  }

  Future<void> _showQuickServers() async {
    final language = container.read(localeProvider).languageCode;
    final profiles =
        container.read(sessionProvider).valueOrNull?.profiles ?? [];
    final selected = container.read(selectedServerProvider);
    final menuItems = <MenuItem>[
      MenuItem(
        key: 'server:$optimalServerId',
        label: AppStrings.translate('Optimal', language),
        checked: selected == optimalServerId,
      ),
      if (profiles.isNotEmpty) MenuItem.separator(),
      for (final profile in profiles)
        MenuItem(
          key: 'server:${profile.id}',
          label: profile.name,
          checked: selected == profile.id,
        ),
    ];
    await trayManager.setContextMenu(Menu(items: menuItems));
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key == 'open') unawaited(showWindow());
    if (key == 'connection') {
      unawaited(container.read(vpnProvider.notifier).toggle());
    }
    if (key == 'quit') unawaited(quit());
    if (key != null && key.startsWith('server:')) {
      final id = key.substring('server:'.length);
      unawaited(_selectServer(id));
    }
  }

  Future<void> _selectServer(String id) async {
    final state = container.read(vpnProvider);
    final reconnect =
        state == VpnState.connected ||
        state == VpnState.connecting ||
        container.read(vpnTunnelMayBeActiveProvider);
    if (state == VpnState.connected ||
        state == VpnState.connecting ||
        container.read(vpnTunnelMayBeActiveProvider)) {
      await container.read(vpnProvider.notifier).disconnect();
    }
    container.read(selectedServerProvider.notifier).state = id;
    if (reconnect) await container.read(vpnProvider.notifier).connect();
    await _setContextMenu(container.read(localeProvider).languageCode);
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
      if (state == VpnState.connected ||
          state == VpnState.connecting ||
          container.read(vpnTunnelMayBeActiveProvider)) {
        await container.read(vpnProvider.notifier).disconnect();
      }
    } catch (_) {
      _quitting = false;
      await showWindow();
      return;
    }
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _disposeSubscriptions();
    if (Platform.isLinux) {
      await _linuxTray?.close();
      _linuxTray = null;
    } else {
      await trayManager.destroy();
    }
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
