import Foundation
import Darwin
@_exported import flutter_vless_privacy

public struct TunnelParsedConfig: Equatable {
    public let inboundPort: Int
    public let serverAddress: String?

    public init(inboundPort: Int, serverAddress: String?) {
        self.inboundPort = inboundPort
        self.serverAddress = serverAddress
    }
}

public struct TunnelPreparedConfig {
    public let data: Data
    public let logMessages: [String]
    public let proxyUsesXhttp: Bool
    public let bootstrapAddresses: [String]

    public init(data: Data, logMessages: [String], proxyUsesXhttp: Bool, bootstrapAddresses: [String] = []) {
        self.data = data
        self.logMessages = logMessages
        self.proxyUsesXhttp = proxyUsesXhttp
        self.bootstrapAddresses = bootstrapAddresses
    }
}

/// Pure JSON normalizer for the iOS Packet Tunnel.
///
/// Keep this logic outside `NEPacketTunnelProvider` so we can unit-test the
/// failure-prone parts without launching a real NetworkExtension process. The
/// helper intentionally preserves proxy credentials and VLESS
/// `users[].encryption` values byte-for-byte; the XHTTP/none incident proved
/// that mutating or dropping those server-provisioned values can produce a VPN
/// that connects locally but cannot fetch HTTP bytes.
public enum TunnelXrayConfigPreparer {
    public enum StartupError: Error { case invalidConfiguration, endpointUnavailable }

    /// Fixed preparation failure points. They only carry stage identity, never
    /// configuration content, so they are safe to publish through diagnostics.
    public enum StartupFailure: Error, Equatable {
        case invalidJSON
        case accessPolicyRejected
        case privacyPolicyRejected
        case dnsResolverUnsupported
        case noProxyEndpoint
        case tagCollision
        case addressPortStrategyUnsupported
        case endpointUnresolved
        case ipv6PolicyRejected
        case encodingFailed
    }

    /// Retry transient endpoint resolution only before virtual DNS/routes exist.
    /// A failed preparation must never create a connected tunnel with no runtime
    /// to recover. Exhaustion is a startup error handled by NetworkExtension.
    public static func prepareForStartup(
        jsonData: Data,
        credentials: LocalProxyCredentials,
        resolveIPv4: (String) -> String?,
        attempts: Int = 5,
        retryDelay: () async throws -> Void = { try await Task.sleep(nanoseconds: 3_000_000_000) }
    ) async throws -> TunnelPreparedConfig {
        var resolutionFailed = false
        var failureCode: StartupFailure?
        for attempt in 0..<max(1, attempts) {
            try Task.checkCancellation()
            resolutionFailed = false
            failureCode = nil
            let prepared = prepare(jsonData: jsonData, credentials: credentials, resolveIPv4: resolveIPv4) { code in
                if case .endpointUnresolved = code { resolutionFailed = true }
                failureCode = code
            }
            try Task.checkCancellation()
            if let prepared { return prepared }
            guard resolutionFailed else { throw failureCode ?? StartupFailure.invalidJSON }
            if attempt + 1 < attempts { try await retryDelay() }
        }
        throw StartupFailure.endpointUnresolved
    }

    /// Maps a caught protected-switch error onto a fixed diagnostic stage
    /// event. The underlying error text never reaches diagnostics.
    public static func switchRejection(_ error: Error) -> NativeDiagnosticMessage {
        func rejected(_ stage: String) -> NativeDiagnosticMessage {
            // Stage names are compile-time literals; route them through the
            // pass-through interpolation so the privacy redactor keeps them.
            "Server switch rejected at \(NativeDiagnosticMessage(stringLiteral: stage)); existing tunnel protection retained"
        }
        if let failure = error as? StartupFailure {
            switch failure {
            case .invalidJSON: return rejected("configuration parse stage")
            case .accessPolicyRejected: return rejected("access policy stage")
            case .privacyPolicyRejected: return rejected("privacy policy stage")
            case .dnsResolverUnsupported: return rejected("DNS resolver policy stage")
            case .noProxyEndpoint: return rejected("proxy endpoint stage")
            case .tagCollision: return rejected("tag collision stage")
            case .addressPortStrategyUnsupported: return rejected("address-port strategy stage")
            case .endpointUnresolved: return rejected("endpoint resolution stage")
            case .ipv6PolicyRejected: return rejected("IPv6 policy stage")
            case .encodingFailed: return rejected("configuration encoding stage")
            }
        }
        switch (error as NSError).localizedDescription {
        case "Invalid replacement metadata":
            return rejected("metadata stage")
        case "Protected tunnel is unavailable":
            return rejected("tunnel state stage")
        case "System route exclusions are unsupported":
            return rejected("route exclusion stage")
        case "Protected switch preparation failed":
            return rejected("preparation stage")
        case "Protected workers could not stop":
            return rejected("worker stop stage")
        default:
            if error is CancellationError {
                return "Server switch cancelled; existing tunnel protection retained"
            }
            return "Server switch rejected; existing tunnel protection retained"
        }
    }

    /// Maps a caught preparation error onto a fixed diagnostic stage event.
    /// The underlying error text never reaches diagnostics.
    public static func preparationFailureEvent(_ error: Error) -> NativeDiagnosticMessage {
        switch error as? StartupFailure {
        case .invalidJSON?:
            return "Tunnel preparation failed at configuration parse stage"
        case .accessPolicyRejected?:
            return "Tunnel preparation failed at access policy stage"
        case .privacyPolicyRejected?:
            return "Tunnel preparation failed at privacy policy stage"
        case .dnsResolverUnsupported?:
            return "Tunnel preparation failed at DNS resolver policy stage"
        case .noProxyEndpoint?:
            return "Tunnel preparation failed at proxy endpoint stage"
        case .tagCollision?:
            return "Tunnel preparation failed at tag collision stage"
        case .addressPortStrategyUnsupported?:
            return "Tunnel preparation failed at address-port strategy stage"
        case .endpointUnresolved?:
            return "Tunnel preparation failed at endpoint resolution stage"
        case .ipv6PolicyRejected?:
            return "Tunnel preparation failed at IPv6 policy stage"
        case .encodingFailed?:
            return "Tunnel preparation failed at configuration encoding stage"
        case nil:
            if error is CancellationError {
                return "Tunnel preparation was cancelled before route installation"
            }
            return "Tunnel preparation failed before route installation"
        }
    }

    public static func parseConfig(jsonData: Data) -> TunnelParsedConfig? {
        guard
            let configJSON = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
            let inboundPort = firstLocalInboundPort(configJSON: configJSON)
        else {
            return nil
        }
        return TunnelParsedConfig(
            inboundPort: inboundPort,
            serverAddress: parseServerAddress(configJSON: configJSON)
        )
    }

    public static func prepare(
        jsonData: Data,
        credentials: LocalProxyCredentials,
        resolveIPv4: (String) -> String? = { _ in nil },
        failure: (StartupFailure) -> Void = { _ in }
    ) -> TunnelPreparedConfig? {
        do {
            guard let input = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                  var configJSON = TunnelConfigKeys.normalize(input) else {
                failure(.invalidJSON)
                return nil
            }
            var messages: [String] = []

            do {
                try LocalProxyAccessPolicy.applyVPN(to: &configJSON, credentials: credentials)
            } catch {
                failure(.accessPolicyRejected)
                return nil
            }
            messages.append("Applied session authentication to the managed loopback SOCKS inbound")

            guard XrayPrivacyConfig.apply(to: &configJSON) else {
                failure(.privacyPolicyRejected)
                return nil
            }
            messages.append("Applied private Xray logging policy")

            if var routing = configJSON["routing"] as? [String: Any] {
                routing["domainStrategy"] = "AsIs"
                configJSON["routing"] = routing
            } else {
                configJSON["routing"] = ["domainStrategy": "AsIs"]
            }

            if var inbounds = configJSON["inbounds"] as? [[String: Any]] {
                for index in inbounds.indices {
                    let protocolType = inbounds[index]["protocol"] as? String
                    guard protocolType == "socks" || protocolType == "http" else {
                        continue
                    }
                    inbounds[index]["sniffing"] = [
                        "enabled": true,
                        "destOverride": ["http", "tls", "quic"],
                        "routeOnly": false
                    ]
                }
                configJSON["inbounds"] = inbounds
            }

            var proxyUsesXhttp = false
            if var outbounds = configJSON["outbounds"] as? [[String: Any]] {
                for index in outbounds.indices {
                    let tag = outbounds[index]["tag"] as? String
                    let protocolType = outbounds[index]["protocol"] as? String
                    guard tag == "proxy" || protocolType != "freedom" && protocolType != "blackhole" else {
                        continue
                    }
                    var streamSettings = outbounds[index]["streamSettings"] as? [String: Any] ?? [:]
                    normalizeStreamSettingsAliases(streamSettings: &streamSettings, messages: &messages)
                    let network = (streamSettings["network"] as? String ?? "?").lowercased()
                    proxyUsesXhttp = network == "xhttp"

                    outbounds[index]["streamSettings"] = streamSettings
                    break
                }
                configJSON["outbounds"] = outbounds
            }

            if proxyUsesXhttp {
                let blackholeTag = blackholeOutboundTag(configJSON: configJSON)
                if ensureUdp443BlockRule(configJSON: &configJSON, outboundTag: blackholeTag) {
                    messages.append("Added XHTTP UDP/443 block rule to force browser TCP fallback")
                }
            }

            guard let bootstrapAddresses = TunnelDNSPolicy.apply(to: &configJSON, resolveIPv4: resolveIPv4,
                failure: failure) else {
                return nil
            }
            messages.append("Configured system DNS over TCP through the selected proxy")
            guard TunnelIPv6Policy.apply(to: &configJSON) else {
                failure(.ipv6PolicyRejected)
                return nil
            }
            messages.append("Captured IPv6 is blocked; IPv4 remains available")
            let data: Data
            do { data = try JSONSerialization.data(withJSONObject: configJSON, options: []) }
            catch {
                failure(.encodingFailed)
                return nil
            }
            return TunnelPreparedConfig(data: data, logMessages: messages, proxyUsesXhttp: proxyUsesXhttp,
                                        bootstrapAddresses: bootstrapAddresses)
        } catch {
            failure(.invalidJSON)
            return nil
        }
    }

    public static func parseServerAddress(configJSON: [String: Any]) -> String? {
        guard let outbounds = configJSON["outbounds"] as? [[String: Any]] else {
            return nil
        }
        for outbound in outbounds {
            let tag = outbound["tag"] as? String
            let protocolType = outbound["protocol"] as? String
            guard tag == "proxy" || protocolType != "freedom" && protocolType != "blackhole" else {
                continue
            }
            guard let settings = outbound["settings"] as? [String: Any] else {
                continue
            }
            if let vnext = settings["vnext"] as? [[String: Any]],
               let address = vnext.first?["address"] as? String,
               !address.isEmpty {
                return address
            }
            if let servers = settings["servers"] as? [[String: Any]],
               let address = servers.first?["address"] as? String,
               !address.isEmpty {
                return address
            }
            if let address = settings["address"] as? String, !address.isEmpty {
                return address
            }
        }
        return nil
    }

    private static func firstLocalInboundPort(configJSON: [String: Any]) -> Int? {
        guard let inbounds = configJSON["inbounds"] as? [[String: Any]] else {
            return nil
        }
        for inbound in inbounds {
            guard let protocolType = inbound["protocol"] as? String,
                  let port = inbound["port"] as? Int else {
                continue
            }
            if protocolType == "socks" || protocolType == "http" {
                return port
            }
        }
        return nil
    }

    private static func blackholeOutboundTag(configJSON: [String: Any]) -> String {
        guard let outbounds = configJSON["outbounds"] as? [[String: Any]] else {
            return "blackhole"
        }
        return outbounds.first(where: { outbound in
            (outbound["protocol"] as? String) == "blackhole"
        })?["tag"] as? String ?? "blackhole"
    }

    private static func ensureUdp443BlockRule(configJSON: inout [String: Any], outboundTag: String) -> Bool {
        var routing = configJSON["routing"] as? [String: Any] ?? [:]
        var rules = routing["rules"] as? [[String: Any]] ?? []
        let alreadyExists = rules.contains { rule in
            (rule["type"] as? String) == "field" &&
            (rule["network"] as? String) == "udp" &&
            String(describing: rule["port"] ?? "") == "443" &&
            (rule["outboundTag"] as? String) == outboundTag
        }
        if alreadyExists {
            return false
        }
        rules.insert([
            "type": "field",
            "network": "udp",
            "port": "443",
            "outboundTag": outboundTag
        ], at: 0)
        routing["rules"] = rules
        configJSON["routing"] = routing
        return true
    }

    private static func normalizeStreamSettingsAliases(
        streamSettings: inout [String: Any],
        messages: inout [String]
    ) {
        if let network = streamSettings["network"] as? String {
            let normalizedNetwork = network.lowercased()
            if normalizedNetwork != network {
                streamSettings["network"] = normalizedNetwork
            }
        }

        if let legacyXhttpSettings = streamSettings.removeValue(forKey: "xHTTPSettings") {
            if streamSettings["xhttpSettings"] == nil {
                streamSettings["xhttpSettings"] = legacyXhttpSettings
                messages.append("Normalized xHTTPSettings to xhttpSettings for Xray XHTTP transport")
            }
        }

        if let legacyHTTPUpgradeSettings = streamSettings.removeValue(forKey: "httpUpgradeSettings") {
            if streamSettings["httpupgradeSettings"] == nil {
                streamSettings["httpupgradeSettings"] = legacyHTTPUpgradeSettings
                messages.append("Normalized httpUpgradeSettings to httpupgradeSettings for Xray HTTPUpgrade transport")
            }
        }

        if let legacySplitHTTPSettings = streamSettings.removeValue(forKey: "splitHTTPSettings") {
            if streamSettings["splithttpSettings"] == nil {
                streamSettings["splithttpSettings"] = legacySplitHTTPSettings
                messages.append("Normalized splitHTTPSettings to splithttpSettings for Xray SplitHTTP transport")
            }
        }

        if var tlsSettings = streamSettings["tlsSettings"] as? [String: Any],
           tlsSettings.removeValue(forKey: "allowInsecure") != nil {
            streamSettings["tlsSettings"] = tlsSettings
            messages.append("Removed deprecated tlsSettings.allowInsecure for Xray 26.x")
        }
    }

}
