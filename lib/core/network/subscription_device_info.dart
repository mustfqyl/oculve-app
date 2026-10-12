import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

/// Device metadata used only when fetching subscriptions.
class SubscriptionDeviceInfo {
  SubscriptionDeviceInfo({Future<Map<String, String>> Function()? read})
    : _read = read ?? _readNative;

  final Future<Map<String, String>> Function() _read;

  Future<Map<String, String>> headers() async {
    final headers = {'X-Device-OS': osName(Platform.operatingSystem)};
    try {
      final values = await _read();
      for (final name in ['X-Device-OS', 'X-Ver-OS', 'X-Device-Model']) {
        final value = values[name];
        if (value == null) continue;
        // Native model strings must remain safe as HTTP header values.
        final safe = value.replaceAll(RegExp(r'[^\x20-\x7E]'), ' ').trim();
        if (safe.isNotEmpty && safe.length <= 256) headers[name] = safe;
      }
    } catch (_) {
      // These fields are optional. An OS metadata failure must not prevent
      // a request with a valid HWID or invent a device model/version.
    }
    return headers;
  }

  static String osName(String platform) => switch (platform) {
    'macos' => 'macOS',
    'ios' => 'iOS',
    'android' => 'Android',
    'windows' => 'Windows',
    'linux' => 'Linux',
    _ => platform,
  };

  static Future<Map<String, String>> _readNative() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return {
        'X-Ver-OS': info.version.release,
        'X-Device-Model': '${info.manufacturer} ${info.model}'.trim(),
      };
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return {
        'X-Ver-OS': info.systemVersion,
        'X-Device-Model': info.utsname.machine,
      };
    }
    if (Platform.isMacOS) {
      final info = await plugin.macOsInfo;
      return {
        'X-Ver-OS':
            '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
        'X-Device-Model': info.model,
      };
    }
    if (Platform.isWindows) {
      final info = await plugin.windowsInfo;
      String? model;
      try {
        model = await const MethodChannel(
          'com.oculve/device_identity',
        ).invokeMethod<String>('getDeviceModel');
      } on PlatformException {
        // Keep the OS version if firmware model information is unavailable.
      } on MissingPluginException {
        // Older native runners may not expose model information yet.
      }
      return {
        'X-Ver-OS':
            '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}',
        if (model != null && model.isNotEmpty) 'X-Device-Model': model,
      };
    }
    if (Platform.isLinux) {
      final info = await plugin.linuxInfo;
      String? model;
      try {
        model = (await File(
          '/sys/class/dmi/id/product_name',
        ).readAsString()).trim();
      } on FileSystemException {
        // Machines without DMI still have their distribution information.
      }
      return {
        if (info.versionId != null) 'X-Ver-OS': info.versionId!,
        'X-Device-Model': model == null || model.isEmpty
            ? info.prettyName
            : model,
      };
    }
    return {};
  }
}
