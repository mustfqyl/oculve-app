import Foundation
import Network
import Darwin
import ByeDpiEngine

public enum TunnelDpiRuntime {
    private static let profileKeyPrefix = "oculve.dpi.strategy.v1."

    public static func interfaceName(in path: NWPath) -> String? {
        let physicalTypes: [NWInterface.InterfaceType] = [.wifi, .cellular, .wiredEthernet]
        for type in physicalTypes where path.usesInterfaceType(type) {
            if let interface = path.availableInterfaces.first(where: { $0.type == type }) {
                return interface.name
            }
        }
        return path.availableInterfaces.first(where: { physicalTypes.contains($0.type) })?.name
    }

    public static func currentPhysicalInterface() async throws -> String {
        try await PhysicalInterfaceWaiter().wait()
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

    public static func start(profile: Int, interfaceName: String) -> Int {
        guard (0...3).contains(profile), !interfaceName.isEmpty else { return 0 }
        return Int(interfaceName.withCString { byedpi_engine_start(Int32(profile), nil, $0) })
    }

    public static func stop() -> Bool {
        byedpi_engine_stop() == 1
    }

    public static func isRunning() -> Bool {
        byedpi_engine_is_running() == 1
    }

    /// NetworkExtension owns the utun socket. Give its descriptor to Xray's
    /// native TUN inbound instead of copying packets through HEV/tun2socks.
    public static func packetTunnelFileDescriptor() -> Int32? {
        let descriptorLimit = min(Int(getdtablesize()), 1025)
        guard descriptorLimit > 0 else { return nil }
        for descriptor in 0..<descriptorLimit {
            var interfaceName = [CChar](repeating: 0, count: Int(IFNAMSIZ))
            var length = socklen_t(interfaceName.count)
            let result = interfaceName.withUnsafeMutableBufferPointer { buffer in
                getsockopt(Int32(descriptor), 2, 2, buffer.baseAddress, &length)
            }
            if result == 0, String(cString: interfaceName).hasPrefix("utun") {
                return Int32(descriptor)
            }
        }
        return nil
    }

    public static func profileCandidates(interfaceName: String) -> [Int] {
        let cached = UserDefaults.standard.object(forKey: profileKeyPrefix + interfaceName) as? Int
        let preferred = cached.flatMap { (0...3).contains($0) ? $0 : nil }
        return (preferred.map { [$0] } ?? []) + (0...3).filter { $0 != preferred }
    }

    public static func save(profile: Int, interfaceName: String) {
        guard (0...3).contains(profile) else { return }
        UserDefaults.standard.set(profile, forKey: profileKeyPrefix + interfaceName)
    }

    public static func invalidate(profile: Int, interfaceName: String) {
        let key = profileKeyPrefix + interfaceName
        if (UserDefaults.standard.object(forKey: key) as? Int) == profile {
            UserDefaults.standard.removeObject(forKey: key)
        }
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
        result["outbounds"] = outbounds
        result["inbounds"] = inbounds
        return try? JSONSerialization.data(withJSONObject: result, options: [])
    }
}

// Access to the one-shot completion flag is serialized by `lock`.
private final class PhysicalInterfaceWaiter: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "oculve.dpi.path-bootstrap", qos: .utility)
    private let lock = NSLock()
    private var completed = false

    func wait() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            monitor.pathUpdateHandler = { [weak self] path in
                guard let self, path.status == .satisfied,
                      let name = TunnelDpiRuntime.interfaceName(in: path) else { return }
                self.finish(.success(name), continuation: continuation)
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
