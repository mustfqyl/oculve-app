import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/desktop/desktop_tray_controller.dart';

void main() {
  test('desktop panel matches the Mullvad content size', () {
    expect(desktopWindowSize, const Size(320, 568));
  });

  test('macOS panel opens below the menu bar icon', () {
    final position = trayWindowPosition(
      const Rect.fromLTWH(1000, 0, 24, 24),
      const Rect.fromLTWH(0, 24, 1440, 876),
      menuBar: true,
    );
    expect(position, const Offset(852, 32));
  });

  test('Windows panel opens above the taskbar and stays on screen', () {
    final position = trayWindowPosition(
      const Rect.fromLTWH(1890, 1040, 24, 24),
      const Rect.fromLTWH(0, 0, 1920, 1040),
      menuBar: false,
    );
    expect(position, const Offset(1600, 464));
  });
}
