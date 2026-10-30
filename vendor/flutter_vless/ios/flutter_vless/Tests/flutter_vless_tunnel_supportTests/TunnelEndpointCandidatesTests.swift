import XCTest
import Darwin
@testable import flutter_vless_tunnel_support

final class TunnelEndpointCandidatesTests: XCTestCase {
    // MARK: filter

    func testFilterKeepsResolverOrderAndDropsDuplicates() {
        XCTAssertEqual(
            TunnelEndpointCandidates.filter(["203.0.113.9", "198.51.100.4", "203.0.113.9", "192.0.2.1"]),
            ["203.0.113.9", "198.51.100.4", "192.0.2.1"])
    }

    func testFilterDropsAddressesThatCanNeverBeAServer() {
        let rejected = ["0.0.0.0", "127.0.0.1", "169.254.1.1", "224.0.0.1", "239.255.255.250",
                        "255.255.255.255", "198.18.0.1", "198.19.255.254", "not-an-ip", "::1",
                        "2001:db8::1", "999.1.1.1", ""]
        XCTAssertEqual(TunnelEndpointCandidates.filter(rejected + ["203.0.113.9"]), ["203.0.113.9"])
        // The tunnel range ends at 198.19.255.255; its neighbours are ordinary.
        XCTAssertEqual(TunnelEndpointCandidates.filter(["198.17.255.255", "198.20.0.0"]),
                       ["198.17.255.255", "198.20.0.0"])
    }

    func testFilterKeepsTenAddressesAndCapsAPathologicalAnswer() {
        let ten = (1...10).map { "203.0.113.\($0)" }
        XCTAssertEqual(TunnelEndpointCandidates.filter(ten), ten)
        let many = (1...40).map { "203.0.113.\($0)" }
        let filtered = TunnelEndpointCandidates.filter(many)
        XCTAssertEqual(filtered.count, TunnelEndpointCandidates.maxCandidates)
        XCTAssertEqual(filtered.first, "203.0.113.1")
    }

    func testTheRaceReachesALiveAddressBehindSeveralDeadOnes() {
        // Nine dead servers, the tenth alive: the default race must get there.
        let all = (1...10).map { "203.0.113.\($0)" }
        let started = Date()
        let winner = TunnelEndpointCandidates.firstReachable(all, port: 443) { address, _, _ in
            address == "203.0.113.10"
        }
        XCTAssertEqual(winner, "203.0.113.10")
        XCTAssertLessThan(Date().timeIntervalSince(started), TunnelEndpointCandidates.raceCapSeconds)
    }

    // MARK: endpointPort

    func testEndpointPortFindsTheServerPortForVlessTrojanAndFlatSettings() {
        func port(_ outbound: String, host: String = "Node.Example.com") -> Int? {
            let json = #"{"outbounds":[{"protocol":"freedom","settings":{}},"# + outbound + "]}"
            return TunnelEndpointCandidates.endpointPort(configJSON: Data(json.utf8), host: host)
        }
        XCTAssertEqual(port(#"{"protocol":"vless","settings":{"vnext":[{"address":"node.example.com","port":443}]}}"#), 443)
        XCTAssertEqual(port(#"{"protocol":"trojan","settings":{"servers":[{"address":"node.example.com.","port":"8443"}]}}"#), 8443)
        XCTAssertEqual(port(#"{"protocol":"vless","settings":{"address":"node.example.com","port":2053}}"#), 2053)
        XCTAssertNil(port(#"{"protocol":"vless","settings":{"vnext":[{"address":"other.example.com","port":443}]}}"#))
        XCTAssertNil(port(#"{"protocol":"vless","settings":{"vnext":[{"address":"node.example.com","port":0}]}}"#))
        XCTAssertNil(TunnelEndpointCandidates.endpointPort(configJSON: Data("{}".utf8), host: "x"))
        XCTAssertNil(TunnelEndpointCandidates.endpointPort(configJSON: Data("nope".utf8), host: "x"))
    }

    // MARK: firstReachable

    func testTheFirstAddressWinsWhenItAnswers() {
        let winner = TunnelEndpointCandidates.firstReachable(
            ["203.0.113.1", "203.0.113.2", "203.0.113.3"], port: 443,
            stagger: 0.05, cap: 1) { _, _, _ in true }
        XCTAssertEqual(winner, "203.0.113.1")
    }

    func testADeadFirstAddressIsSkippedWithoutWaitingForItsTimeout() {
        let started = Date()
        let winner = TunnelEndpointCandidates.firstReachable(
            ["203.0.113.1", "203.0.113.2", "203.0.113.3"], port: 443,
            stagger: 0.05, cap: 2) { address, _, _ in
            // The first one hangs for a long time, like a blackholed server.
            if address == "203.0.113.1" { Thread.sleep(forTimeInterval: 1.5); return false }
            return address == "203.0.113.2"
        }
        XCTAssertEqual(winner, "203.0.113.2")
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.8,
                          "must not wait for the dead address's own timeout")
    }

    func testAnImmediateFailureStartsTheNextAttemptAtOnce() {
        let started = Date()
        let winner = TunnelEndpointCandidates.firstReachable(
            ["203.0.113.1", "203.0.113.2"], port: 443,
            stagger: 1, cap: 3) { address, _, _ in address == "203.0.113.2" }
        XCTAssertEqual(winner, "203.0.113.2")
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5,
                          "a refused connection must not cost a full stagger")
    }

    func testNothingReachableReturnsNilWithinTheCap() {
        let started = Date()
        let winner = TunnelEndpointCandidates.firstReachable(
            ["203.0.113.1", "203.0.113.2"], port: 443,
            stagger: 0.05, cap: 0.4) { _, _, _ in Thread.sleep(forTimeInterval: 5); return false }
        XCTAssertNil(winner)
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.0)
    }

    func testAtMostTheParallelLimitIsInFlight() {
        let lock = NSLock()
        var inFlight = 0
        var peak = 0
        _ = TunnelEndpointCandidates.firstReachable(
            (1...6).map { "203.0.113.\($0)" }, port: 443,
            stagger: 0.01, cap: 1, parallel: 2) { _, _, _ in
            lock.lock(); inFlight += 1; peak = max(peak, inFlight); lock.unlock()
            Thread.sleep(forTimeInterval: 0.1)
            lock.lock(); inFlight -= 1; lock.unlock()
            return false
        }
        XCTAssertLessThanOrEqual(peak, 2)
    }

    func testEmptyInputHasNoWinner() {
        XCTAssertNil(TunnelEndpointCandidates.firstReachable([], port: 443) { _, _, _ in true })
    }

    // MARK: rebind / demoting

    private let prepared = Data(#"""
    {"dns":{"hosts":{"node.example.com":"203.0.113.1","doh.example.net":"1.1.1.1"},"servers":["tcp://1.1.1.1"]},
     "outbounds":[{"protocol":"vless","settings":{"vnext":[{"address":"node.example.com","port":443}]}}]}
    """#.utf8)

    func testRebindChangesOnlyTheNamedHostsPinnedAddress() throws {
        let rebound = try XCTUnwrap(TunnelEndpointCandidates.rebind(
            configJSON: prepared, host: "Node.Example.com.", address: "203.0.113.2"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: rebound) as? [String: Any])
        let dns = try XCTUnwrap(json["dns"] as? [String: Any])
        let hosts = try XCTUnwrap(dns["hosts"] as? [String: String])
        XCTAssertEqual(hosts["node.example.com"], "203.0.113.2")
        XCTAssertEqual(hosts["doh.example.net"], "1.1.1.1")
        XCTAssertEqual(dns["servers"] as? [String], ["tcp://1.1.1.1"])
        XCTAssertNotNil(json["outbounds"])
    }

    func testRebindRefusesWhatItCannotPinSafely() {
        XCTAssertNil(TunnelEndpointCandidates.rebind(configJSON: prepared, host: "node.example.com", address: "not-an-ip"))
        XCTAssertNil(TunnelEndpointCandidates.rebind(configJSON: prepared, host: "node.example.com", address: "2001:db8::1"))
        XCTAssertNil(TunnelEndpointCandidates.rebind(configJSON: prepared, host: "unknown.example.com", address: "203.0.113.2"))
        XCTAssertNil(TunnelEndpointCandidates.rebind(configJSON: Data("{}".utf8), host: "node.example.com", address: "203.0.113.2"))
    }

    func testDemotingMovesTheFailedAddressToTheBack() {
        let order = ["203.0.113.1", "203.0.113.2", "203.0.113.3"]
        XCTAssertEqual(TunnelEndpointCandidates.demoting("203.0.113.1", in: order),
                       ["203.0.113.2", "203.0.113.3", "203.0.113.1"])
        XCTAssertEqual(TunnelEndpointCandidates.demoting("203.0.113.9", in: order), order)
        XCTAssertEqual(TunnelEndpointCandidates.demoting("203.0.113.1", in: ["203.0.113.1"]), ["203.0.113.1"])
    }

    // MARK: tcpConnect against real sockets

    private func listener() throws -> (fd: Int32, port: Int) {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        XCTAssertGreaterThanOrEqual(fd, 0)
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = UInt32(0x7f000001).bigEndian
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        XCTAssertEqual(bound, 0)
        XCTAssertEqual(listen(fd, 4), 0)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        return (fd, Int(UInt16(bigEndian: address.sin_port)))
    }

    func testTcpConnectSucceedsOnAListeningPortAndFailsOnAClosedOne() throws {
        let open = try listener()
        defer { close(open.fd) }
        XCTAssertTrue(TunnelEndpointCandidates.tcpConnect(address: "127.0.0.1", port: open.port, timeout: 1))

        let closed = try listener()
        close(closed.fd)
        XCTAssertFalse(TunnelEndpointCandidates.tcpConnect(address: "127.0.0.1", port: closed.port, timeout: 1))
        XCTAssertFalse(TunnelEndpointCandidates.tcpConnect(address: "not-an-ip", port: 443, timeout: 1))
    }

    func testTheRaceFindsTheLivePortAmongRealSockets() throws {
        let live = try listener()
        defer { close(live.fd) }
        let dead = try listener()
        close(dead.fd)
        // Same address, different ports: the closed port refuses at once, so
        // the race must move on and land on the listening one.
        let ports = ["a": dead.port, "b": live.port]
        let winner = TunnelEndpointCandidates.firstReachable(["a", "b"], port: 0, stagger: 0.05, cap: 1) { name, _, timeout in
            TunnelEndpointCandidates.tcpConnect(address: "127.0.0.1", port: ports[name]!, timeout: timeout)
        }
        XCTAssertEqual(winner, "b")
    }
}
