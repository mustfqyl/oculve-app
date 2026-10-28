import XCTest
@testable import flutter_vless_tunnel_support

final class TunnelDNSPolicyTests: XCTestCase {
    private static let credentials = try! LocalProxyCredentials(username: "test-session", password: "test-session-password")
    func testStartupRetriesEndpointResolutionAndProducesRecoverableRuntime() async throws {
        let data = Data(#"{"inbounds":[{"protocol":"socks","port":10808}],"outbounds":[{"protocol":"http","settings":{"address":"bootstrap.invalid","port":443}}]}"#.utf8)
        var attempts = 0
        var pauses = 0
        let prepared = try await TunnelXrayConfigPreparer.prepareForStartup(jsonData: data, credentials: Self.credentials,
            resolveIPv4: { _ in attempts += 1; return attempts < 3 ? nil : "203.0.113.7" },
            retryDelay: { pauses += 1 })
        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(pauses, 2)
        XCTAssertEqual(prepared.bootstrapAddresses, ["203.0.113.7"])
        XCTAssertEqual(TunnelXrayConfigPreparer.parseConfig(jsonData: prepared.data)?.inboundPort, 10808)
        do {
            _ = try await TunnelXrayConfigPreparer.prepareForStartup(jsonData: data, credentials: Self.credentials,
                resolveIPv4: { _ in nil }, attempts: 2, retryDelay: {})
            XCTFail("Unavailable endpoints must fail startup, never install a runtime-less tunnel")
        } catch {
            XCTAssertEqual(error as? TunnelXrayConfigPreparer.StartupFailure, .endpointUnresolved)
            XCTAssertEqual(
                TunnelXrayConfigPreparer.preparationFailureEvent(error).text,
                "Tunnel preparation failed at endpoint resolution stage")
        }
        do {
            _ = try await TunnelXrayConfigPreparer.prepareForStartup(jsonData: Data("{}".utf8), credentials: Self.credentials,
                resolveIPv4: { _ in XCTFail("Invalid input must not resolve"); return nil },
                retryDelay: { XCTFail("Invalid configuration must not retry") })
            XCTFail("Invalid input must fail startup")
        } catch {
            XCTAssertEqual(error as? TunnelXrayConfigPreparer.StartupFailure, .accessPolicyRejected)
            XCTAssertEqual(
                TunnelXrayConfigPreparer.preparationFailureEvent(error).text,
                "Tunnel preparation failed at access policy stage")
        }
        do {
            // A valid inbound without any proxy outbound must reach the DNS
            // policy and fail at the proxy endpoint stage, not the resolver.
            let data = try JSONSerialization.data(withJSONObject: [
                "inbounds": [["tag": "socks-in", "protocol": "socks", "port": 10808,
                              "settings": ["auth": "noauth", "udp": true]]]
            ], options: [])
            _ = try await TunnelXrayConfigPreparer.prepareForStartup(jsonData: data, credentials: Self.credentials,
                resolveIPv4: { _ in XCTFail("A missing outbound must not resolve"); return nil },
                retryDelay: { XCTFail("A missing outbound must not retry") })
            XCTFail("A config without outbounds must fail startup")
        } catch {
            XCTAssertEqual(error as? TunnelXrayConfigPreparer.StartupFailure, .noProxyEndpoint)
            XCTAssertEqual(
                TunnelXrayConfigPreparer.preparationFailureEvent(error).text,
                "Tunnel preparation failed at proxy endpoint stage")
        }
    }

    func testPreparationFailureEventsCarryFixedStagesOnly() {
        let secrets = ["server.example.invalid", "secret-token"]
        let cases: [(TunnelXrayConfigPreparer.StartupFailure, String)] = [
            (.invalidJSON, "Tunnel preparation failed at configuration parse stage"),
            (.accessPolicyRejected, "Tunnel preparation failed at access policy stage"),
            (.privacyPolicyRejected, "Tunnel preparation failed at privacy policy stage"),
            (.dnsResolverUnsupported, "Tunnel preparation failed at DNS resolver policy stage"),
            (.noProxyEndpoint, "Tunnel preparation failed at proxy endpoint stage"),
            (.tagCollision, "Tunnel preparation failed at tag collision stage"),
            (.addressPortStrategyUnsupported, "Tunnel preparation failed at address-port strategy stage"),
            (.endpointUnresolved, "Tunnel preparation failed at endpoint resolution stage"),
            (.ipv6PolicyRejected, "Tunnel preparation failed at IPv6 policy stage"),
            (.encodingFailed, "Tunnel preparation failed at configuration encoding stage")
        ]
        for (failure, expected) in cases {
            let text = TunnelXrayConfigPreparer.preparationFailureEvent(failure).text
            XCTAssertEqual(text, expected)
            for secret in secrets {
                XCTAssertFalse(text.contains(secret))
            }
        }
        XCTAssertEqual(
            TunnelXrayConfigPreparer.preparationFailureEvent(CancellationError()).text,
            "Tunnel preparation was cancelled before route installation")
        XCTAssertEqual(
            TunnelXrayConfigPreparer.preparationFailureEvent(
                NSError(domain: "flutter_vless.packet_tunnel", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: secrets[0]])).text,
            "Tunnel preparation failed before route installation")
    }

    func testEncryptedResolverPolicyMatchesAppPresets() throws {
        // The app's DNS presets are single https:// DoH endpoints (the macOS
        // policy already accepts them). The iOS policy must accept the same
        // shape, bootstrap the DoH host through the proxy, and rewrite the
        // plaintext relay onto Xray's protected loopback DoH module.
        func makeConfig(_ servers: [Any]) -> [String: Any] {
            [
                "inbounds": [["tag": "socks-in", "protocol": "socks", "port": 10808,
                              "settings": ["auth": "noauth", "udp": true]]],
                "outbounds": [["tag": "proxy", "protocol": "vless",
                               "settings": ["vnext": [["address": "203.0.113.7", "port": 443]]]]],
                "dns": ["servers": servers]
            ]
        }
        var knownConfig = makeConfig(["https://cloudflare-dns.com/dns-query"])
        var knownStages: [TunnelXrayConfigPreparer.StartupFailure] = []
        let known = TunnelDNSPolicy.apply(to: &knownConfig,
            resolveIPv4: { _ in XCTFail("A known DoH host must not resolve"); return nil },
            failure: { knownStages.append($0) })
        XCTAssertNotNil(known)
        XCTAssertNil(knownStages.first)
        let knownDns = try XCTUnwrap(knownConfig["dns"] as? [String: Any])
        XCTAssertEqual(knownDns["servers"] as? [String], ["https://cloudflare-dns.com/dns-query"])
        XCTAssertEqual((knownDns["hosts"] as? [String: String])?["cloudflare-dns.com"], "1.1.1.1")
        let outbounds = try XCTUnwrap(knownConfig["outbounds"] as? [[String: Any]])
        let relay = try XCTUnwrap(outbounds.first { ($0["tag"] as? String) == "flutter-vless-system-dns" })
        let relaySettings = try XCTUnwrap(relay["settings"] as? [String: Any])
        XCTAssertEqual(relaySettings["rewriteAddress"] as? String, "127.0.0.1")
        let relayRules = try XCTUnwrap(relaySettings["rules"] as? [[String: Any]])
        XCTAssertEqual(relayRules.count, 3)
        XCTAssertEqual(relayRules[1]["action"] as? String, "hijack")
        XCTAssertEqual(relayRules[1]["qType"] as? String, "1")

        var unknownConfig = makeConfig(["https://dns.example.net/dns-query"])
        var unknownStages: [TunnelXrayConfigPreparer.StartupFailure] = []
        let unknown = TunnelDNSPolicy.apply(to: &unknownConfig,
            resolveIPv4: { _ in "203.0.113.9" }, failure: { unknownStages.append($0) })
        XCTAssertNotNil(unknown)
        XCTAssertNil(unknownStages.first)

        var unresolvedConfig = makeConfig(["https://dns.example.net/dns-query"])
        var unresolvedStages: [TunnelXrayConfigPreparer.StartupFailure] = []
        let unresolved = TunnelDNSPolicy.apply(to: &unresolvedConfig,
            resolveIPv4: { _ in nil }, failure: { unresolvedStages.append($0) })
        XCTAssertNil(unresolved)
        XCTAssertEqual(unresolvedStages, [.endpointUnresolved])

        var rejectedConfig = makeConfig(["https://user:pass@dns.example.net/dns-query"])
        var rejectedStages: [TunnelXrayConfigPreparer.StartupFailure] = []
        let rejected = TunnelDNSPolicy.apply(to: &rejectedConfig,
            resolveIPv4: { _ in XCTFail("A rejected endpoint must not resolve"); return nil },
            failure: { rejectedStages.append($0) })
        XCTAssertNil(rejected)
        XCTAssertEqual(rejectedStages, [.dnsResolverUnsupported])

        var multiConfig = makeConfig(["tcp://1.1.1.1", "tcp://8.8.8.8"])
        var multiStages: [TunnelXrayConfigPreparer.StartupFailure] = []
        let multi = TunnelDNSPolicy.apply(to: &multiConfig,
            resolveIPv4: { _ in XCTFail("A rejected list must not resolve"); return nil },
            failure: { multiStages.append($0) })
        XCTAssertNil(multi)
        XCTAssertEqual(multiStages, [.dnsResolverUnsupported])

        var plainConfig = makeConfig(["tcp://1.1.1.1"])
        var plainStages: [TunnelXrayConfigPreparer.StartupFailure] = []
        let plain = TunnelDNSPolicy.apply(to: &plainConfig,
            resolveIPv4: { _ in nil }, failure: { plainStages.append($0) })
        XCTAssertNotNil(plain)
        XCTAssertNil(plainStages.first)
        let plainDns = try XCTUnwrap(plainConfig["dns"] as? [String: Any])
        XCTAssertEqual(plainDns["servers"] as? [String], ["tcp://1.1.1.1"])
    }

    func testStartupCancellationDuringBackoffCannotPublishPreparedRuntime() async throws {
        let waiting = expectation(description: "bootstrap retry")
        let data = Data(#"{"inbounds":[{"protocol":"socks","port":10808}],"outbounds":[{"protocol":"http","settings":{"address":"bootstrap.invalid","port":443}}]}"#.utf8)
        let task = Task {
            try await TunnelXrayConfigPreparer.prepareForStartup(jsonData: data, credentials: Self.credentials,
                resolveIPv4: { _ in nil }, retryDelay: {
                    waiting.fulfill()
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                })
        }
        await fulfillment(of: [waiting], timeout: 2)
        task.cancel()
        do { _ = try await task.value; XCTFail("Stopped startup must not complete") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testHTTPAndSocksDNSUseTCPProxyAndKeepApplicationRules() throws {
        for proto in ["http", "socks"] {
            let applicationRule: [String: Any] = ["inboundTag": ["socks-direct"], "outboundTag": "direct"]
            let input: [String: Any] = [
                "inbounds": [["tag": "socks-in", "listen": "127.0.0.1", "protocol": "socks", "port": 10808]],
                "outbounds": [
                    ["tag": "proxy", "protocol": proto, "settings": ["servers": [["address": "proxy.example", "port": 443]]]],
                    ["tag": "direct", "protocol": "freedom"]
                ],
                "routing": ["rules": [applicationRule]]
            ]
            let data = try JSONSerialization.data(withJSONObject: input)
            let prepared = try XCTUnwrap(TunnelXrayConfigPreparer.prepare(jsonData: data, credentials: Self.credentials, resolveIPv4: { _ in "203.0.113.7" }))
            let output = try XCTUnwrap(JSONSerialization.jsonObject(with: prepared.data) as? [String: Any])
            let dns = try XCTUnwrap(output["dns"] as? [String: Any])
            XCTAssertEqual(dns["servers"] as? [String], ["tcp://1.1.1.1"])
            XCTAssertEqual((dns["hosts"] as? [String: String])?["proxy.example"], "203.0.113.7")
            let outbounds = try XCTUnwrap(output["outbounds"] as? [[String: Any]])
            let relay = try XCTUnwrap(outbounds.first(where: { ($0["protocol"] as? String) == "dns" }))
            XCTAssertNil(relay["proxySettings"])
            let stream = try XCTUnwrap(relay["streamSettings"] as? [String: Any])
            XCTAssertEqual((stream["sockopt"] as? [String: String])?["dialerProxy"], "proxy")
            let relaySettings = try XCTUnwrap(relay["settings"] as? [String: Any])
            XCTAssertEqual(relaySettings["rewriteNetwork"] as? String, "tcp")
            let relayRules = try XCTUnwrap(relaySettings["rules"] as? [[String: Any]])
            XCTAssertEqual(relayRules.count, 2)
            XCTAssertEqual(relayRules[0] as NSDictionary, ["action": "return", "qType": "28", "rCode": 0] as NSDictionary)
            XCTAssertEqual(relayRules[1] as NSDictionary, ["action": "direct"] as NSDictionary)
            let rules = try XCTUnwrap((output["routing"] as? [String: Any])?["rules"] as? [[String: Any]])
            XCTAssertEqual(rules[1]["outboundTag"] as? String, "proxy")
            XCTAssertEqual(rules[2]["ip"] as? [String], ["198.18.0.2/32"])
            XCTAssertEqual(rules[2]["network"] as? String, "tcp,udp")
            XCTAssertEqual(rules.last! as NSDictionary, applicationRule as NSDictionary)
            XCTAssertEqual(prepared.bootstrapAddresses, ["203.0.113.7"])
            if let directory = ProcessInfo.processInfo.environment["TUNNEL_DNS_FIXTURES"] {
                try prepared.data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(proto + ".json"))
            }
        }
    }

    func testBootstrapFailureAndTagCollisionsRejectPreparation() {
        var config: [String: Any] = ["outbounds": [["protocol": "http", "settings": ["address": "unresolved.example", "port": 443]]]]
        XCTAssertNil(TunnelDNSPolicy.apply(to: &config, resolveIPv4: { _ in nil }))
        config["inbounds"] = [["tag": "flutter-vless-dns-upstream"]]
        XCTAssertNil(TunnelDNSPolicy.apply(to: &config, resolveIPv4: { _ in "203.0.113.7" }))
    }

    func testNestedXHTTPDownloadBootstrapAndCredentialsStayIntact() throws {
        var config: [String: Any] = ["outbounds": [[
            "protocol": "vless", "settings": ["vnext": [["address": "primary.example", "port": 443, "users": [["id": "test-uuid", "encryption": "preserve-exactly"]]]]],
            "streamSettings": ["network": "xhttp", "xhttpSettings": ["extra": ["downloadSettings": [
                "address": "download.example", "port": 443, "sockopt": ["tcpKeepAliveIdle": 30]
            ]]]]
        ]]]
        var resolved: [String] = []
        XCTAssertNotNil(TunnelDNSPolicy.apply(to: &config, resolveIPv4: { host in
            resolved.append(host)
            return "203.0.113.7"
        }))
        XCTAssertEqual(Set(resolved), ["primary.example", "download.example"])
        let output = String(decoding: try JSONSerialization.data(withJSONObject: config), as: UTF8.self)
        XCTAssertTrue(output.contains("preserve-exactly"))
        XCTAssertTrue(output.contains("test-uuid"))
        XCTAssertTrue(output.contains("tcpKeepAliveIdle"))
        XCTAssertEqual(output.components(separatedBy: "ForceIP").count - 1, 2)
    }

    func testDNSAddressCannotBeExcludedButServerAndLANBypassesRemain() {
        for subnet in ["198.18.0.2/32", "198.18.0.0/16", "0.0.0.0/0"] {
            XCTAssertFalse(TunnelDNSPolicy.allowsRouteExclusions([subnet]))
        }
        XCTAssertTrue(TunnelDNSPolicy.allowsRouteExclusions(["203.0.113.7/32", "192.168.0.0/16", "1.1.1.1/32"]))
    }

    func testPartialDNSSettingsUseProtectedDefaultResolver() throws {
        var config: [String: Any] = [
            "dns": ["queryStrategy": "UseIPv4"],
            "outbounds": [["tag": "proxy", "protocol": "vless", "settings": [
                "vnext": [["address": "vpn.example", "port": 443, "users": []]]
            ]]]
        ]

        let addresses = try XCTUnwrap(TunnelDNSPolicy.apply(to: &config, resolveIPv4: { _ in "203.0.113.7" }))

        XCTAssertEqual(addresses, ["203.0.113.7"])
        XCTAssertEqual((config["dns"] as? [String: Any])?["servers"] as? [String], ["tcp://1.1.1.1"])
    }

    func testWireGuardPeersBootstrapWithoutChangingKeysOrEndpoints() throws {
        let settings: [String: Any] = ["secretKey": "private-key-marker", "peers": [
            ["endpoint": "wg.example:51820", "publicKey": "public-key-marker"],
            ["endpoint": "[2001:db8::1]:51820", "publicKey": "second-key"]
        ]]
        var config: [String: Any] = ["outbounds": [["protocol": "wireguard", "settings": settings]]]
        XCTAssertEqual(TunnelDNSPolicy.apply(to: &config, resolveIPv4: { _ in "203.0.113.7" }),
                       ["2001:db8::1", "203.0.113.7"])
        let outbounds = try XCTUnwrap(config["outbounds"] as? [[String: Any]])
        XCTAssertEqual(outbounds[0]["settings"] as? NSDictionary, settings as NSDictionary)
    }

    func testAbsoluteDNSNameMatchesXrayHostLookup() throws {
        var config: [String: Any] = ["outbounds": [["protocol": "http", "settings": ["address": "Proxy.Example.", "port": 443]]]]
        XCTAssertNotNil(TunnelDNSPolicy.apply(to: &config, resolveIPv4: { _ in "203.0.113.7" }))
        let dns = try XCTUnwrap(config["dns"] as? [String: Any])
        XCTAssertEqual(dns["hosts"] as? [String: String], ["proxy.example": "203.0.113.7"])
        let outbounds = try XCTUnwrap(config["outbounds"] as? [[String: Any]])
        XCTAssertEqual((outbounds[0]["settings"] as? [String: Any])?["address"] as? String, "Proxy.Example.")
    }

    func testModernEndpointAndExtraPrecedenceMatchXray() throws {
        var config: [String: Any] = ["outbounds": [[
            "protocol": "HTTP", "settings": ["address": "active.example", "port": 443,
                                                "servers": [["address": "ignored.example", "port": 443]]],
            "streamSettings": ["xhttpSettings": [
                "downloadSettings": ["address": "ignored-download.example"],
                "extra": ["downloadSettings": ["address": "active-download.example"]]
            ]]
        ]]]
        var resolved: [String] = []
        XCTAssertNotNil(TunnelDNSPolicy.apply(to: &config, resolveIPv4: { host in
            resolved.append(host)
            return host.hasPrefix("active") ? "203.0.113.7" : nil
        }))
        XCTAssertEqual(Set(resolved), ["active.example", "active-download.example"])
    }
}
