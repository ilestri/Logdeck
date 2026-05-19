@testable import LogdeckCore
import XCTest

final class LogQueryFilterTests: XCTestCase {
    func testFiltersByLevelAndText() {
        let sourceID = UUID()
        let entries = [
            LogEntry(sourceID: sourceID, lineNumber: 1, timestamp: nil, level: .info, message: "ready", rawText: "info ready"),
            LogEntry(sourceID: sourceID, lineNumber: 2, timestamp: nil, level: .error, message: "database failed", rawText: "error database failed"),
            LogEntry(sourceID: sourceID, lineNumber: 3, timestamp: nil, level: .warning, message: "cache slow", rawText: "warn cache slow")
        ]

        let filter = LogQueryFilter(query: "DATABASE", enabledLevels: [.error, .warning])

        XCTAssertEqual(filter.apply(to: entries).map(\.lineNumber), [2])
    }

    func testSupportsSlashDelimitedRegex() {
        let sourceID = UUID()
        let entries = [
            LogEntry(sourceID: sourceID, lineNumber: 1, timestamp: nil, level: .info, message: "request id=abc", rawText: "request id=abc"),
            LogEntry(sourceID: sourceID, lineNumber: 2, timestamp: nil, level: .info, message: "request id=123", rawText: "request id=123")
        ]

        let filter = LogQueryFilter(query: #"/id=\d+/"#, enabledLevels: [.info])

        XCTAssertEqual(filter.apply(to: entries).map(\.lineNumber), [2])
    }
}

