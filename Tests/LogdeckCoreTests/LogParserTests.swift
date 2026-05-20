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

    func testDoesNotInferDebugFromTraceIdentifierFields() {
        let sourceID = UUID()
        let entries = LogParser.parse(
            text: """
            request completed trace_id=abc123
            request completed trace-id=abc123
            request completed trace.id=abc123
            """,
            sourceID: sourceID
        )

        XCTAssertEqual(entries.map(\.level), [.info, .info, .info])
    }

    func testInfersCriticalAndShortErrorLevels() {
        let sourceID = UUID()
        let entries = LogParser.parse(
            text: """
            CRITICAL database unavailable
            ERR connection refused
            """,
            sourceID: sourceID
        )

        XCTAssertEqual(entries.map(\.level), [.fault, .error])
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

    func testParsesJSONMetadataFields() {
        let sourceID = UUID()
        let entry = LogParser.parseLine(
            #"{"timestamp":"2026-05-19T04:10:20Z","level":"info","message":"request started","subsystem":"com.example.api","category":"network","process":"ExampleApp","sender":"ExampleBinary"}"#,
            lineNumber: 1,
            sourceID: sourceID
        )

        XCTAssertEqual(entry.subsystem, "com.example.api")
        XCTAssertEqual(entry.category, "network")
        XCTAssertEqual(entry.process, "ExampleApp")
        XCTAssertEqual(entry.sender, "ExampleBinary")
        XCTAssertTrue(entry.hasUnifiedMetadata)
    }

    func testParsesNestedJSONMetadataFields() {
        let sourceID = UUID()
        let entry = LogParser.parseLine(
            #"{"timestamp":"2026-05-19T04:10:20Z","level":"info","message":"request started","log":{"subsystem":"com.example.api","category":"network"},"process":{"name":"ExampleApp"},"sender":{"name":"ExampleBinary"}}"#,
            lineNumber: 1,
            sourceID: sourceID
        )

        XCTAssertEqual(entry.subsystem, "com.example.api")
        XCTAssertEqual(entry.category, "network")
        XCTAssertEqual(entry.process, "ExampleApp")
        XCTAssertEqual(entry.sender, "ExampleBinary")
        XCTAssertTrue(entry.hasUnifiedMetadata)
    }

    func testParsesNestedJSONAliasFields() {
        let sourceID = UUID()
        let entry = LogParser.parseLine(
            #"{"timestamp":"2026-05-19T04:10:20Z","message":"request started","log":{"level":"verbose","subsystem":"com.example.api","category":"network"},"process":{"name":"ExampleApp"},"sender":{"name":"ExampleBinary"}}"#,
            lineNumber: 1,
            sourceID: sourceID
        )

        XCTAssertEqual(entry.level, .debug)
        XCTAssertEqual(entry.subsystem, "com.example.api")
        XCTAssertEqual(entry.category, "network")
        XCTAssertEqual(entry.process, "ExampleApp")
        XCTAssertEqual(entry.sender, "ExampleBinary")
    }

    func testParsesLaterMetadataAliasWhenEarlierAliasIsEmpty() {
        let sourceID = UUID()
        let entry = LogParser.parseLine(
            #"{"timestamp":"2026-05-19T04:10:20Z","level":"info","message":"request started","subsystem":"   ","category":"","process":"","sender":"","log":{"subsystem":"com.example.api","category":"network"},"processName":"ExampleApp","senderName":"ExampleBinary"}"#,
            lineNumber: 1,
            sourceID: sourceID
        )

        XCTAssertEqual(entry.subsystem, "com.example.api")
        XCTAssertEqual(entry.category, "network")
        XCTAssertEqual(entry.process, "ExampleApp")
        XCTAssertEqual(entry.sender, "ExampleBinary")
        XCTAssertTrue(entry.hasUnifiedMetadata)
    }

    func testParsesCommonJSONLogFieldVariants() {
        let sourceID = UUID()
        let entry = LogParser.parseLine(
            #"{"@timestamp":"2026-05-19T04:10:20Z","severity_text":"WARN","body":"cache miss"}"#,
            lineNumber: 1,
            sourceID: sourceID
        )

        XCTAssertEqual(entry.level, .warning)
        XCTAssertEqual(entry.message, "cache miss")
        XCTAssertNotNil(entry.timestamp)
    }

    func testParsesLaterCoreJSONAliasesWhenEarlierAliasesAreEmptyOrInvalid() {
        let sourceID = UUID()
        let entry = LogParser.parseLine(
            #"{"timestamp":"","time":"2026-05-19T04:10:20Z","level":"unknown","severity":40,"message":"   ","body":"database unavailable"}"#,
            lineNumber: 1,
            sourceID: sourceID
        )

        XCTAssertEqual(entry.level, .error)
        XCTAssertEqual(entry.message, "database unavailable")
        XCTAssertNotNil(entry.timestamp)
    }

    func testParsesJSONTimestampValuesWithSurroundingWhitespace() {
        let sourceID = UUID()
        let isoEntry = LogParser.parseLine(
            #"{"timestamp":" 2026-05-19T04:10:20Z ","level":"info","message":"ready"}"#,
            lineNumber: 1,
            sourceID: sourceID
        )
        let plainEntry = LogParser.parseLine(
            #"{"timestamp":" 2026-05-19 04:10:20 ","level":"info","message":"ready"}"#,
            lineNumber: 2,
            sourceID: sourceID
        )

        XCTAssertNotNil(isoEntry.timestamp)
        XCTAssertNotNil(plainEntry.timestamp)
    }

    func testParsesJSONKeysCaseInsensitively() {
        let sourceID = UUID()
        let entry = LogParser.parseLine(
            #"{"Time":"2026-05-19T04:10:20Z","Level":"FATAL","Message":"kernel panic"}"#,
            lineNumber: 1,
            sourceID: sourceID
        )

        XCTAssertEqual(entry.level, .fault)
        XCTAssertEqual(entry.message, "kernel panic")
        XCTAssertNotNil(entry.timestamp)
    }

    func testParsesJSONNumericSeverity() {
        let sourceID = UUID()
        let entry = LogParser.parseLine(
            #"{"ts":"2026-05-19T04:10:20Z","severity":40,"msg":"request failed"}"#,
            lineNumber: 1,
            sourceID: sourceID
        )

        XCTAssertEqual(entry.level, .error)
        XCTAssertEqual(entry.message, "request failed")
        XCTAssertNotNil(entry.timestamp)
    }

    func testParsesJSONEpochTimestamps() throws {
        let sourceID = UUID()
        let secondsEntry = LogParser.parseLine(
            #"{"ts":1717000000,"level":"info","msg":"seconds"}"#,
            lineNumber: 1,
            sourceID: sourceID
        )
        let millisecondsEntry = LogParser.parseLine(
            #"{"timestamp":1717000000000,"level":"info","msg":"milliseconds"}"#,
            lineNumber: 2,
            sourceID: sourceID
        )
        let microsecondsEntry = LogParser.parseLine(
            #"{"timestamp":1717000000000000,"level":"info","msg":"microseconds"}"#,
            lineNumber: 3,
            sourceID: sourceID
        )
        let nanosecondsEntry = LogParser.parseLine(
            #"{"timestamp":1717000000000000000,"level":"info","msg":"nanoseconds"}"#,
            lineNumber: 4,
            sourceID: sourceID
        )

        XCTAssertEqual(try XCTUnwrap(secondsEntry.timestamp).timeIntervalSince1970, 1_717_000_000, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(millisecondsEntry.timestamp).timeIntervalSince1970, 1_717_000_000, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(microsecondsEntry.timestamp).timeIntervalSince1970, 1_717_000_000, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(nanosecondsEntry.timestamp).timeIntervalSince1970, 1_717_000_000, accuracy: 0.001)
    }

    func testShortNumericPrefixIsNotTreatedAsEpochTimestamp() {
        let entry = LogParser.parseLine(
            "123 ERROR failed",
            lineNumber: 1,
            sourceID: UUID()
        )

        XCTAssertNil(entry.timestamp)
        XCTAssertEqual(entry.level, .error)
    }

    func testPreservesBlankLinesWithoutAddingTrailingLine() {
        let sourceID = UUID()
        let entries = LogParser.parse(
            text: "INFO first\n\nERROR third\n",
            sourceID: sourceID
        )

        XCTAssertEqual(entries.map(\.lineNumber), [1, 2, 3])
        XCTAssertEqual(entries.map(\.message), ["INFO first", "", "ERROR third"])
        XCTAssertEqual(entries.map(\.level), [.info, .info, .error])
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

    func testParsesBracketedTimestampPrefix() {
        let sourceID = UUID()
        let entry = LogParser.parseLine(
            "[2026-05-19 13:10:20] ERROR failed to open file",
            lineNumber: 7,
            sourceID: sourceID
        )

        XCTAssertEqual(entry.level, .error)
        XCTAssertNotNil(entry.timestamp)
    }
}
