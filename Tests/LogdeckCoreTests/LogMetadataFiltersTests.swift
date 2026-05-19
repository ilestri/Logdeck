@testable import LogdeckCore
import XCTest

final class LogMetadataFiltersTests: XCTestCase {
    func testAppliesSubsystemProcessAndCategoryFilters() {
        let sourceID = UUID()
        let entries = [
            LogEntry(
                sourceID: sourceID,
                lineNumber: 1,
                timestamp: nil,
                level: .info,
                message: "match",
                rawText: "match",
                subsystem: "com.example.api",
                category: "network",
                process: "ExampleApp"
            ),
            LogEntry(
                sourceID: sourceID,
                lineNumber: 2,
                timestamp: nil,
                level: .info,
                message: "miss",
                rawText: "miss",
                subsystem: "com.example.worker",
                category: "jobs",
                process: "Worker"
            )
        ]
        let filters = LogMetadataFilters(subsystem: "API", process: "example", category: "net")

        XCTAssertEqual(filters.apply(to: entries).map(\.message), ["match"])
    }

    func testActiveFilterExcludesEntriesWithoutMetadata() {
        let sourceID = UUID()
        let entry = LogEntry(
            sourceID: sourceID,
            lineNumber: 1,
            timestamp: nil,
            level: .info,
            message: "plain",
            rawText: "plain"
        )

        XCTAssertTrue(LogMetadataFilters.empty.apply(to: [entry]).contains(entry))
        XCTAssertTrue(LogMetadataFilters(subsystem: "com.example").apply(to: [entry]).isEmpty)
    }
}
