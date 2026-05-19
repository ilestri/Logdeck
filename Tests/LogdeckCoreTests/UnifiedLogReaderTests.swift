@testable import LogdeckCore
import XCTest

final class UnifiedLogReaderTests: XCTestCase {
    func testZeroLimitBuildsEmptyUnifiedLogSourceWithoutStoreAccess() throws {
        let source = try UnifiedLogReader.readLocal(query: UnifiedLogQuery(intervalSinceEnd: 60, limit: 0))

        XCTAssertEqual(source.name, UnifiedLogReader.sourceName)
        XCTAssertTrue(source.entries.isEmpty)
    }

    func testBuildsSourceFromUnifiedLogRecords() {
        let archiveURL = URL(fileURLWithPath: "/tmp/system.logarchive")
        let records = [
            UnifiedLogRecord(
                date: Date(timeIntervalSince1970: 10),
                level: .error,
                subsystem: "com.example.api",
                category: "network",
                process: "ExampleApp",
                sender: "ExampleBinary",
                message: "request failed"
            ),
            UnifiedLogRecord(
                date: Date(timeIntervalSince1970: 20),
                level: .info,
                subsystem: "com.example.worker",
                category: "jobs",
                process: "Worker",
                sender: "WorkerBinary",
                message: "job completed"
            )
        ]

        let source = UnifiedLogReader.source(
            from: records,
            name: "Test Unified Logs",
            url: archiveURL,
            loadedAt: Date(timeIntervalSince1970: 30)
        )

        XCTAssertTrue(source.isFileBacked)
        XCTAssertFalse(source.supportsTail)
        XCTAssertEqual(source.url, archiveURL)
        XCTAssertEqual(source.name, "Test Unified Logs")
        XCTAssertEqual(source.entries.map(\.lineNumber), [1, 2])
        XCTAssertEqual(source.entries.map(\.timestamp), records.map(\.date))
        XCTAssertEqual(source.entries.map(\.level), [.error, .info])
        XCTAssertEqual(source.entries.map(\.message), ["request failed", "job completed"])
        XCTAssertEqual(source.entries[0].process, "ExampleApp")
        XCTAssertEqual(source.entries[0].subsystem, "com.example.api")
        XCTAssertEqual(source.entries[0].category, "network")
        XCTAssertEqual(source.entries[0].sender, "ExampleBinary")
        XCTAssertTrue(source.entries[0].rawText.contains("process=ExampleApp"))
        XCTAssertTrue(source.entries[0].rawText.contains("subsystem=com.example.api"))
        XCTAssertTrue(source.entries[0].rawText.contains("category=network"))
    }

    func testDetectsLogArchiveURLsCaseInsensitively() {
        XCTAssertTrue(UnifiedLogReader.isLogArchive(URL(fileURLWithPath: "/tmp/System.LOGARCHIVE")))
        XCTAssertFalse(UnifiedLogReader.isLogArchive(URL(fileURLWithPath: "/tmp/system.log")))
    }
}
