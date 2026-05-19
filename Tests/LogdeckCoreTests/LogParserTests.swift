@testable import LogdeckCore
import XCTest

final class LogParserTests: XCTestCase {
    func testInfersCommonLevels() {
        let sourceID = UUID()
        let entries = LogParser.parse(
            text: """
            DEBUG booting
            info ready
            WARN slow response
            ERROR request failed
            fatal crash
            """,
            sourceID: sourceID
        )

        XCTAssertEqual(entries.map(\.level), [.debug, .info, .warning, .error, .fault])
    }

    func testParsesJSONLineFields() {
        let sourceID = UUID()
        let entry = LogParser.parseLine(
            #"{"timestamp":"2026-05-19T04:10:20Z","level":"error","message":"database unavailable"}"#,
            lineNumber: 1,
            sourceID: sourceID
        )

        XCTAssertEqual(entry.level, .error)
        XCTAssertEqual(entry.message, "database unavailable")
        XCTAssertNotNil(entry.timestamp)
    }

    func testParsesPlainTimestampPrefix() {
        let sourceID = UUID()
        let entry = LogParser.parseLine(
            "2026-05-19 13:10:20 ERROR failed to open file",
            lineNumber: 7,
            sourceID: sourceID
        )

        XCTAssertEqual(entry.lineNumber, 7)
        XCTAssertEqual(entry.level, .error)
        XCTAssertNotNil(entry.timestamp)
    }
}

