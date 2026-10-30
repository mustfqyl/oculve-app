import Foundation
import XCTest
@testable import flutter_vless_tunnel_support

final class TunnelDpiRuntimeTests: XCTestCase {
    func testAutomaticAndPinnedProfilePolicy() throws {
        XCTAssertEqual(TunnelDpiRuntime.selectedProfile(data: Data("{}".utf8)), 4)
        for value in 0...6 {
            XCTAssertEqual(TunnelDpiRuntime.selectedProfile(data: Data("{\"oculveDpiProfile\":\(value)}".utf8)), value)
        }
        for value in ["-1", "7", "true", "1.5", "\"automatic\""] {
            XCTAssertNil(TunnelDpiRuntime.selectedProfile(data: Data("{\"oculveDpiProfile\":\(value)}".utf8)))
        }
    }

    func testPinnedProfileRunsAloneAndAutomaticLadderStartsWithLearnedProfile() {
        let interfaceName = "test-\(UUID().uuidString)"
        let key = "oculve.dpi.strategy.v1.\(interfaceName)"
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let ladder = [4, 5, 6, 0, 1, 2, 3]
        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(selected: 4, interfaceName: interfaceName), ladder)
        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(selected: 2, interfaceName: interfaceName), [2])
        TunnelDpiRuntime.save(profile: 5, interfaceName: interfaceName)
        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(selected: 4, interfaceName: interfaceName), [5, 4, 6, 0, 1, 2, 3])
        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(selected: 2, interfaceName: interfaceName), [2])
        TunnelDpiRuntime.invalidate(profile: 5, interfaceName: interfaceName)
        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(selected: 4, interfaceName: interfaceName), ladder)

        TunnelDpiRuntime.save(profile: 7, interfaceName: interfaceName)
        XCTAssertNil(UserDefaults.standard.object(forKey: key))
        UserDefaults.standard.set(99, forKey: key)
        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(selected: 4, interfaceName: interfaceName), ladder)
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

    func testNetworkHashIsStableOpaqueAndNetworkScoped() {
        let base = TunnelDpiRuntime.networkHash(interfaceName: "en0", network: "192.168.1.1",
                                                isExpensive: false, isConstrained: false,
                                                supportsIPv4: true, supportsIPv6: true)
        XCTAssertEqual(base, TunnelDpiRuntime.networkHash(interfaceName: "en0", network: "192.168.1.1",
                                                          isExpensive: false, isConstrained: false,
                                                          supportsIPv4: true, supportsIPv6: true))
        XCTAssertFalse(base.isEmpty)
        XCTAssertTrue(base.allSatisfy { $0.isHexDigit })
        XCTAssertFalse(base.contains("192.168.1.1"), "the network address must not survive the hash")
        XCTAssertNotEqual(base, TunnelDpiRuntime.networkHash(interfaceName: "en0", network: "192.168.1.2",
                                                             isExpensive: false, isConstrained: false,
                                                             supportsIPv4: true, supportsIPv6: true))
        XCTAssertNotEqual(base, TunnelDpiRuntime.networkHash(interfaceName: "en0", network: nil,
                                                             isExpensive: false, isConstrained: false,
                                                             supportsIPv4: true, supportsIPv6: true))
        XCTAssertNotEqual(base, TunnelDpiRuntime.networkHash(interfaceName: "en0", network: "192.168.1.1",
                                                             isExpensive: true, isConstrained: false,
                                                             supportsIPv4: true, supportsIPv6: true))
        XCTAssertNotEqual(base, TunnelDpiRuntime.networkHash(interfaceName: "pdp_ip0", network: "192.168.1.1",
                                                             isExpensive: false, isConstrained: false,
                                                             supportsIPv4: true, supportsIPv6: true))
        XCTAssertNotEqual(base, TunnelDpiRuntime.networkHash(interfaceName: "en0", network: "192.168.1.1",
                                                             isExpensive: false, isConstrained: false,
                                                             supportsIPv4: true, supportsIPv6: false))
    }

    func testIpv4NetworkKeepsTheSubnetAndDropsTheHostPart() {
        // Loopback is 127.0.0.1/8 on every Apple platform.
        XCTAssertEqual(TunnelDpiRuntime.ipv4Network(interfaceName: "lo0"), "127.0.0.0/8")
        XCTAssertNil(TunnelDpiRuntime.ipv4Network(interfaceName: "oculve-no-such-interface"))
    }

    func testLearnedStrategyUsesTheNetworkKeyAndFallsBackToTheLegacyKey() {
        let interfaceName = "test-\(UUID().uuidString)"
        let identity = TunnelDpiRuntime.NetworkIdentity(interfaceName: interfaceName, hash: "abc123")
        let otherNetwork = TunnelDpiRuntime.NetworkIdentity(interfaceName: interfaceName, hash: "def456")
        defer { TunnelDpiRuntime.invalidate(identity: identity) }

        XCTAssertNil(TunnelDpiRuntime.learnedProfile(identity: identity))
        XCTAssertNil(TunnelDpiRuntime.learnedGroup(identity: identity))
        XCTAssertEqual(TunnelDpiRuntime.strategyKey(identity),
                       "oculve.dpi.strategy.v1.\(interfaceName).abc123")
        TunnelDpiRuntime.save(profile: 5, identity: identity)
        TunnelDpiRuntime.save(group: 3, identity: identity)
        XCTAssertEqual(TunnelDpiRuntime.learnedProfile(identity: identity), 5)
        XCTAssertEqual(TunnelDpiRuntime.learnedGroup(identity: identity), 3)
        XCTAssertNil(TunnelDpiRuntime.learnedProfile(identity: otherNetwork))
        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(selected: 4, identity: identity).first, 5)

        // Pre-hash installs kept one strategy per interface; read it as a fallback.
        UserDefaults.standard.set(6, forKey: "oculve.dpi.strategy.v1.\(interfaceName)")
        XCTAssertEqual(TunnelDpiRuntime.learnedProfile(identity: otherNetwork), 6)
        XCTAssertEqual(TunnelDpiRuntime.profileCandidates(selected: 4, identity: otherNetwork).first, 6)
        XCTAssertEqual(TunnelDpiRuntime.learnedProfile(identity: identity), 5,
                       "a network key must win over the legacy key")

        // A malformed hash degrades to the legacy key instead of inventing one.
        let legacyOnly = TunnelDpiRuntime.NetworkIdentity(interfaceName: interfaceName, hash: "not-hex!")
        XCTAssertEqual(TunnelDpiRuntime.strategyKey(legacyOnly),
                       "oculve.dpi.strategy.v1.\(interfaceName)")
        XCTAssertEqual(TunnelDpiRuntime.learnedProfile(identity: legacyOnly), 6)
    }

    func testCorruptLearnedValuesAreRejected() {
        let interfaceName = "test-\(UUID().uuidString)"
        let identity = TunnelDpiRuntime.NetworkIdentity(interfaceName: interfaceName, hash: "123456")
        defer { TunnelDpiRuntime.invalidate(identity: identity) }
        let defaults = UserDefaults.standard
        let key = TunnelDpiRuntime.strategyKey(identity)
        for value in ["5", true, 7, -1, 2.5] as [Any] {
            defaults.set(value, forKey: key)
            XCTAssertNil(TunnelDpiRuntime.learnedProfile(identity: identity), "\(value)")
        }
        defaults.set(4, forKey: key)
        XCTAssertEqual(TunnelDpiRuntime.learnedProfile(identity: identity), 4)

        let groupKey = TunnelDpiRuntime.groupKey(identity)
        for value in ["1", true, 5, -1, 1.5] as [Any] {
            defaults.set(value, forKey: groupKey)
            XCTAssertNil(TunnelDpiRuntime.learnedGroup(identity: identity), "\(value)")
        }
        defaults.set(2, forKey: groupKey)
        XCTAssertEqual(TunnelDpiRuntime.learnedGroup(identity: identity), 2)
    }

    func testGroupLearningNeedsEnoughRealResponses() {
        XCTAssertNil(DpiStrategyLearner.bestGroup([]))
        XCTAssertNil(DpiStrategyLearner.bestGroup([
            TunnelDpiRuntime.GroupStat(group: 0, okCount: 2, failCount: 0)
        ]), "a single probe is not evidence")
        XCTAssertEqual(DpiStrategyLearner.bestGroup([
            TunnelDpiRuntime.GroupStat(group: 0, okCount: 10, failCount: 0),
            TunnelDpiRuntime.GroupStat(group: 1, okCount: 3, failCount: 0)
        ])?.group, 0)
        XCTAssertEqual(DpiStrategyLearner.bestGroup([
            TunnelDpiRuntime.GroupStat(group: 0, okCount: 6, failCount: 5),
            TunnelDpiRuntime.GroupStat(group: 1, okCount: 3, failCount: 0)
        ])?.group, 1, "the response ratio decides, not the raw count")
        XCTAssertEqual(DpiStrategyLearner.bestGroup([
            TunnelDpiRuntime.GroupStat(group: 3, okCount: 3, failCount: 1),
            TunnelDpiRuntime.GroupStat(group: 1, okCount: 3, failCount: 1)
        ])?.group, 1, "ties keep the earlier preset")
    }

    func testLearnerStoresNothingWithoutARunningEngine() throws {
        try XCTSkipIf(TunnelDpiRuntime.isRunning(), "another test left the engine running")
        XCTAssertTrue(TunnelDpiRuntime.groupStats().isEmpty)
        XCTAssertEqual(TunnelDpiRuntime.exhaustedCount(), 0)
        let interfaceName = "test-\(UUID().uuidString)"
        let identity = TunnelDpiRuntime.NetworkIdentity(interfaceName: interfaceName, hash: "654321")
        defer { TunnelDpiRuntime.invalidate(identity: identity) }

        let learner = DpiStrategyLearner(identity: identity, profile: 4, queue: .main, interval: 60)
        XCTAssertFalse(learner.sample())
        learner.stop()
        XCTAssertNil(TunnelDpiRuntime.learnedProfile(identity: identity))
        XCTAssertNil(TunnelDpiRuntime.learnedGroup(identity: identity))

        // Pinned profiles have no alternative group to learn.
        let pinned = DpiStrategyLearner(identity: identity, profile: 0, queue: .main, interval: 60)
        XCTAssertFalse(pinned.sample())
        XCTAssertNil(TunnelDpiRuntime.learnedGroup(identity: identity))
    }

    func testInvalidStartArgumentsNeverReachTheEngine() {
        XCTAssertEqual(TunnelDpiRuntime.start(profile: 7, firstGroup: 0, interfaceName: "en0"), 0)
        XCTAssertEqual(TunnelDpiRuntime.start(profile: 4, firstGroup: 0, interfaceName: ""), 0)
        XCTAssertEqual(TunnelDpiRuntime.start(profile: 4, firstGroup: 99, interfaceName: ""), 0)
        XCTAssertEqual(TunnelDpiRuntime.start(profile: -1, interfaceName: "en0"), 0)
    }

}
