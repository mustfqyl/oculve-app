import Cocoa
import FlutterMacOS
import ServiceManagement
import IOKit

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let identityChannel = FlutterMethodChannel(
      name: "com.oculve/device_identity",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    identityChannel.setMethodCallHandler { call, result in
      guard call.method == "getHwid" else {
        result(FlutterMethodNotImplemented); return
      }
      let service = IOServiceGetMatchingService(
        kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice")
      )
      guard service != 0 else {
        result(FlutterError(code: "HWID_UNAVAILABLE", message: "Device identity unavailable.", details: nil)); return
      }
      defer { IOObjectRelease(service) }
      let value = IORegistryEntryCreateCFProperty(
        service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0
      )?.takeRetainedValue() as? String
      guard let value = value, !value.isEmpty else {
        result(FlutterError(code: "HWID_UNAVAILABLE", message: "Device identity unavailable.", details: nil)); return
      }
      result(value)
    }
    registerPhysicalTcpPingChannel(
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    let startupChannel = FlutterMethodChannel(name: "oculve/startup", binaryMessenger: flutterViewController.engine.binaryMessenger)
    startupChannel.setMethodCallHandler { call, result in
      if call.method == "launchContext" {
        AppDelegate.readLoginLaunch { result($0) }
        return
      }
      guard #available(macOS 13.0, *) else {
        result(FlutterError(code: "UNSUPPORTED", message: "Startup requires macOS 13 or later.", details: nil)); return
      }
      let service = SMAppService.mainApp
      if call.method == "setEnabled" {
        guard let enabled = call.arguments as? Bool else { result(FlutterError(code: "INVALID", message: "Invalid startup setting.", details: nil)); return }
        do {
          if enabled && service.status != .enabled && service.status != .requiresApproval { try service.register() }
          if !enabled && (service.status == .enabled || service.status == .requiresApproval) { try service.unregister() }
        } catch { result(FlutterError(code: "STARTUP_FAILED", message: "Could not update login startup. Check System Settings.", details: nil)); return }
      } else if call.method != "status" { result(FlutterMethodNotImplemented); return }
      result(["enabled": service.status == .enabled, "requiresApproval": service.status == .requiresApproval])
    }

    super.awakeFromNib()
  }
}
