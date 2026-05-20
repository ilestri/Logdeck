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

    func testDecodesNullTerminatedFileURLData() {
        let url = URL(fileURLWithPath: "/tmp/logdeck.log")
        let data = "\(url.absoluteString)\0".data(using: .utf8)

        XCTAssertEqual(DroppedFileURLDecoder.url(from: data as NSData?), url)
    }

    func testDecodesFirstFileURLFromNullSeparatedData() {
        let firstURL = URL(fileURLWithPath: "/tmp/first.log")
        let secondURL = URL(fileURLWithPath: "/tmp/second.log")
        let data = "\(firstURL.absoluteString)\0\(secondURL.absoluteString)".data(using: .utf8)

        XCTAssertEqual(DroppedFileURLDecoder.url(from: data as NSData?), firstURL)
    }

    func testDecodesAbsolutePathString() {
        let url = URL(fileURLWithPath: "/tmp/logdeck.log")

        XCTAssertEqual(DroppedFileURLDecoder.url(from: " /tmp/logdeck.log\n" as NSString), url)
    }

    func testRejectsNonFileURLString() {
        XCTAssertNil(DroppedFileURLDecoder.url(from: "https://example.com/logdeck.log" as NSString))
    }
}
