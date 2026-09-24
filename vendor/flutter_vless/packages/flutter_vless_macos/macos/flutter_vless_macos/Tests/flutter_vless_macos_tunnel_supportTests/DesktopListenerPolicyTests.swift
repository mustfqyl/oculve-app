import XCTest
import flutter_vless_macos_privacy
@testable import flutter_vless_macos_tunnel_support

final class DesktopListenerPolicyTests: XCTestCase {
    private let base: [String: Any] = [
        "inbounds": [["protocol": "socks", "listen": "127.0.0.1", "port": 10808]],
        "outbounds": [["protocol": "http", "tag": "proxy", "settings": ["address": "127.0.0.1", "port": 18090]]]
    ]
    func testEveryAdditionalInboundIsRejectedBeforeAndDuringPreparation() throws {
        let credentials = try LocalProxyCredentials(username: "test", password: "test-password")
        for kind in ["dokodemo-door", "mixed", "http", "socks", "tun", "unknown"] {
            var json = base
            var listeners = json["inbounds"] as! [[String: Any]]
            listeners.append(["protocol": kind, "listen": "127.0.0.1", "port": 18081])
            json["inbounds"] = listeners
            let data = try JSONSerialization.data(withJSONObject: json)
            XCTAssertThrowsError(try LocalProxyAccessPolicy.validateVPN(configData: data), kind)
            XCTAssertNil(TunnelXrayConfigPreparer.prepare(jsonData: data, credentials: credentials), kind)
        }
        XCTAssertNotNil(TunnelXrayConfigPreparer.prepare(jsonData: try JSONSerialization.data(withJSONObject: base), credentials: credentials))
    }
    func testManagementAliasesAreRemovedAndAmbiguityFails() throws {
        for field in ["api", "Api", "API", "aPI"] {
            var json = base
            json[field] = ["listen": "127.0.0.1:18081", "services": ["HandlerService", "RoutingService"]]
            XCTAssertTrue(XrayPrivacyConfig.apply(to: &json))
            XCTAssertNil(json["api"]); XCTAssertNil(json[field])
            XCTAssertNotNil(json["stats"])
            let policy = json["policy"] as! [String: Any]
            XCTAssertEqual((policy["system"] as! [String: Any])["statsOutboundUplink"] as? Bool, true)
        }
        var ambiguous = base; ambiguous["api"] = [:] as [String: Any]; ambiguous["API"] = [:] as [String: Any]
        XCTAssertFalse(XrayPrivacyConfig.apply(to: &ambiguous))
    }

    func testPolicyLevelSettingsSurvivePrivacyAndTunnelPreparation() throws {
        let credentials = try LocalProxyCredentials(username: "test", password: "test-password")
        var json = base
        json["policy"] = [
            "levels": ["0": ["handshake": 45, "statsUserOnline": true]],
            "system": ["statsOutboundUplink": false]
        ] as [String: Any]
        XCTAssertTrue(XrayPrivacyConfig.apply(to: &json))
        let policy = json["policy"] as! [String: Any]
        XCTAssertEqual((policy["levels"] as! [String: [String: Any]])["0"]?["handshake"] as? Int, 45)
        XCTAssertEqual((policy["system"] as! [String: Any])["statsOutboundUplink"] as? Bool, false)

        let data = try JSONSerialization.data(withJSONObject: json)
        let prepared = try XCTUnwrap(TunnelXrayConfigPreparer.prepare(jsonData: data, credentials: credentials))
        let preparedJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: prepared.data) as? [String: Any])
        let preparedPolicy = preparedJSON["policy"] as! [String: Any]
        XCTAssertEqual((preparedPolicy["levels"] as! [String: [String: Any]])["0"]?["statsUserOnline"] as? Bool, true)
        XCTAssertEqual((preparedPolicy["system"] as! [String: Any])["statsOutboundUplink"] as? Bool, false)
    }
}
