@testable import LogdeckCore
import XCTest

final class LogFileLoaderTests: XCTestCase {
    func testTruncatedLoadKeepsFirstLineWhenOffsetStartsAtLineBoundary() throws {
        let url = temporaryFileURL()
        try "alpha\nbravo\ncharlie\n".write(to: url, atomically: true, encoding: .utf8)

        let maxBytes = Data("bravo\ncharlie\n".utf8).count
        let source = try LogFileLoader.load(url: url, maxBytes: maxBytes)

        XCTAssertTrue(source.isTruncated)
        XCTAssertEqual(source.entries.map(\.message), ["bravo", "charlie"])
    }

    func testTruncatedLoadDropsPartialFirstLineWhenOffsetStartsInsideLine() throws {
        let url = temporaryFileURL()
        try "alpha\nbravo\ncharlie\n".write(to: url, atomically: true, encoding: .utf8)

        let maxBytes = Data("avo\ncharlie\n".utf8).count
        let source = try LogFileLoader.load(url: url, maxBytes: maxBytes)

        XCTAssertTrue(source.isTruncated)
        XCTAssertEqual(source.entries.map(\.message), ["charlie"])
    }

    func testNegativeMaxBytesDoesNotSeekPastEndOfFile() throws {
        let url = temporaryFileURL()
        try "alpha\nbravo\n".write(to: url, atomically: true, encoding: .utf8)

        let source = try LogFileLoader.load(url: url, maxBytes: -1)

        XCTAssertTrue(source.isTruncated)
        XCTAssertTrue(source.entries.isEmpty)
        XCTAssertEqual(source.lastReadOffset, UInt64(Data("alpha\nbravo\n".utf8).count))
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("log")
    }
}
