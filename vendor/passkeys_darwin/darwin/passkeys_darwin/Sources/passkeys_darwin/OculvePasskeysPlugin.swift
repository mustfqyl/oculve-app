import Foundation
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

// Keep Oculve's existing minimum OS versions. The upstream plugin's native
// entry point requires macOS 13.5 / iOS 16; older systems must retain TOTP.
public final class OculvePasskeysPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        if #available(macOS 13.5, iOS 16.0, *) {
            PasskeysPlugin.register(with: registrar)
        }
    }
}
