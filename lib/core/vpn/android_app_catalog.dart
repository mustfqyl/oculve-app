import 'package:flutter/services.dart';

class AndroidVpnApp {
  const AndroidVpnApp({
    required this.packageName,
    required this.label,
    required this.icon,
  });

  final String packageName;
  final String label;
  final Uint8List? icon;

  factory AndroidVpnApp.fromMap(Map<Object?, Object?> value) => AndroidVpnApp(
    packageName: value['packageName']! as String,
    label: value['label']! as String,
    icon: value['icon'] is Uint8List ? value['icon'] as Uint8List : null,
  );
}

class AndroidAppCatalog {
  static const _channel = MethodChannel('com.oculve/vpn_app_catalog');

  static Future<List<AndroidVpnApp>> listLaunchableApps() async {
    final values = await _channel.invokeListMethod<Object?>(
      'listLaunchableApps',
    );
    return (values ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(AndroidVpnApp.fromMap)
        .toList(growable: false);
  }
}
