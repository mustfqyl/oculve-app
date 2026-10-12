import 'dart:io';

import 'package:flutter/services.dart';

/// OS-provided device identity for subscription requests. Never synthesizes an ID.
class DeviceHwid {
  DeviceHwid({Future<String?> Function()? read}) : _read = read ?? _readNative;

  static const channel = MethodChannel('com.oculve/device_identity');
  final Future<String?> Function() _read;
  Future<String>? _pending;

  Future<String> get() async {
    final pending = _pending ??= _load();
    try {
      return await pending;
    } catch (_) {
      // Retry on the next request, e.g. when iOS was locked during startup.
      if (identical(_pending, pending)) _pending = null;
      rethrow;
    }
  }

  Future<String> _load() async {
    try {
      final value = (await _read())?.trim();
      if (value == null ||
          value.isEmpty ||
          value.length > 128 ||
          !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(value) ||
          RegExp(r'^0+$').hasMatch(value.replaceAll('-', '')) ||
          RegExp(r'^[fF]+$').hasMatch(value.replaceAll('-', ''))) {
        throw const DeviceHwidUnavailable();
      }
      return value;
    } catch (_) {
      throw const DeviceHwidUnavailable();
    }
  }

  static Future<String?> _readNative() async {
    if (Platform.isLinux) {
      for (final path in ['/etc/machine-id', '/var/lib/dbus/machine-id']) {
        try {
          final id = (await File(path).readAsString()).trim();
          if (RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(id) &&
              !RegExp(r'^0+$').hasMatch(id)) {
            return id;
          }
        } on FileSystemException {
          continue;
        }
      }
      return null;
    }
    return channel.invokeMethod<String>('getHwid');
  }
}

class DeviceHwidUnavailable implements Exception {
  const DeviceHwidUnavailable();
}
