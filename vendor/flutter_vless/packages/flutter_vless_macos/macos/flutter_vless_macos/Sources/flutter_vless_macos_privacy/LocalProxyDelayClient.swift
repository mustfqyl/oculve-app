import Foundation
import Security
import Darwin

/// Uses an explicitly authenticated socket: CFNetwork's SOCKS dictionary offers
/// noauth even with credentials. There is no origin connection or auth fallback.
public enum LocalProxyDelayClient {
    public static func resolveIPv4(host: String, port: Int, credentials: LocalProxyCredentials) throws -> String? {
        let query = try ProtectedDNSQuery(host: host)
        let fd = try LocalSOCKS5Client.openConnection(proxyPort: port, credentials: credentials,
            host: "1.1.1.1", port: 853, timeout: 5)
        defer { close(fd) }
        let connection = LocalProxyTLSConnection(fd: fd,
            deadline: DispatchTime.now().uptimeNanoseconds + 8_000_000_000)
        guard connection.startTLS(host: "cloudflare-dns.com"), connection.write(query.framed) else { return nil }
        func readExactly(_ count: Int) -> [UInt8]? {
            var bytes: [UInt8] = []
            while bytes.count < count {
                guard let next = connection.read(maxCount: count - bytes.count), !next.isEmpty else { return nil }
                bytes += next
            }
            return bytes
        }
        guard let length = readExactly(2) else { return nil }
        let size = Int(length[0]) * 256 + Int(length[1])
        guard (12...16384).contains(size), let response = readExactly(size) else { return nil }
        return query.address(in: response)
    }

    /// Verifies the full local-proxy-to-Internet path with certificate-checked
    /// HTTPS and a small, strict 204 response from either independent probe.
    public static func checkConnectivity(port: Int, credentials: LocalProxyCredentials?) -> Bool {
        let probes = [
            URL(string: "https://www.gstatic.com/generate_204")!,
            URL(string: "https://cp.cloudflare.com/generate_204")!
        ]
        return probes.contains { measureResponse(url: $0, port: port, credentials: credentials,
            proxyProtocol: "socks", expectedStatus: 204, connectTimeout: 3, tlsTimeout: 4) > 0 }
    }

    public static func measure(url: URL, port: Int, credentials: LocalProxyCredentials?,
                               proxyProtocol: String = "socks", completion: @escaping (Int64) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            completion(measureResponse(url: url, port: port, credentials: credentials, proxyProtocol: proxyProtocol))
        }
    }

    private static func measureResponse(url: URL, port: Int, credentials: LocalProxyCredentials?,
                                        proxyProtocol: String, expectedStatus: Int? = nil,
                                        connectTimeout: TimeInterval = 8, tlsTimeout: UInt64 = 10) -> Int64 {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let rawHost = url.host, !rawHost.isEmpty, url.user == nil, url.password == nil,
              (1...65535).contains(port), ["socks", "http"].contains(proxyProtocol),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return -1 }
        let host = rawHost.hasPrefix("[") && rawHost.hasSuffix("]") ? String(rawHost.dropFirst().dropLast()) : rawHost
        let destinationPort = url.port ?? (scheme == "https" ? 443 : 80)
        let start = DispatchTime.now().uptimeNanoseconds
        do {
            let fd: Int32
            if proxyProtocol == "http" {
                fd = try LocalHTTPProxyClient.openConnection(proxyPort: port, credentials: credentials,
                    host: host, port: destinationPort, timeout: connectTimeout)
            } else {
                fd = try LocalSOCKS5Client.openConnection(proxyPort: port, credentials: credentials,
                    host: host, port: destinationPort, timeout: connectTimeout)
            }
            defer { close(fd) }
            let connection = LocalProxyTLSConnection(fd: fd, deadline: start + tlsTimeout * 1_000_000_000)
            if scheme == "https", !connection.startTLS(host: host) { return -1 }
            let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
            let target = path + (components.percentEncodedQuery.map { "?" + $0 } ?? "")
            let authority = (host.contains(":") ? "[\(host)]" : host) + (url.port.map { ":\($0)" } ?? "")
            guard ![target, authority].contains(where: { $0.contains("\r") || $0.contains("\n") }) else { return -1 }
            let request = Array("GET \(target) HTTP/1.1\r\nHost: \(authority)\r\nConnection: close\r\nUser-Agent: flutter-vless-delay\r\n\r\n".utf8)
            guard connection.write(request) else { return -1 }
            // Bounded response headers suffice; no cookies, credential storage, redirects or body buffering.
            var bytes: [UInt8] = []
            while bytes.count < 16_384, let next = connection.read(maxCount: min(2048, 16_384 - bytes.count)) {
                bytes.append(contentsOf: next)
                guard let end = bytes.firstIndex(of: 10) else { continue }
                let fields = String(decoding: bytes[...end], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
                guard fields.count >= 2, fields[0] == "HTTP/1.1" || fields[0] == "HTTP/1.0",
                      let status = Int(fields[1]), expectedStatus.map({ $0 == status }) ?? (200...399).contains(status) else { return -1 }
                return Int64(max(1, (DispatchTime.now().uptimeNanoseconds - start) / 1_000_000))
            }
            return -1
        } catch { return -1 }
    }
}

/// TLS wraps only the authenticated FD; trust and hostname are checked before
/// HTTP bytes. SecureTransport remains available on iOS 15 and supports TLS 1.2.
private final class LocalProxyTLSConnection {
    let fd: Int32
    let deadline: UInt64
    private var tls: SSLContext?

    init(fd: Int32, deadline: UInt64) { self.fd = fd; self.deadline = deadline }
    private var withinDeadline: Bool { DispatchTime.now().uptimeNanoseconds < deadline }

    func startTLS(host: String) -> Bool {
        guard let context = SSLCreateContext(kCFAllocatorDefault, .clientSide, .streamType) else { return false }
        tls = context
        guard SSLSetIOFuncs(context, { connection, data, size in
            return Unmanaged<LocalProxyTLSConnection>.fromOpaque(connection).takeUnretainedValue().transportRead(data, size)
        }, { connection, data, size in
            return Unmanaged<LocalProxyTLSConnection>.fromOpaque(connection).takeUnretainedValue().transportWrite(data, size)
        }) == errSecSuccess,
        SSLSetConnection(context, Unmanaged.passUnretained(self).toOpaque()) == errSecSuccess,
        SSLSetProtocolVersionMin(context, .tlsProtocol12) == errSecSuccess,
        SSLSetSessionOption(context, .breakOnServerAuth, true) == errSecSuccess,
        host.withCString({ SSLSetPeerDomainName(context, $0, host.utf8.count) }) == errSecSuccess else { return false }
        var authenticated = false
        while withinDeadline {
            let result = SSLHandshake(context)
            if result == errSSLPeerAuthCompleted {
                var trust: SecTrust?
                guard SSLCopyPeerTrust(context, &trust) == errSecSuccess, let trust,
                      SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, host as CFString)) == errSecSuccess,
                      SecTrustSetNetworkFetchAllowed(trust, false) == errSecSuccess,
                      SecTrustEvaluateWithError(trust, nil) else { return false }
                authenticated = true
            } else if result == errSecSuccess { return authenticated }
            else if result != errSSLWouldBlock { return false }
        }
        return false
    }

    func write(_ bytes: [UInt8]) -> Bool {
        guard withinDeadline else { return false }
        guard let tls else { return LocalSOCKS5Client.sendAll(fd: fd, bytes: bytes) }
        var offset = 0
        while offset < bytes.count, withinDeadline {
            var count = 0
            let status = bytes.withUnsafeBytes { SSLWrite(tls, $0.baseAddress!.advanced(by: offset), bytes.count - offset, &count) }
            offset += count
            guard status == errSecSuccess || status == errSSLWouldBlock else { return false }
        }
        return offset == bytes.count
    }

    func read(maxCount: Int) -> [UInt8]? {
        while withinDeadline {
            var bytes = [UInt8](repeating: 0, count: maxCount)
            var count = 0
            if let tls {
                let status = bytes.withUnsafeMutableBytes { SSLRead(tls, $0.baseAddress!, maxCount, &count) }
                if count > 0 { return Array(bytes.prefix(count)) }
                guard status == errSecSuccess || status == errSSLWouldBlock else { return nil }
            } else {
                count = bytes.withUnsafeMutableBytes { recv(fd, $0.baseAddress, maxCount, 0) }
                if count > 0 { return Array(bytes.prefix(count)) }
                guard count < 0 && errno == EINTR else { return nil }
            }
        }
        return nil
    }

    private func transportRead(_ data: UnsafeMutableRawPointer, _ size: UnsafeMutablePointer<Int>) -> OSStatus {
        guard withinDeadline else { size.pointee = 0; return errSSLClosedAbort }
        let requested = size.pointee
        let count = recv(fd, data, requested, 0)
        size.pointee = max(0, count)
        if count > 0 { return count == requested ? errSecSuccess : errSSLWouldBlock }
        if count == 0 { return errSSLClosedGraceful }
        return errno == EINTR ? errSSLWouldBlock : errSSLClosedAbort
    }

    private func transportWrite(_ data: UnsafeRawPointer, _ size: UnsafeMutablePointer<Int>) -> OSStatus {
        guard withinDeadline else { size.pointee = 0; return errSSLClosedAbort }
        let requested = size.pointee
        let count = send(fd, data, requested, MSG_NOSIGNAL)
        size.pointee = max(0, count)
        if count > 0 { return count == requested ? errSecSuccess : errSSLWouldBlock }
        return errno == EINTR ? errSSLWouldBlock : errSSLClosedAbort
    }
}

/// Bounded DNS-over-TLS framing; rejects mismatched questions and responses.
struct ProtectedDNSQuery {
    let host: String
    let id: UInt16
    let bytes: [UInt8]
    init(host: String, id: UInt16 = UInt16.random(in: 0...65535)) throws {
        let host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty, host.utf8.count <= 253,
              labels.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 63 && $0.utf8.allSatisfy({ $0 > 32 && $0 < 127 }) }) else {
            throw LocalSOCKS5Client.Failure.invalidDestination
        }
        self.host = host; self.id = id
        var bytes: [UInt8] = [UInt8(id >> 8), UInt8(id & 255), 1, 0, 0, 1, 0, 0, 0, 0, 0, 0]
        for label in labels { bytes.append(UInt8(label.utf8.count)); bytes += label.utf8 }
        bytes += [0, 0, 1, 0, 1]
        self.bytes = bytes
    }
    var framed: [UInt8] { [UInt8(bytes.count >> 8), UInt8(bytes.count & 255)] + bytes }
    func address(in data: [UInt8]) -> String? {
        guard data.count >= 12, data.count <= 16384 else { return nil }
        func word(_ at: Int) -> Int { Int(data[at]) * 256 + Int(data[at + 1]) }
        guard word(0) == Int(id), data[2] & 0x82 == 0x80, data[3] & 15 == 0, word(4) == 1 else { return nil }
        func name(_ offset: inout Int) -> String? {
            var cursor = offset, next: Int?, labels: [String] = [], seen = Set<Int>()
            for _ in 0..<128 {
                guard cursor < data.count, seen.insert(cursor).inserted else { return nil }
                let size = Int(data[cursor]); cursor += 1
                if size == 0 { offset = next ?? cursor; return labels.joined(separator: ".").lowercased() }
                if size & 0xc0 == 0xc0 {
                    guard cursor < data.count else { return nil }
                    if next == nil { next = cursor + 1 }
                    cursor = ((size & 63) << 8) | Int(data[cursor]); continue
                }
                guard size <= 63, cursor + size <= data.count else { return nil }
                labels.append(String(decoding: data[cursor..<cursor+size], as: UTF8.self)); cursor += size
            }
            return nil
        }
        var cursor = 12
        guard name(&cursor) == host, cursor + 4 <= data.count,
              word(cursor) == 1, word(cursor + 2) == 1 else { return nil }
        cursor += 4
        var addresses: [String: String] = [:], aliases: [String: String] = [:]
        guard word(6) <= 256 else { return nil }
        for _ in 0..<word(6) {
            guard let owner = name(&cursor), cursor + 10 <= data.count else { return nil }
            let type = word(cursor), klass = word(cursor + 2), size = word(cursor + 8)
            cursor += 10
            guard cursor + size <= data.count else { return nil }
            if klass == 1 && type == 1 && size == 4 {
                addresses[owner] = data[cursor..<cursor+4].map(String.init).joined(separator: ".")
            } else if klass == 1 && type == 5 {
                var target = cursor
                if let alias = name(&target), target <= cursor + size { aliases[owner] = alias }
            }
            cursor += size
        }
        var owner = host, seen = Set<String>()
        for _ in 0..<16 {
            guard seen.insert(owner).inserted else { return nil }
            if let address = addresses[owner] { return address }
            guard let alias = aliases[owner] else { return nil }; owner = alias
        }
        return nil
    }
}
