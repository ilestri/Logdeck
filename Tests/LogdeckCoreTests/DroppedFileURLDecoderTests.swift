@testable import LogdeckCore
import XCTest

final class DroppedFileURLDecoderTests: XCTestCase {
    func testDecodesDirectFileURL() {
        let url = URL(fileURLWithPath: "/tmp/logdeck.log")

        XCTAssertEqual(DroppedFileURLDecoder.url(from: url as NSURL), url)
    }

    func testDecodesFileURLData() {
        let url = URL(fileURLWithPath: "/tmp/logdeck with spaces.log")
        let data = "\(url.absoluteString)\n".data(using: .utf8)

        XCTAssertEqual(DroppedFileURLDecoder.url(from: data as NSData?), url)
    }

    func testDecodesAbsolutePathString() {
        let url = URL(fileURLWithPath: "/tmp/logdeck.log")

        XCTAssertEqual(DroppedFileURLDecoder.url(from: " /tmp/logdeck.log\n" as NSString), url)
    }

    func testRejectsNonFileURLString() {
        XCTAssertNil(DroppedFileURLDecoder.url(from: "https://example.com/logdeck.log" as NSString))
    }
}
