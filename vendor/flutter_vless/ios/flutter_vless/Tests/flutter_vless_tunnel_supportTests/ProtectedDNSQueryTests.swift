import XCTest
@testable import flutter_vless_privacy

final class ProtectedDNSQueryTests: XCTestCase {
    func testAuthenticatedResponseMustMatchQuestionAndTransaction() throws {
        let query = try ProtectedDNSQuery(host: "vpn.example", id: 1234)
        var answer = query.bytes
        answer[2] = 0x81; answer[3] = 0x80; answer[7] = 1
        answer += [0xc0, 12, 0, 1, 0, 1, 0, 0, 0, 10, 0, 4, 192, 0, 2, 17]
        XCTAssertEqual(query.address(in: answer), "192.0.2.17")
        XCTAssertEqual(query.framed.count, query.bytes.count + 2)
        var mismatched = answer; mismatched[1] ^= 1
        XCTAssertNil(query.address(in: mismatched))
        var truncated = answer; truncated[2] |= 2
        XCTAssertNil(query.address(in: truncated))
        for count in 0..<answer.count { XCTAssertNil(query.address(in: Array(answer.prefix(count)))) }
        var wrongHost = answer; wrongHost[13] = 120
        XCTAssertNil(query.address(in: wrongHost))
        var pointerCycle = answer; pointerCycle[query.bytes.count + 1] = UInt8(query.bytes.count)
        XCTAssertNil(query.address(in: pointerCycle))
        XCTAssertThrowsError(try ProtectedDNSQuery(host: "a..example"))
        XCTAssertThrowsError(try ProtectedDNSQuery(host: String(repeating: "a", count: 64) + ".example"))
    }
}
