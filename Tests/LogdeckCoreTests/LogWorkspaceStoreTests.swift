@testable import LogdeckCore
import XCTest

final class LogWorkspaceStoreTests: XCTestCase {
    func testWritesAndReadsWorkspaceDocument() throws {
        let url = temporaryURL(filename: "workspace.logdeck")
        let document = LogWorkspaceDocument(
            sourcePaths: ["/tmp/api.log", "/tmp/worker.log"],
            selectedSourcePath: "/tmp/worker.log",
            displayMode: .timeline,
            query: "/error|fault/",
            enabledLevels: [.error, .fault],
            metadataFilters: LogMetadataFilters(subsystem: "com.example", process: "api", category: "network"),
            pinnedToken: LogCorrelationToken(kind: .requestID, value: "REQ-42")
        )

        try LogWorkspaceStore.write(document, to: url)
        let restored = try LogWorkspaceStore.read(from: url)

        XCTAssertEqual(restored, document)
    }

    func testReadsWorkspaceDocumentWithoutMetadataFilters() throws {
        let url = temporaryURL(filename: "legacy.logdeck")
        let json = """
        {
          "displayMode" : "source",
          "enabledLevels" : [
            "info",
            "error"
          ],
          "query" : "",
          "selectedSourcePath" : "/tmp/api.log",
          "sourcePaths" : [
            "/tmp/api.log"
          ],
          "version" : 1
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        try data.write(to: url)
        let restored = try LogWorkspaceStore.read(from: url)

        XCTAssertNil(restored.metadataFilters)
        XCTAssertEqual(restored.sourcePaths, ["/tmp/api.log"])
        XCTAssertEqual(restored.enabledLevels, [.info, .error])
    }

    func testReadsWorkspaceDocumentWithoutVersion() throws {
        let url = temporaryURL(filename: "unversioned.logdeck")
        let json = """
        {
          "displayMode" : "source",
          "enabledLevels" : [
            "debug",
            "info",
            "warning",
            "error",
            "fault"
          ],
          "query" : "",
          "selectedSourcePath" : "/tmp/api.log",
          "sourcePaths" : [
            "/tmp/api.log"
          ]
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        try data.write(to: url)
        let restored = try LogWorkspaceStore.read(from: url)

        XCTAssertEqual(restored.version, LogWorkspaceDocument.currentVersion)
        XCTAssertEqual(restored.sourcePaths, ["/tmp/api.log"])
    }

    func testReadsMinimalLegacyWorkspaceDocumentWithDefaultViewState() throws {
        let url = temporaryURL(filename: "minimal-legacy.logdeck")
        let json = """
        {
          "selectedSourcePath" : "/tmp/api.log",
          "sourcePaths" : [
            "/tmp/api.log"
          ],
          "version" : 1
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        try data.write(to: url)
        let restored = try LogWorkspaceStore.read(from: url)

        XCTAssertEqual(restored.displayMode, .source)
        XCTAssertEqual(restored.query, "")
        XCTAssertEqual(restored.enabledLevels, LogLevel.allCases)
        XCTAssertEqual(restored.sourcePaths, ["/tmp/api.log"])
    }

    func testRejectsFutureWorkspaceVersion() throws {
        let url = temporaryURL(filename: "future.logdeck")
        let futureVersion = LogWorkspaceDocument.currentVersion + 1
        let document = LogWorkspaceDocument(
            version: futureVersion,
            sourcePaths: ["/tmp/api.log"],
            selectedSourcePath: "/tmp/api.log",
            displayMode: .source,
            query: "",
            enabledLevels: LogLevel.allCases,
            pinnedToken: nil
        )

        try LogWorkspaceStore.write(document, to: url)

        XCTAssertThrowsError(try LogWorkspaceStore.read(from: url)) { error in
            XCTAssertEqual(error.localizedDescription, "Unsupported workspace version \(futureVersion).")
        }
    }

    private func temporaryURL(filename: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(filename)")
    }
}
