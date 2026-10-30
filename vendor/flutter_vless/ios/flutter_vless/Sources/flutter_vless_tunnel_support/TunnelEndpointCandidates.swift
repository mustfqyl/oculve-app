import Foundation
import Darwin

/// Picks which of a server's IPv4 addresses the tunnel talks to.
///
/// A server name can resolve to many addresses. The tunnel pins exactly one of
/// them in the Xray config, so that one must answer: if it is down or blocked,
/// the whole connection is dead even though the others work. This module
/// filters the resolver's answer, finds the first address that accepts a TCP
/// connection, and rewrites the pinned address when it stops answering.
///
/// Everything here is pure or takes its network call as a parameter, so the
/// selection logic is testable without a network. Addresses are never logged.
public enum TunnelEndpointCandidates {
    /// Every candidate needs a route exclusion (traffic to it leaves the tunnel
    /// instead of going through it). That is harmless when the addresses are the
    /// operator's own servers, which is the case for a server name with several
    /// A records; the cap only keeps a pathological answer from bloating the
    /// route list.
    public static let maxCandidates = 16
    /// Gap between starting attempts: a dead first address costs this, not a
    /// full connect timeout.
    public static let staggerSeconds: TimeInterval = 0.25
    /// Upper bound for the whole race. With the stagger above this reaches the
    /// twelfth address; a live first address still answers at once.
    public static let raceCapSeconds: TimeInterval = 3
    public static let maxParallelAttempts = 4

    public typealias Connect = (_ address: String, _ port: Int, _ timeout: TimeInterval) -> Bool

    /// IPv4 literals only, without addresses that can never be a server:
    /// loopback, unspecified, link-local, multicast, reserved, and the tunnel's
    /// own range. Duplicates are dropped; resolver order is kept.
    public static func filter(_ addresses: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for address in addresses {
            guard let value = ipv4Value(address), isUsableServerAddress(value),
                  seen.insert(address).inserted else { continue }
            result.append(address)
            if result.count == maxCandidates { break }
        }
        return result
    }

    private static func isUsableServerAddress(_ value: UInt32) -> Bool {
        let first = value >> 24
        if first == 0 || first == 127 || first >= 224 { return false } // this-net, loopback, multicast/reserved
        if value >> 16 == 0xA9FE { return false } // 169.254/16 link-local
        if value >> 17 == 0x6309 { return false } // 198.18.0.0/15 (the tunnel's own range)
        return true
    }

    private static func ipv4Value(_ address: String) -> UInt32? {
        var parsed = in_addr()
        guard address.withCString({ inet_pton(AF_INET, $0, &parsed) }) == 1 else { return nil }
        return UInt32(bigEndian: parsed.s_addr)
    }

    /// The port of the first proxy endpoint whose address is [host].
    public static func endpointPort(configJSON: Data, host: String) -> Int? {
        guard let config = (try? JSONSerialization.jsonObject(with: configJSON)) as? [String: Any],
              let outbounds = config["outbounds"] as? [[String: Any]] else { return nil }
        let wanted = hostKey(host)
        for outbound in outbounds {
            guard let settings = outbound["settings"] as? [String: Any] else { continue }
            var entries: [[String: Any]] = []
            if let vnext = settings["vnext"] as? [[String: Any]] {
                entries = vnext
            } else if let servers = settings["servers"] as? [[String: Any]] {
                entries = servers
            } else if settings["address"] is String {
                entries = [settings]
            }
            for entry in entries {
                guard let address = entry["address"] as? String, hostKey(address) == wanted else { continue }
                if let port = entry["port"] as? Int, (1...65535).contains(port) { return port }
                if let text = entry["port"] as? String, let port = Int(text), (1...65535).contains(port) {
                    return port
                }
            }
        }
        return nil
    }

    /// The first address in [candidates] that accepts a TCP connection, or nil
    /// when none does within [cap]. Attempts start [stagger] apart (sooner when
    /// an earlier one fails), at most [parallel] at a time, so a dead first
    /// address delays the connection by a fraction of a second.
    public static func firstReachable(
        _ candidates: [String],
        port: Int,
        stagger: TimeInterval = staggerSeconds,
        cap: TimeInterval = raceCapSeconds,
        parallel: Int = maxParallelAttempts,
        connect: @escaping Connect
    ) -> String? {
        guard !candidates.isEmpty else { return nil }
        let condition = NSCondition()
        var winner: String?
        var pending = 0
        var next = 0
        let end = Date().addingTimeInterval(cap)
        let queue = DispatchQueue(label: "com.oculve.endpoint-race", attributes: .concurrent)

        condition.lock()
        while winner == nil, Date() < end {
            if next < candidates.count, pending < max(1, parallel) {
                let address = candidates[next]
                next += 1
                pending += 1
                let budget = max(0.3, end.timeIntervalSinceNow)
                queue.async {
                    let reachable = connect(address, port, budget)
                    condition.lock()
                    pending -= 1
                    if reachable, winner == nil { winner = address }
                    condition.broadcast()
                    condition.unlock()
                }
                _ = condition.wait(until: min(end, Date().addingTimeInterval(stagger)))
                continue
            }
            if next >= candidates.count, pending == 0 { break }
            _ = condition.wait(until: end)
        }
        let result = winner
        condition.unlock()
        return result
    }

    /// Returns [config] with the pinned address of [host] replaced by [address].
    /// Nothing else changes, so a worker restart with it keeps every other
    /// policy exactly as prepared.
    public static func rebind(configJSON: Data, host: String, address: String) -> Data? {
        guard ipv4Value(address) != nil,
              var config = (try? JSONSerialization.jsonObject(with: configJSON)) as? [String: Any],
              var dns = config["dns"] as? [String: Any],
              var hosts = dns["hosts"] as? [String: Any] else { return nil }
        let key = hostKey(host)
        guard hosts[key] is String else { return nil }
        hosts[key] = address
        dns["hosts"] = hosts
        config["dns"] = dns
        return try? JSONSerialization.data(withJSONObject: config, options: [])
    }

    /// Moves [failed] to the back so the next pick is another address. With a
    /// single address the order cannot change.
    public static func demoting(_ failed: String, in order: [String]) -> [String] {
        guard order.count > 1, let index = order.firstIndex(of: failed) else { return order }
        var result = order
        result.remove(at: index)
        result.append(failed)
        return result
    }

    /// A plain TCP connect to [address]:[port], bounded by [timeout].
    public static func tcpConnect(address: String, port: Int, timeout: TimeInterval) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        let flags = fcntl(fd, F_GETFL, 0)
        guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0 else { return false }
        var target = sockaddr_in()
        target.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        target.sin_family = sa_family_t(AF_INET)
        target.sin_port = UInt16(port).bigEndian
        guard address.withCString({ inet_pton(AF_INET, $0, &target.sin_addr) }) == 1 else { return false }
        let status = withUnsafePointer(to: &target) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if status == 0 { return true }
        guard errno == EINPROGRESS else { return false }
        var descriptor = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let milliseconds = Int32(max(1, min(timeout, 30)) * 1000)
        guard poll(&descriptor, 1, milliseconds) > 0 else { return false }
        var error: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) == 0 else { return false }
        return error == 0
    }

    private static func hostKey(_ host: String) -> String {
        (host.hasSuffix(".") ? String(host.dropLast()) : host).lowercased()
    }
}
