@testable import LogdeckCore
import XCTest

final class DiagnosticReporterTests: XCTestCase {
    func testCapsRecentEventsAndRedactsHomeDirectory() {
        let reporter = DiagnosticReporter(maxEvents: 2, currentDate: fixedDate)
        reporter.record(severity: .info, category: "file", message: "opened first.log")
        reporter.record(severity: .warning, category: "tail", message: "reset detected")
        reporter.record(severity: .error, category: "file", message: "failed \(NSHomeDirectory())/secret.log")

        let report = reporter.makeReport(workspace: makeWorkspace())

        XCTAssertEqual(report.recentEvents.map(\.severity), [.warning, .error])
        XCTAssertEqual(report.recentEvents.map(\.category), ["tail", "file"])
        XCTAssertEqual(report.recentEvents.last?.message, "failed ~/secret.log")
    }

    func testWritesJSONReport() throws {
        let reporter = DiagnosticReporter(currentDate: fixedDate)
        reporter.record(severity: .error, category: "workspace", message: "failed to open workspace")
        let report = reporter.makeReport(workspace: makeWorkspace())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        try reporter.write(report, to: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DiagnosticReport.self, from: Data(contentsOf: url))
        XCTAssertEqual(decoded.recentEvents.first?.message, "failed to open workspace")
        XCTAssertEqual(decoded.workspace.sources.first?.name, "app.log")
    }
}

@MainActor
final class LogWorkspaceDiagnosticsTests: XCTestCase {
    func testDiagnosticReportSummarizesWorkspaceWithoutSourcePaths() throws {
        let sourceID = UUID()
        let source = LogSource(
            id: sourceID,
            url: URL(fileURLWithPath: "\(NSHomeDirectory())/private/app.log"),
            name: "app.log",
            loadedAt: fixedDate(),
            entries: [
                LogEntry(sourceID: sourceID, lineNumber: 1, timestamp: nil, level: .error, message: "failed", rawText: "error failed")
            ]
        )
        let viewModel = LogWorkspaceViewModel(
            diagnosticReporter: DiagnosticReporter(currentDate: fixedDate)
        )

        viewModel.sources = [source]
        let report = viewModel.makeDiagnosticReport()

        XCTAssertEqual(report.workspace.selectedSourceName, "app.log")
        XCTAssertEqual(report.workspace.totalEntryCount, 1)
        XCTAssertEqual(report.workspace.visibleEntryCount, 1)
        XCTAssertEqual(report.workspace.issueEntryCount, 1)
        XCTAssertEqual(report.workspace.sources.first?.kind, .file)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(report), as: UTF8.self)
        XCTAssertFalse(json.contains(NSHomeDirectory()))
    }
}

private func fixedDate() -> Date {
    Date(timeIntervalSince1970: 1_700_000_000)
}

private func makeWorkspace() -> DiagnosticWorkspaceSnapshot {
    DiagnosticWorkspaceSnapshot(
        displayMode: .source,
        queryActive: false,
        enabledLevels: LogLevel.allCases,
        metadataFiltersActive: false,
        pinnedTokenLabel: nil,
        selectedSourceName: "app.log",
        totalEntryCount: 12,
        visibleEntryCount: 8,
        issueEntryCount: 1,
        sources: [
            DiagnosticSourceSnapshot(
                name: "app.log",
                kind: .file,
                entryCount: 12,
                isTruncated: false,
                supportsTail: true,
                loadedAt: fixedDate()
            )
        ]
    )
}
