import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DeviceIdentity") {
      let channel = FlutterMethodChannel(
        name: "com.oculve/device_identity", binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "getHwid" else {
          result(FlutterMethodNotImplemented); return
        }
        guard let value = UIDevice.current.identifierForVendor?.uuidString else {
          result(FlutterError(code: "HWID_UNAVAILABLE", message: "Device identity unavailable.", details: nil)); return
        }
        result(value)
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PhysicalTcpPing") {
      registerPhysicalTcpPingChannel(binaryMessenger: registrar.messenger())
    }
  }
}
