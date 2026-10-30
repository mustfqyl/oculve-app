import XCTest
@testable import flutter_vless_tunnel_support

final class TunnelStallDetectorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    func testSendingWithNoAnswerForAFullWindowIsAStall() {
        var detector = TunnelStallDetector(window: 6, minimumSentPackets: 4)
        XCTAssertFalse(detector.record(now: at(0), up: 100, down: 100))
        XCTAssertFalse(detector.record(now: at(2), up: 110, down: 100))
        XCTAssertFalse(detector.record(now: at(4), up: 120, down: 100))
        XCTAssertTrue(detector.record(now: at(6), up: 130, down: 100))
    }

    func testAnswersKeepTheTunnelHealthy() {
        var detector = TunnelStallDetector(window: 6, minimumSentPackets: 4)
        XCTAssertFalse(detector.record(now: at(0), up: 0, down: 0))
        for step in 1...10 {
            // Heavy upload but replies keep arriving.
            XCTAssertFalse(detector.record(now: at(TimeInterval(step * 2)), up: UInt64(step * 50), down: UInt64(step)))
        }
    }

    func testAnIdlePhoneIsNeverReportedAsStalled() {
        var detector = TunnelStallDetector(window: 6, minimumSentPackets: 4)
        XCTAssertFalse(detector.record(now: at(0), up: 500, down: 500))
        for step in 1...30 {
            XCTAssertFalse(detector.record(now: at(TimeInterval(step * 2)), up: 501, down: 500),
                           "nothing was sent, so nothing can be missing")
        }
    }

    func testAFewBackgroundPacketsAreNotAStall() {
        var detector = TunnelStallDetector(window: 6, minimumSentPackets: 4)
        XCTAssertFalse(detector.record(now: at(0), up: 10, down: 10))
        XCTAssertFalse(detector.record(now: at(6), up: 12, down: 10), "two keepalive packets")
    }

    func testAStallIsReportedOncePerWindowNotEveryTick() {
        var detector = TunnelStallDetector(window: 6, minimumSentPackets: 4)
        XCTAssertFalse(detector.record(now: at(0), up: 0, down: 0))
        XCTAssertTrue(detector.record(now: at(6), up: 20, down: 0))
        XCTAssertFalse(detector.record(now: at(8), up: 30, down: 0))
        XCTAssertFalse(detector.record(now: at(10), up: 40, down: 0))
        XCTAssertTrue(detector.record(now: at(12), up: 60, down: 0))
    }

    func testAReplyResetsTheWindow() {
        var detector = TunnelStallDetector(window: 6, minimumSentPackets: 4)
        XCTAssertFalse(detector.record(now: at(0), up: 0, down: 0))
        XCTAssertFalse(detector.record(now: at(5), up: 40, down: 1)) // answer just in time
        XCTAssertFalse(detector.record(now: at(10), up: 80, down: 1)) // only 5s since the answer
        XCTAssertTrue(detector.record(now: at(11), up: 90, down: 1))
    }

    func testCountersThatGoBackwardsMeanARestartAndAreNotAStall() {
        var detector = TunnelStallDetector(window: 6, minimumSentPackets: 4)
        XCTAssertFalse(detector.record(now: at(0), up: 1000, down: 1000))
        XCTAssertFalse(detector.record(now: at(8), up: 5, down: 0))
        XCTAssertFalse(detector.record(now: at(10), up: 9, down: 0))
    }

    func testResetForgetsTheBaseline() {
        var detector = TunnelStallDetector(window: 6, minimumSentPackets: 4)
        XCTAssertFalse(detector.record(now: at(0), up: 0, down: 0))
        detector.reset()
        XCTAssertFalse(detector.record(now: at(20), up: 100, down: 0), "first reading after a reset only sets the baseline")
    }

    func testEndpointLivenessNeedsConsecutiveFailures() {
        var liveness = EndpointLiveness(failureThreshold: 2)
        XCTAssertFalse(liveness.record(alive: false))
        XCTAssertFalse(liveness.record(alive: true), "one success clears the count")
        XCTAssertFalse(liveness.record(alive: false))
        XCTAssertTrue(liveness.record(alive: false))
        liveness.reset()
        XCTAssertEqual(liveness.consecutiveFailures, 0)
    }
}
