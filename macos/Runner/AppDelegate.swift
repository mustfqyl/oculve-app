import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private static var launchReady = false
  private static var loginLaunch = false
  private static var launchCallbacks: [(Bool) -> Void] = []

  static func readLoginLaunch(_ callback: @escaping (Bool) -> Void) {
    if launchReady { callback(loginLaunch) } else { launchCallbacks.append(callback) }
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let event = NSAppleEventManager.shared().currentAppleEvent
    Self.loginLaunch = event?.eventID == kAEOpenApplication &&
      (event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem ||
       event?.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil)
    Self.launchReady = true
    let callbacks = Self.launchCallbacks
    Self.launchCallbacks.removeAll()
    callbacks.forEach { $0(Self.loginLaunch) }
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
