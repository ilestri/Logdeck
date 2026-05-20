@testable import LogdeckCore
import XCTest

final class LogCorrelationExtractorTests: XCTestCase {
    func testExtractsTokensFromJSONAndLogfmt() {
        let tokens = LogCorrelationExtractor.tokens(
            from: #"{"requestId":"REQ-123","trace_id":"abc.def"} tx_id=TX-9"#
        )

        XCTAssertEqual(tokens.map(\.kind), [.requestID, .traceID, .transactionID])
        XCTAssertEqual(tokens.map(\.value), ["REQ-123", "abc.def", "TX-9"])
    }

    func testExtractsDottedCorrelationKeys() {
        let tokens = LogCorrelationExtractor.tokens(
            from: #"request.id=REQ-1 trace.id=TRACE-2 span.id=SPAN-3 correlation.id=CORR-4 session.id=SID-5 transaction.id=TX-6"#
        )

        XCTAssertEqual(tokens.map(\.kind), [.requestID, .traceID, .traceID, .correlationID, .sessionID, .transactionID])
        XCTAssertEqual(tokens.map(\.value), ["REQ-1", "TRACE-2", "SPAN-3", "CORR-4", "SID-5", "TX-6"])
    }

    func testDeduplicatesRepeatedTokens() {
        let tokens = LogCorrelationExtractor.tokens(
            from: #"request_id=REQ-123 requestId=REQ-123 trace_id=TRACE-1"#
        )

        XCTAssertEqual(tokens.map(\.id), [
            "requestID:REQ-123",
            "traceID:TRACE-1"
        ])
    }

    func testMatchesExactTokenOrRawValue() {
        let sourceID = UUID()
        let token = LogCorrelationToken(kind: .requestID, value: "REQ-123")
        let keyed = LogEntry(sourceID: sourceID, lineNumber: 1, timestamp: nil, level: .info, message: "keyed", rawText: "request_id=REQ-123 started")
        let rawOnly = LogEntry(sourceID: sourceID, lineNumber: 2, timestamp: nil, level: .info, message: "raw", rawText: "continuing REQ-123")
        let miss = LogEntry(sourceID: sourceID, lineNumber: 3, timestamp: nil, level: .info, message: "miss", rawText: "request_id=REQ-999")

        XCTAssertTrue(LogCorrelationExtractor.matches(keyed, token: token))
        XCTAssertTrue(LogCorrelationExtractor.matches(rawOnly, token: token))
        XCTAssertFalse(LogCorrelationExtractor.matches(miss, token: token))
    }

    func testRawValueMatchRequiresIdentifierBoundary() {
        let sourceID = UUID()
        let token = LogCorrelationToken(kind: .requestID, value: "REQ-9")
        let prefixOnly = LogEntry(sourceID: sourceID, lineNumber: 1, timestamp: nil, level: .info, message: "prefix", rawText: "request_id=REQ-999")
        let exact = LogEntry(sourceID: sourceID, lineNumber: 2, timestamp: nil, level: .info, message: "exact", rawText: "completed REQ-9")

        XCTAssertFalse(LogCorrelationExtractor.matches(prefixOnly, token: token))
        XCTAssertTrue(LogCorrelationExtractor.matches(exact, token: token))
    }
}
