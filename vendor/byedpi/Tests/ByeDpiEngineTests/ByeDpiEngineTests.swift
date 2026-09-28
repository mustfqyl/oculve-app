import Darwin
import XCTest
@testable import ByeDpiEngine

final class ByeDpiEngineTests: XCTestCase {
    func testDynamicLoopbackEndpointLifecycle() throws {
        let port = byedpi_engine_start(0, nil, nil)
        XCTAssertTrue((1...65535).contains(port))
        XCTAssertEqual(byedpi_engine_profile(), 0)
        XCTAssertEqual(byedpi_engine_is_running(), 1)
        XCTAssertEqual(byedpi_engine_start(1, nil, nil), 0, "Only one engine instance may run")

        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(socketFD, 0)
        defer { close(socketFD) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: in_addr_t(0x7f000001).bigEndian)
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        XCTAssertEqual(connected, 0)
        XCTAssertEqual(byedpi_engine_stop(), 1)
        XCTAssertEqual(byedpi_engine_is_running(), 0)
        XCTAssertEqual(byedpi_engine_profile(), -1)
    }
}
