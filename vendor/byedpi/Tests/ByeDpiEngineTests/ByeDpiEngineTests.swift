import Darwin
import XCTest
@testable import ByeDpiEngine

private func readGroupStats(_ ok: inout [Int32], _ fail: inout [Int32], capacity: Int32) -> Int32 {
    ok.withUnsafeMutableBufferPointer { okBuffer in
        fail.withUnsafeMutableBufferPointer { failBuffer in
            byedpi_engine_group_stats(okBuffer.baseAddress, failBuffer.baseAddress, capacity)
        }
    }
}

final class ByeDpiEngineTests: XCTestCase {
    func testAutomaticAndPinnedStrategiesStartAndReset() {
        for profile in 0...6 {
            let port = byedpi_engine_start(Int32(profile), nil, nil)
            XCTAssertTrue((1...65535).contains(port))
            XCTAssertEqual(byedpi_engine_profile(), Int32(profile))
            XCTAssertEqual(byedpi_engine_stop(), 1)
        }
        XCTAssertEqual(byedpi_engine_start(7, nil, nil), 0)
    }

    func testProfileFourRestartsAfterParserRuns() {
        // run_engine resets getopt state with optind = 1 before each
        // parse_args; profile 4 must start repeatedly after other profiles
        // and after an invalid profile request touched no parser state.
        for _ in 0..<2 {
            let port = byedpi_engine_start(4, nil, nil)
            XCTAssertTrue((1...65535).contains(port))
            XCTAssertEqual(byedpi_engine_profile(), 4)
            XCTAssertEqual(byedpi_engine_stop(), 1)
        }
        XCTAssertEqual(byedpi_engine_start(7, nil, nil), 0)
        let port = byedpi_engine_start(4, nil, nil)
        XCTAssertTrue((1...65535).contains(port))
        XCTAssertEqual(byedpi_engine_stop(), 1)
    }

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

    func testGroupStatsAreEmptyAndZeroedWhileIdle() {
        var ok = [Int32](repeating: -1, count: 8)
        var fail = [Int32](repeating: -1, count: 8)
        XCTAssertEqual(readGroupStats(&ok, &fail, capacity: 8), 0)
        XCTAssertEqual(byedpi_engine_exhausted(), 0)
        XCTAssertEqual(byedpi_engine_group_stats(nil, nil, 8), 0)
        XCTAssertEqual(byedpi_engine_group_stats(nil, &fail, 8), 0)
        XCTAssertEqual(byedpi_engine_group_stats(&ok, nil, 8), 0)
        XCTAssertEqual(readGroupStats(&ok, &fail, capacity: 0), 0)
        XCTAssertEqual(readGroupStats(&ok, &fail, capacity: -1), 0)
    }

    func testGroupStatsExposeTheAutomaticPresetsInPresetOrder() {
        let port = byedpi_engine_start_grouped(4, 2, nil, nil)
        XCTAssertTrue((1...65535).contains(port))
        var ok = [Int32](repeating: -1, count: 8)
        var fail = [Int32](repeating: -1, count: 8)
        XCTAssertEqual(readGroupStats(&ok, &fail, capacity: 8), 5)
        XCTAssertEqual(Array(ok.prefix(5)), [0, 0, 0, 0, 0])
        XCTAssertEqual(Array(fail.prefix(5)), [0, 0, 0, 0, 0])
        XCTAssertEqual(byedpi_engine_exhausted(), 0)

        // A short buffer only gets as many entries as it can hold.
        var shortOk = [Int32](repeating: -1, count: 2)
        var shortFail = [Int32](repeating: -1, count: 2)
        XCTAssertEqual(readGroupStats(&shortOk, &shortFail, capacity: 2), 2)
        XCTAssertEqual(shortOk, [0, 0])
        XCTAssertEqual(byedpi_engine_stop(), 1)

        XCTAssertEqual(readGroupStats(&ok, &fail, capacity: 8), 0, "stopped engines report nothing")
    }

    func testPinnedProfileReportsItsSingleGroup() {
        let port = byedpi_engine_start(0, nil, nil)
        XCTAssertTrue((1...65535).contains(port))
        var ok = [Int32](repeating: -1, count: 8)
        var fail = [Int32](repeating: -1, count: 8)
        XCTAssertEqual(readGroupStats(&ok, &fail, capacity: 8), 1)
        XCTAssertEqual(byedpi_engine_stop(), 1)
    }

    func testInvalidFirstGroupKeepsTheEngineStartable() {
        XCTAssertEqual(byedpi_engine_start_grouped(7, 0, nil, nil), 0)
        for first in [Int32(99), -5, 0, 4] {
            let port = byedpi_engine_start_grouped(4, first, nil, nil)
            XCTAssertTrue((1...65535).contains(port), "first_group=\(first)")
            var ok = [Int32](repeating: 0, count: 8)
            var fail = [Int32](repeating: 0, count: 8)
            XCTAssertEqual(readGroupStats(&ok, &fail, capacity: 8), 5)
            XCTAssertEqual(byedpi_engine_stop(), 1)
        }
    }
}
