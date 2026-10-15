import Foundation
import Darwin

/// Applies a monotonic total budget to each blocking socket operation.
public struct LocalSocketDeadline {
    private let end: UInt64
    public init(timeout: TimeInterval) throws {
        let now = DispatchTime.now().uptimeNanoseconds
        guard timeout.isFinite, timeout > 0,
              timeout < Double(UInt64.max - now) / 1_000_000_000 else {
            throw LocalSOCKS5Client.Failure.invalidDestination
        }
        end = now + UInt64(timeout * 1_000_000_000)
    }
    public init(uptimeNanoseconds: UInt64) { end = uptimeNanoseconds }
    public var isExpired: Bool { DispatchTime.now().uptimeNanoseconds >= end }
    public func apply(to fd: Int32) -> Bool {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < end else { return false }
        // Round up to a positive microsecond: timeval(0, 0) means no timeout.
        let microseconds = (end - now + 999) / 1000
        var duration = timeval(tv_sec: Int(microseconds / 1_000_000),
                               tv_usec: __darwin_suseconds_t(microseconds % 1_000_000))
        let size = socklen_t(MemoryLayout<timeval>.size)
        return setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &duration, size) == 0
            && setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &duration, size) == 0
    }
}

/// Shared framing for native health checks; authentication never falls back to noauth.
public enum LocalSOCKS5Client {
    public enum Failure: Error { case invalidDestination, connect, authentication, request }

    public static func authenticate(fd: Int32, credentials: LocalProxyCredentials?,
                                    deadline: LocalSocketDeadline? = nil) -> Bool {
        // A worker can exit while the watchdog writes its greeting. SIGPIPE
        // must report an auth failure instead of terminating NetworkExtension.
        var noSignal: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
        let method: UInt8 = credentials == nil ? 0 : 2
        guard sendAll(fd: fd, bytes: [5, 1, method], deadline: deadline),
              receiveExactly(fd: fd, count: 2, deadline: deadline) == [5, method] else { return false }
        guard let credentials else { return true } // Explicit proxyOnly noauth contract.
        return sendAll(fd: fd, bytes: Array(credentials.socksAuthenticationRequest), deadline: deadline)
            && receiveExactly(fd: fd, count: 2, deadline: deadline) == [1, 0]
    }

    public static func openConnection(proxyPort: Int, credentials: LocalProxyCredentials?, host: String,
                                      port: Int, timeout: TimeInterval = 8) throws -> Int32 {
        guard (1...65535).contains(proxyPort), (1...65535).contains(port), !host.isEmpty,
              host.utf8.count <= 255, !host.utf8.contains(0) else { throw Failure.invalidDestination }
        let deadline = try LocalSocketDeadline(timeout: timeout)
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { throw Failure.connect }
        do {
            var noSignal: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
            guard deadline.apply(to: fd) else { throw Failure.connect }
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = UInt16(proxyPort).bigEndian
            inet_pton(AF_INET, "127.0.0.1", &address.sin_addr)
            guard withUnsafePointer(to: &address, { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }) == 0 else { throw Failure.connect }
            guard authenticate(fd: fd, credentials: credentials, deadline: deadline) else { throw Failure.authentication }
            var request: [UInt8] = [5, 1, 0]
            var ipv4 = in_addr()
            var ipv6 = in6_addr()
            if inet_pton(AF_INET, host, &ipv4) == 1 {
                request.append(1)
                withUnsafeBytes(of: &ipv4) { request.append(contentsOf: $0) }
            } else if inet_pton(AF_INET6, host, &ipv6) == 1 {
                request.append(4)
                withUnsafeBytes(of: &ipv6) { request.append(contentsOf: $0) }
            } else {
                request.append(contentsOf: [3, UInt8(host.utf8.count)])
                request.append(contentsOf: host.utf8)
            }
            request.append(contentsOf: [UInt8(port >> 8), UInt8(port & 255)])
            guard sendAll(fd: fd, bytes: request, deadline: deadline),
                  let header = receiveExactly(fd: fd, count: 4, deadline: deadline),
                  header[0] == 5, header[1] == 0, header[2] == 0 else { throw Failure.request }
            let tail: Int
            switch header[3] {
            case 1: tail = 6
            case 4: tail = 18
            case 3:
                guard let length = receiveExactly(fd: fd, count: 1, deadline: deadline)?.first else { throw Failure.request }
                tail = Int(length) + 2
            default: throw Failure.request
            }
            guard receiveExactly(fd: fd, count: tail, deadline: deadline) != nil else { throw Failure.request }
            guard !deadline.isExpired,
                  try LocalSocketDeadline(timeout: timeout).apply(to: fd) else { throw Failure.request }
            return fd
        } catch {
            close(fd)
            throw error
        }
    }

    public static func sendAll(fd: Int32, bytes: [UInt8],
                               deadline: LocalSocketDeadline? = nil) -> Bool {
        var offset = 0
        while offset < bytes.count {
            guard deadline?.apply(to: fd) != false else { return false }
            let count = bytes.withUnsafeBytes { send(fd, $0.baseAddress!.advanced(by: offset), bytes.count - offset, MSG_NOSIGNAL) }
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { return false }
            offset += count
        }
        return true
    }

    public static func receiveExactly(fd: Int32, count: Int,
                                      deadline: LocalSocketDeadline? = nil) -> [UInt8]? {
        guard count >= 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: count)
        var offset = 0
        while offset < count {
            guard deadline?.apply(to: fd) != false else { return nil }
            let read = bytes.withUnsafeMutableBytes { recv(fd, $0.baseAddress!.advanced(by: offset), count - offset, 0) }
            if read < 0 && errno == EINTR { continue }
            guard read > 0 else { return nil }
            offset += read
        }
        return bytes
    }
}
