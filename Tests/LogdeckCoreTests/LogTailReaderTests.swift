@testable import LogdeckCore
import XCTest

final class LogTailReaderTests: XCTestCase {
    func testReadsOnlyAppendedCompleteLines() throws {
        let url = temporaryFileURL()
        try "info ready\n".write(to: url, atomically: true, encoding: .utf8)

        let source = try LogFileLoader.load(url: url)
        try append("ERROR failed\npartial", to: url)

        let result = try LogTailReader.readAppendedEntries(from: source)

        XCTAssertEqual(result.entries.map(\.lineNumber), [2])
        XCTAssertEqual(result.entries.first?.level, .error)
        XCTAssertEqual(result.pendingText, "partial")
        XCTAssertFalse(result.didReset)
    }

    func testCombinesPendingTextWithNextAppend() throws {
        let url = temporaryFileURL()
        try "info ready\n".write(to: url, atomically: true, encoding: .utf8)

        var source = try LogFileLoader.load(url: url)
        try append("ERROR fail", to: url)

        let first = try LogTailReader.readAppendedEntries(from: source)
        source.lastReadOffset = first.nextOffset

        try append("ed\n", to: url)
        let second = try LogTailReader.readAppendedEntries(from: source, pendingText: first.pendingText)

        XCTAssertTrue(first.entries.isEmpty)
        XCTAssertEqual(second.entries.first?.lineNumber, 2)
        XCTAssertEqual(second.entries.first?.message, "ERROR failed")
        XCTAssertEqual(second.pendingText, "")
    }

    func testWaitsForLineFeedWhenCRLFIsSplitAcrossAppends() throws {
        let url = temporaryFileURL()
        try "info ready\r\n".write(to: url, atomically: true, encoding: .utf8)

        var source = try LogFileLoader.load(url: url)
        try append("ERROR failed\r", to: url)

        let first = try LogTailReader.readAppendedEntries(from: source)
        source.lastReadOffset = first.nextOffset

        try append("\nWARN recovered\r\n", to: url)
        let second = try LogTailReader.readAppendedEntries(from: source, pendingText: first.pendingText)

        XCTAssertTrue(first.entries.isEmpty)
        XCTAssertEqual(first.pendingText, "ERROR failed\r")
        XCTAssertEqual(second.entries.map(\.lineNumber), [2, 3])
        XCTAssertEqual(second.entries.map(\.message), ["ERROR failed", "WARN recovered"])
        XCTAssertEqual(second.pendingText, "")
    }

    func testDetectsFileReset() throws {
        let url = temporaryFileURL()
        try "info first\ninfo second\n".write(to: url, atomically: true, encoding: .utf8)

        let source = try LogFileLoader.load(url: url)
        try "WARN restarted\n".write(to: url, atomically: true, encoding: .utf8)

        let result = try LogTailReader.readAppendedEntries(from: source)

        XCTAssertTrue(result.didReset)
        XCTAssertEqual(result.entries.map(\.lineNumber), [1])
        XCTAssertEqual(result.entries.first?.level, .warning)
    }

    func testDetectsFileReplacementWhenSizeDoesNotShrink() throws {
        let url = temporaryFileURL()
        try "info first\n".write(to: url, atomically: true, encoding: .utf8)

        let source = try LogFileLoader.load(url: url)
        try "WARN reset\n".write(to: url, atomically: true, encoding: .utf8)

        let result = try LogTailReader.readAppendedEntries(from: source)

        XCTAssertTrue(result.didReset)
        XCTAssertEqual(result.entries.map(\.lineNumber), [1])
        XCTAssertEqual(result.entries.map(\.message), ["WARN reset"])
        XCTAssertEqual(result.pendingText, "")
    }

    func testFileResetDropsPendingTextFromPreviousFile() throws {
        let url = temporaryFileURL()
        try "info ready\n".write(to: url, atomically: true, encoding: .utf8)

        var source = try LogFileLoader.load(url: url)
        try append("partial", to: url)

        let first = try LogTailReader.readAppendedEntries(from: source)
        source.lastReadOffset = first.nextOffset

        try "WARN restarted\n".write(to: url, atomically: true, encoding: .utf8)
        let reset = try LogTailReader.readAppendedEntries(from: source, pendingText: first.pendingText)

        XCTAssertTrue(reset.didReset)
        XCTAssertEqual(reset.entries.map(\.lineNumber), [1])
        XCTAssertEqual(reset.entries.map(\.message), ["WARN restarted"])
        XCTAssertEqual(reset.pendingText, "")
    }

    func testEmptyFileResetClearsPendingText() throws {
        let url = temporaryFileURL()
        try "info ready\n".write(to: url, atomically: true, encoding: .utf8)

        var source = try LogFileLoader.load(url: url)
        try append("partial", to: url)

        let first = try LogTailReader.readAppendedEntries(from: source)
        source.lastReadOffset = first.nextOffset

        try "".write(to: url, atomically: true, encoding: .utf8)
        let reset = try LogTailReader.readAppendedEntries(from: source, pendingText: first.pendingText)

        XCTAssertTrue(reset.didReset)
        XCTAssertTrue(reset.entries.isEmpty)
        XCTAssertEqual(reset.pendingText, "")
        XCTAssertEqual(reset.nextOffset, 0)
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("log")
    }

    private func append(_ text: String, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer {
            try? handle.close()
        }

        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))
    }
}
