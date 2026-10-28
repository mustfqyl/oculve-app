import Foundation
import os

/// Strings supplied by configs, servers, callbacks and errors are never rendered.
/// Only source literals and explicitly typed scalar diagnostics reach a sink.
public struct NativeDiagnosticMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public let text: String
    public init(stringLiteral value: String) { text = value }
    public init(stringInterpolation: StringInterpolation) { text = stringInterpolation.text }
    public struct StringInterpolation: StringInterpolationProtocol {
        var text = ""
        public init(literalCapacity: Int, interpolationCount: Int) { text.reserveCapacity(literalCapacity) }
        public mutating func appendLiteral(_ literal: String) { text += literal }
        public mutating func appendInterpolation(_ value: NativeDiagnosticMessage, privacy: OSLogPrivacy = .private) { text += value.text }
        public mutating func appendInterpolation<T>(_ value: T, privacy: OSLogPrivacy = .private) { text += "<redacted>" }
        public mutating func appendInterpolation<T: BinaryInteger>(_ value: T, privacy: OSLogPrivacy = .private) { text += String(value) }
        public mutating func appendInterpolation(_ value: Bool, privacy: OSLogPrivacy = .private) { text += value ? "true" : "false" }
        public mutating func appendInterpolation(_ value: Double, privacy: OSLogPrivacy = .private) { text += value.isFinite ? String(value) : "unknown" }
    }
}

public struct NativePrivacyLogger {
    private let logger: Logger
    public init(subsystem: String, category: String) { logger = Logger(subsystem: subsystem, category: category) }
    public func info(_ message: NativeDiagnosticMessage) { logger.info("\(message.text, privacy: .public)") }
    public func warning(_ message: NativeDiagnosticMessage) { logger.warning("\(message.text, privacy: .public)") }
    public func error(_ message: NativeDiagnosticMessage) { logger.error("\(message.text, privacy: .public)") }
    public func fault(_ message: NativeDiagnosticMessage) { logger.fault("\(message.text, privacy: .public)") }
}

public enum NativeLogPrivacy {
    public static let providerLogFilename = "flutter_vless_tunnel_private_v2.log"
    public static let snapshotCommand = "xray_debug_private_v2"

    /// Recovery catches every startNativeRuntime failure. Only fixed stage
    /// codes are exported; raw error text never reaches diagnostics.
    /// The description input is already filtered through runtimeEvent() or
    /// thrown by tunnelError(), which emits a closed message vocabulary.
    public static func restartFailure(_ error: Error) -> NativeDiagnosticMessage {
        let description = (error as NSError).localizedDescription
        switch description {
        case "Physical network interface is unavailable":
            return "Native restart failed at DPI interface stage; protected traffic remains blocked"
        case "Xray could not locate the NetworkExtension TUN interface":
            return "Native restart failed at TUN descriptor stage; protected traffic remains blocked"
        case "Invalid DPI strategy":
            return "Native restart failed at DPI profile stage; protected traffic remains blocked"
        case "DPI Bypass could not establish verified Internet connectivity":
            return "Native restart failed at DPI connectivity stage; protected traffic remains blocked"
        case "Xray geo asset directory must not be empty":
            return "Native restart failed at Xray asset stage; protected traffic remains blocked"
        case "Timed out waiting for HEV startup":
            return "Native restart failed at HEV startup stage; protected traffic remains blocked"
        case "Failed to start XRay with unknown error":
            return "Native restart failed at Xray startup stage; protected traffic remains blocked"
        default:
            let hevPrefix = "HEV exited during startup with code "
            if description.hasPrefix(hevPrefix),
               let code = Int32(description.dropFirst(hevPrefix.count)) {
                return "Native restart failed at HEV startup stage (code \(code)); protected traffic remains blocked"
            }
            let nativePrefix = "Native operation failed (code "
            if description.hasPrefix(nativePrefix),
               let code = Int(description.dropFirst(nativePrefix.count).dropLast(")".count)) {
                return "Native restart failed at native stage (code \(code)); protected traffic remains blocked"
            }
            if description.hasPrefix("Xray startup failed") {
                return "Native restart failed at Xray startup stage; protected traffic remains blocked"
            }
            if description == "Xray diagnostic details omitted" {
                return "Native restart failed at Xray stage; protected traffic remains blocked"
            }
            return "Native restart failed at native stage; protected traffic remains blocked"
        }
    }

    /// Closed callback vocabulary: never infer that arbitrary runtime text is safe.
    public static func runtimeEvent(_ raw: String) -> NativeDiagnosticMessage {
        switch raw {
        case "Xray startup failed: privacy configuration": return "Xray startup failed: privacy configuration"
        case "Xray startup failed: decode configuration": return "Xray startup failed: decode configuration"
        case "Xray startup failed: build configuration": return "Xray startup failed: build configuration"
        case "Xray startup failed: create core": return "Xray startup failed: create core"
        case "Xray startup failed: start core": return "Xray startup failed: start core"
        case "Xray configuration error": return "Xray configuration error"
        case "Xray configuration warning": return "Xray configuration warning"
        case "Xray configuration info": return "Xray configuration info"
        case "Xray configuration debug": return "Xray configuration debug"
        case "Xray runtime error": return "Xray runtime error"
        case "Xray runtime warning": return "Xray runtime warning"
        case "Xray runtime info": return "Xray runtime info"
        case "Xray runtime debug": return "Xray runtime debug"
        default: return "Xray diagnostic details omitted"
        }
    }

    public static func operationError(_ error: Error) -> NSError {
        let original = error as NSError
        let stage = runtimeEvent(original.localizedDescription)
        let message: NativeDiagnosticMessage = stage.text == "Xray diagnostic details omitted"
            ? "Native operation failed (code \(original.code))" : stage
        return NSError(domain: "flutter_vless.native", code: original.code,
                       userInfo: [NSLocalizedDescriptionKey: message.text])
    }

    public static func removeLegacyProviderLog(in directory: URL) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("flutter_vless_tunnel_debug.log"))
    }
}
