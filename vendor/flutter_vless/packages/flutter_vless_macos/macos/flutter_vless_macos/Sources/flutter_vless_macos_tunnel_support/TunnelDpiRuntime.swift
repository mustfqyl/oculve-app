import Foundation
import CoreFoundation
import Network
import Darwin
import ByeDpiEngine

public enum TunnelDpiRuntime {
    private static let strategyKeyPrefix = "oculve.dpi.strategy.v1."
    private static let groupKeySuffix = ".group"
    static let automaticProfile = 4
    /// Automatic order: the profile 4 group chain, then pinned TLS-record profiles, then the older profiles 0-3.
    private static let automaticLadder = [4, 5, 6, 0, 1, 2, 3]
    /// A learned group may only reorder the next connection after this many
    /// real destination responses; one probe is not evidence.
    public static let minimumLearnedResponses = 3
    private static let groupStatCapacity = 8

    /// Opaque network identity: the interface name plus a hash of the path
    /// signature. The raw address is never stored or logged.
    public struct NetworkIdentity: Equatable {
        public let interfaceName: String
        public let hash: String

        public init(interfaceName: String, hash: String) {
            self.interfaceName = interfaceName
            self.hash = hash
        }
    }

    public struct GroupStat: Equatable {
        public let group: Int
        public let okCount: Int
        public let failCount: Int

        public init(group: Int, okCount: Int, failCount: Int) {
            self.group = group
            self.okCount = okCount
            self.failCount = failCount
        }
    }

    public static func interfaceName(in path: NWPath) -> String? {
        let physicalTypes: [NWInterface.InterfaceType] = [.wifi, .cellular, .wiredEthernet]
        for type in physicalTypes where path.usesInterfaceType(type) {
            if let interface = path.availableInterfaces.first(where: { $0.type == type }) {
                return interface.name
            }
        }
        return path.availableInterfaces.first(where: { physicalTypes.contains($0.type) })?.name
    }

    /// IPv4 network the interface is on, as "a.b.c.0/24". It is only an input
    /// to `networkHash`: the address itself is never stored or logged. Two
    /// networks behind the same interface name get different hashes; a DHCP
    /// lease change inside the same subnet does not.
    static func ipv4Network(interfaceName: String) -> String? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let address = entry.pointee.ifa_addr,
                  let mask = entry.pointee.ifa_netmask,
                  address.pointee.sa_family == UInt8(AF_INET),
                  String(cString: entry.pointee.ifa_name) == interfaceName else { continue }
            let host = UInt32(bigEndian: UnsafeRawPointer(address)
                .assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr.s_addr)
            let bits = UInt32(bigEndian: UnsafeRawPointer(mask)
                .assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr.s_addr)
            let network = host & bits
            return "\(network >> 24).\((network >> 16) & 0xff).\((network >> 8) & 0xff).\(network & 0xff)"
                + "/\(bits.nonzeroBitCount)"
        }
        return nil
    }

    /// FNV-1a over the path signature. Only the hex digest leaves this
    /// function, so a saved strategy can be keyed per network without keeping
    /// the address or the SSID (which is not available anyway).
    public static func networkHash(interfaceName: String, network: String?,
                                   isExpensive: Bool, isConstrained: Bool,
                                   supportsIPv4: Bool, supportsIPv6: Bool) -> String {
        let signature = [interfaceName, network ?? "-",
                         isExpensive ? "1" : "0", isConstrained ? "1" : "0",
                         supportsIPv4 ? "1" : "0", supportsIPv6 ? "1" : "0"].joined(separator: "|")
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in signature.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }

    public static func networkIdentity(in path: NWPath) -> NetworkIdentity? {
        guard let name = interfaceName(in: path) else { return nil }
        return NetworkIdentity(interfaceName: name, hash: networkHash(
            interfaceName: name,
            network: ipv4Network(interfaceName: name),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            supportsIPv4: path.supportsIPv4,
            supportsIPv6: path.supportsIPv6))
    }

    public static func currentNetworkIdentity() async throws -> NetworkIdentity {
        try await PhysicalInterfaceWaiter().wait()
    }

    public static func currentPhysicalInterface() async throws -> String {
        try await currentNetworkIdentity().interfaceName
    }

    public static func isDpiConfig(_ data: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outbounds = root["outbounds"] as? [[String: Any]],
              outbounds.allSatisfy({ ($0["protocol"] as? String) != "vless" }) else { return false }
        let matches = outbounds.filter {
            ($0["tag"] as? String) == "byedpi" && ($0["protocol"] as? String) == "socks"
        }
        guard matches.count == 1,
              let settings = matches[0]["settings"] as? [String: Any],
              let servers = settings["servers"] as? [[String: Any]], servers.count == 1,
              servers[0]["address"] as? String == "127.0.0.1",
              let port = servers[0]["port"] as? Int,
              (1...65535).contains(port) else { return false }
        return true
    }

    public static func selectedProfile(data: Data) -> Int? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let value = root["oculveDpiProfile"] else { return 4 }
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue == Double(number.intValue),
              (0...6).contains(number.intValue) else { return nil }
        return number.intValue
    }

    public static func start(profile: Int, interfaceName: String) -> Int {
        start(profile: profile, firstGroup: nil, interfaceName: interfaceName)
    }

    /// `firstGroup` rotates the profile 4 automatic chain so the strategy that
    /// last carried real traffic runs first. Pinned profiles ignore it and
    /// nil/-1 keeps the built-in order.
    public static func start(profile: Int, firstGroup: Int?, interfaceName: String) -> Int {
        guard (0...6).contains(profile), !interfaceName.isEmpty else { return 0 }
        let group = Int32(firstGroup.map { (0...4).contains($0) ? $0 : -1 } ?? -1)
        return Int(interfaceName.withCString {
            byedpi_engine_start_grouped(Int32(profile), group, nil, $0)
        })
    }

    public static func stop() -> Bool {
        byedpi_engine_stop() == 1
    }

    public static func isRunning() -> Bool {
        byedpi_engine_is_running() == 1
    }

    /// Per-group counters of the running engine. Automatic runs report the five
    /// presets in preset order regardless of the rotation in use. Empty while
    /// no engine runs.
    public static func groupStats() -> [GroupStat] {
        var ok = [Int32](repeating: 0, count: groupStatCapacity)
        var fail = [Int32](repeating: 0, count: groupStatCapacity)
        let count = ok.withUnsafeMutableBufferPointer { okBuffer in
            fail.withUnsafeMutableBufferPointer { failBuffer in
                byedpi_engine_group_stats(okBuffer.baseAddress, failBuffer.baseAddress,
                                          Int32(okBuffer.count))
            }
        }
        guard count > 0, Int(count) <= ok.count else { return [] }
        return (0..<Int(count)).map {
            GroupStat(group: $0, okCount: Int(ok[$0]), failCount: Int(fail[$0]))
        }
    }

    /// How often the automatic chain ran out of untried groups.
    public static func exhaustedCount() -> Int {
        Int(byedpi_engine_exhausted())
    }

    /// NetworkExtension owns the utun socket. Give its descriptor to Xray's
    /// native TUN inbound instead of copying packets through HEV/tun2socks.
    public static func packetTunnelFileDescriptor() -> Int32? {
        let descriptorLimit = min(Int(getdtablesize()), 1025)
        guard descriptorLimit > 0 else { return nil }
        for descriptor in 0..<descriptorLimit where isTunnelDescriptor(Int32(descriptor)) {
            return Int32(descriptor)
        }
        return nil
    }

    /// True only while `descriptor` is an open utun control socket. Closed,
    /// reused or non-utun descriptors all return false.
    public static func isTunnelDescriptor(_ descriptor: Int32) -> Bool {
        guard descriptor >= 0 else { return false }
        var interfaceName = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        var length = socklen_t(interfaceName.count)
        let result = interfaceName.withUnsafeMutableBufferPointer { buffer in
            getsockopt(descriptor, 2, 2, buffer.baseAddress, &length)
        }
        return result == 0 && String(cString: interfaceName).hasPrefix("utun")
    }

    /// Outcome of a descriptor number after Xray stopped. Only `.tunnel` may be
    /// closed: a number that is open but no longer a utun socket belongs to
    /// another file that was handed the same number.
    public enum DescriptorState: String {
        case tunnel
        case reused
        case closed
    }

    public static func descriptorState(_ descriptor: Int32) -> DescriptorState {
        if isTunnelDescriptor(descriptor) { return .tunnel }
        guard descriptor >= 0, fcntl(descriptor, F_GETFD) != -1 else { return .closed }
        return .reused
    }

    /// Closes a duplicate handed to Xray only if Xray left it open. Returns
    /// true when this call closed it. A descriptor that is no longer a utun
    /// socket is never closed, since its number may belong to another file.
    @discardableResult
    public static func closeIfStillTunnel(_ descriptor: Int32) -> Bool {
        guard descriptorState(descriptor) == .tunnel else { return false }
        return close(descriptor) == 0
    }

    /// A pinned profile runs alone so an explicit choice is never replaced.
    /// Automatic walks the ladder, starting with the profile that last carried
    /// real traffic on this network.
    public static func profileCandidates(selected: Int, identity: NetworkIdentity) -> [Int] {
        guard selected == automaticProfile else { return [selected] }
        let preferred = learnedProfile(identity: identity).flatMap {
            automaticLadder.contains($0) ? $0 : nil
        }
        return (preferred.map { [$0] } ?? []) + automaticLadder.filter { $0 != preferred }
    }

    public static func profileCandidates(selected: Int, interfaceName: String) -> [Int] {
        profileCandidates(selected: selected,
                          identity: NetworkIdentity(interfaceName: interfaceName, hash: ""))
    }

    public static func strategyKey(_ identity: NetworkIdentity) -> String {
        guard !identity.hash.isEmpty, identity.hash.allSatisfy({ $0.isHexDigit }) else {
            return strategyKeyPrefix + identity.interfaceName
        }
        return strategyKeyPrefix + identity.interfaceName + "." + identity.hash
    }

    public static func groupKey(_ identity: NetworkIdentity) -> String {
        strategyKey(identity) + groupKeySuffix
    }

    public static func learnedProfile(identity: NetworkIdentity) -> Int? {
        let defaults = UserDefaults.standard
        if let value = validProfile(defaults.object(forKey: strategyKey(identity))) { return value }
        // Pre-hash installs stored one strategy per interface.
        return validProfile(defaults.object(forKey: strategyKeyPrefix + identity.interfaceName))
    }

    public static func learnedGroup(identity: NetworkIdentity) -> Int? {
        let defaults = UserDefaults.standard
        if let value = validGroup(defaults.object(forKey: groupKey(identity))) { return value }
        return validGroup(defaults.object(forKey: strategyKeyPrefix + identity.interfaceName + groupKeySuffix))
    }

    public static func save(profile: Int, identity: NetworkIdentity) {
        guard (0...6).contains(profile) else { return }
        UserDefaults.standard.set(profile, forKey: strategyKey(identity))
    }

    public static func save(group: Int, identity: NetworkIdentity) {
        guard (0...4).contains(group) else { return }
        UserDefaults.standard.set(group, forKey: groupKey(identity))
    }

    public static func save(profile: Int, interfaceName: String) {
        save(profile: profile, identity: NetworkIdentity(interfaceName: interfaceName, hash: ""))
    }

    public static func invalidate(identity: NetworkIdentity) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: strategyKey(identity))
        defaults.removeObject(forKey: groupKey(identity))
        defaults.removeObject(forKey: strategyKeyPrefix + identity.interfaceName)
        defaults.removeObject(forKey: strategyKeyPrefix + identity.interfaceName + groupKeySuffix)
    }

    public static func invalidate(profile: Int, interfaceName: String) {
        let key = strategyKeyPrefix + interfaceName
        if (UserDefaults.standard.object(forKey: key) as? Int) == profile {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Booleans, strings, fractions and out-of-range numbers are all rejected.
    static func validProfile(_ value: Any?) -> Int? {
        validInteger(value, in: 0...6)
    }

    static func validGroup(_ value: Any?) -> Int? {
        validInteger(value, in: 0...4)
    }

    private static func validInteger(_ value: Any?, in range: ClosedRange<Int>) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue == Double(number.intValue),
              range.contains(number.intValue) else { return nil }
        return number.intValue
    }

    public static func config(data: Data, localProxyPort: Int, interfaceName: String) -> Data? {
        guard (1...65535).contains(localProxyPort),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var outbounds = root["outbounds"] as? [[String: Any]] else { return nil }
        var inbounds = root["inbounds"] as? [[String: Any]] ?? []
        guard !inbounds.contains(where: { ($0["tag"] as? String) == "tun" }) else { return nil }
        let indices = outbounds.indices.filter {
            (outbounds[$0]["tag"] as? String) == "byedpi"
                && (outbounds[$0]["protocol"] as? String) == "socks"
        }
        guard indices.count == 1, let index = indices.first,
              var settings = outbounds[index]["settings"] as? [String: Any],
              var servers = settings["servers"] as? [[String: Any]], servers.count == 1,
              servers[0]["address"] as? String == "127.0.0.1" else { return nil }
        servers[0]["port"] = localProxyPort
        settings["servers"] = servers
        outbounds[index]["settings"] = settings
        for index in outbounds.indices where (outbounds[index]["protocol"] as? String) == "freedom" {
            var stream = outbounds[index]["streamSettings"] as? [String: Any] ?? [:]
            var sockopt = stream["sockopt"] as? [String: Any] ?? [:]
            sockopt["interface"] = interfaceName
            stream["sockopt"] = sockopt
            outbounds[index]["streamSettings"] = stream
        }
        inbounds.insert([
            "tag": "tun",
            "port": 0,
            "protocol": "tun",
            "settings": ["name": "utun", "MTU": 1500]
        ], at: 0)
        var result = root
        result.removeValue(forKey: "oculveDpiProfile")
        result["outbounds"] = outbounds
        result["inbounds"] = inbounds
        return try? JSONSerialization.data(withJSONObject: result, options: [])
    }
}

/// Samples ByeDPI's per-group counters while a tunnel runs and persists the
/// strategy that produced the most real destination responses. Only group ids
/// and counters are read; no host, address or packet data is stored.
public final class DpiStrategyLearner {
    public static let defaultInterval: TimeInterval = 45

    private let identity: TunnelDpiRuntime.NetworkIdentity
    private let profile: Int
    private let queue: DispatchQueue
    private let interval: TimeInterval
    private var timer: DispatchSourceTimer?
    private var lastOk: [Int]?
    private var lastFail: [Int]?

    public init(identity: TunnelDpiRuntime.NetworkIdentity, profile: Int,
                queue: DispatchQueue, interval: TimeInterval = DpiStrategyLearner.defaultInterval) {
        self.identity = identity
        self.profile = profile
        self.queue = queue
        self.interval = interval
    }

    public func start() {
        cancelTimer()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .seconds(5))
        timer.setEventHandler { [weak self] in _ = self?.sample() }
        timer.resume()
        self.timer = timer
    }

    /// Stops sampling and takes a final sample. Must run on the owning queue
    /// before the engine stops, otherwise the last counters are lost.
    public func stop() {
        cancelTimer()
        _ = sample()
    }

    private func cancelTimer() {
        timer?.cancel()
        timer = nil
    }

    /// Writes only when the counters changed and enough real responses were
    /// seen. Returns true when a learned value was stored.
    @discardableResult
    public func sample() -> Bool {
        guard profile == TunnelDpiRuntime.automaticProfile else { return false }
        let stats = TunnelDpiRuntime.groupStats()
        guard !stats.isEmpty else { return false }
        let ok = stats.map(\.okCount)
        let fail = stats.map(\.failCount)
        guard ok != lastOk || fail != lastFail else { return false }
        lastOk = ok
        lastFail = fail
        guard let best = Self.bestGroup(stats) else { return false }
        TunnelDpiRuntime.save(profile: profile, identity: identity)
        TunnelDpiRuntime.save(group: best.group, identity: identity)
        return true
    }

    /// Highest response ratio first. A group needs
    /// `minimumLearnedResponses` real destination responses before it may
    /// reorder the next connection; ties prefer the earlier preset.
    public static func bestGroup(_ stats: [TunnelDpiRuntime.GroupStat]) -> TunnelDpiRuntime.GroupStat? {
        let eligible = stats.filter { $0.okCount >= TunnelDpiRuntime.minimumLearnedResponses }
        return eligible.max { left, right in
            let leftScore = Double(left.okCount) / Double(left.failCount + 1)
            let rightScore = Double(right.okCount) / Double(right.failCount + 1)
            if leftScore != rightScore { return leftScore < rightScore }
            if left.okCount != right.okCount { return left.okCount < right.okCount }
            return left.group > right.group
        }
    }
}

// Access to the one-shot completion flag is serialized by `lock`.
private final class PhysicalInterfaceWaiter: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "oculve.dpi.path-bootstrap", qos: .utility)
    private let lock = NSLock()
    private var completed = false

    func wait() async throws -> TunnelDpiRuntime.NetworkIdentity {
        try await withCheckedThrowingContinuation { continuation in
            monitor.pathUpdateHandler = { [weak self] path in
                guard let self, path.status == .satisfied,
                      let identity = TunnelDpiRuntime.networkIdentity(in: path) else { return }
                self.finish(.success(identity), continuation: continuation)
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 6) { [weak self] in
                self?.finish(.failure(PhysicalInterfaceError.unavailable), continuation: continuation)
            }
        }
    }

    private func finish<T>(_ result: Result<T, Error>, continuation: CheckedContinuation<T, Error>) {
        lock.lock()
        guard !completed else { lock.unlock(); return }
        completed = true
        lock.unlock()
        monitor.cancel()
        continuation.resume(with: result)
    }
}

private enum PhysicalInterfaceError: Error {
    case unavailable
}
