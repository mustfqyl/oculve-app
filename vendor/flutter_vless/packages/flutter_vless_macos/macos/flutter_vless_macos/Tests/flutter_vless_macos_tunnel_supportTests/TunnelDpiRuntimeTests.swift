import Foundation
import XCTest
@testable import flutter_vless_macos_tunnel_support

final class TunnelDpiRuntimeTests: XCTestCase {
    func testAutomaticAndPinnedProfilePolicy() throws {
        XCTAssertEqual(TunnelDpiRuntime.selectedProfile(data: Data("{}".utf8)), 4)
        for value in 0...4 {
            XCTAssertEqual(TunnelDpiRuntime.selectedProfile(data: Data("{\"oculveDpiProfile\":\(value)}".utf8)), value)
        }
        for value in ["-1", "5", "true", "1.5", "\"automatic\""] {
            XCTAssertNil(TunnelDpiRuntime.selectedProfile(data: Data("{\"oculveDpiProfile\":\(value)}".utf8)))
        }
    }

    func testCachedProfileRunsFirstAndFailureRestoresLightestFirstScan() {
        let interfaceName = "test-\(UUID().uuidString)"
        let key = "oculve.dpi.strategy.v1.\(interfaceName)"
        defer { UserDefaults.standard.removeObject(forKey: key) }

        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(interfaceName: interfaceName), [0, 1, 2, 3])
        TunnelDpiRuntime.save(profile: 2, interfaceName: interfaceName)
        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(interfaceName: interfaceName), [2, 0, 1, 3])
        TunnelDpiRuntime.invalidate(profile: 2, interfaceName: interfaceName)
        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(interfaceName: interfaceName), [0, 1, 2, 3])

        UserDefaults.standard.set(99, forKey: key)
        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(interfaceName: interfaceName), [0, 1, 2, 3])
    }

    func testDpiConfigUsesDynamicLocalSocksPortAndPhysicalDirectInterface() throws {
        let source = try JSONSerialization.data(withJSONObject: [
            "outbounds": [
                ["tag": "byedpi", "protocol": "socks", "settings": [
                    "servers": [["address": "127.0.0.1", "port": 65535]]
                ]],
                ["tag": "direct", "protocol": "freedom"],
                ["tag": "block", "protocol": "blackhole"]
            ],
            "routing": ["rules": [["type": "field", "domain": ["domain:example.com"],
                                     "outboundTag": "byedpi"]]
            ]
        ])
        XCTAssertTrue(TunnelDpiRuntime.isDpiConfig(source))
        let result = try XCTUnwrap(TunnelDpiRuntime.config(
            data: source, localProxyPort: 41239, interfaceName: "en0"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: result) as? [String: Any])
        let inbounds = try XCTUnwrap(config["inbounds"] as? [[String: Any]])
        XCTAssertEqual(inbounds.count, 1)
        XCTAssertEqual(inbounds[0]["tag"] as? String, "tun")
        XCTAssertEqual(inbounds[0]["protocol"] as? String, "tun")
        XCTAssertEqual(inbounds[0]["port"] as? Int, 0)
        let tunSettings = try XCTUnwrap(inbounds[0]["settings"] as? [String: Any])
        XCTAssertEqual(tunSettings["name"] as? String, "utun")
        XCTAssertEqual(tunSettings["MTU"] as? Int, 1500)
        let outbounds = try XCTUnwrap(config["outbounds"] as? [[String: Any]])
        let byedpi = try XCTUnwrap(outbounds.first { ($0["tag"] as? String) == "byedpi" })
        let settings = try XCTUnwrap(byedpi["settings"] as? [String: Any])
        let servers = try XCTUnwrap(settings["servers"] as? [[String: Any]])
        XCTAssertEqual(servers.first?["address"] as? String, "127.0.0.1")
        XCTAssertEqual(servers.first?["port"] as? Int, 41239)
        let direct = try XCTUnwrap(outbounds.first { ($0["tag"] as? String) == "direct" })
        let stream = try XCTUnwrap(direct["streamSettings"] as? [String: Any])
        let sockopt = try XCTUnwrap(stream["sockopt"] as? [String: Any])
        XCTAssertEqual(sockopt["interface"] as? String, "en0")
        XCTAssertTrue(outbounds.allSatisfy { ($0["protocol"] as? String) != "vless" })
    }

    func testDpiConfigRejectsRemoteOrAmbiguousLocalEndpoints() throws {
        let remote = try JSONSerialization.data(withJSONObject: [
            "outbounds": [["tag": "byedpi", "protocol": "socks", "settings": [
                "servers": [["address": "192.0.2.1", "port": 1080]]
            ]]]
        ])
        XCTAssertNil(TunnelDpiRuntime.config(data: remote, localProxyPort: 45678, interfaceName: "en0"))
        XCTAssertFalse(TunnelDpiRuntime.isDpiConfig(remote))

        let ambiguous = try JSONSerialization.data(withJSONObject: [
            "outbounds": [["tag": "byedpi", "protocol": "socks", "settings": [
                "servers": [
                    ["address": "127.0.0.1", "port": 1080],
                    ["address": "127.0.0.1", "port": 1081]
                ]
            ]]]
        ])
        XCTAssertNil(TunnelDpiRuntime.config(data: ambiguous, localProxyPort: 45678, interfaceName: "en0"))
        XCTAssertFalse(TunnelDpiRuntime.isDpiConfig(ambiguous))

        let mixed = try JSONSerialization.data(withJSONObject: [
            "outbounds": [
                ["tag": "byedpi", "protocol": "socks", "settings": [
                    "servers": [["address": "127.0.0.1", "port": 1080]]
                ]],
                ["tag": "proxy", "protocol": "vless"]
            ]
        ])
        XCTAssertFalse(TunnelDpiRuntime.isDpiConfig(mixed))
    }
}
