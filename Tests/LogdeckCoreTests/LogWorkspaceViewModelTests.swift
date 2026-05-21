@testable import LogdeckCore
import XCTest

@MainActor
final class LogWorkspaceViewModelTests: XCTestCase {
    func testBuildsSelectedEntryContextFromOriginalSource() {
        let entries = makeEntries()
        let viewModel = makeViewModel(entries: entries, selectedEntry: entries[3])

        XCTAssertEqual(viewModel.selectedEntryContext.map(\.lineNumber), [1, 2, 3, 4, 5])
    }

    func testNavigatesVisibleIssueEntriesWithWraparound() {
        let entries = makeEntries()
        let viewModel = makeViewModel(entries: entries, selectedEntry: entries[0])

        viewModel.selectNextIssue()
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 2)
        XCTAssertEqual(viewModel.issueStatusLabel, "이슈 1 / 2")

        viewModel.selectNextIssue()
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 4)
        XCTAssertEqual(viewModel.issueStatusLabel, "이슈 2 / 2")

        viewModel.selectNextIssue()
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 2)

        viewModel.selectPreviousIssue()
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 4)
    }

    func testIssueNavigationRespectsCurrentFilters() {
        let entries = makeEntries()
        let viewModel = makeViewModel(entries: entries, selectedEntry: entries[0])
        viewModel.query = "database"

        viewModel.selectNextIssue()

        XCTAssertEqual(viewModel.visibleIssueEntries.map(\.lineNumber), [4])
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 4)
    }

    func testIssueNavigationFollowsTimelineOrderAcrossSources() {
        let firstSourceID = UUID()
        let secondSourceID = UUID()
        let firstIssue = LogEntry(
            sourceID: firstSourceID,
            lineNumber: 2,
            timestamp: date(10),
            level: .error,
            message: "first issue",
            rawText: "error first"
        )
        let secondIssue = LogEntry(
            sourceID: secondSourceID,
            lineNumber: 1,
            timestamp: date(20),
            level: .fault,
            message: "second issue",
            rawText: "fault second"
        )
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [
            LogSource(id: firstSourceID, url: URL(fileURLWithPath: "/tmp/first.log"), entries: [firstIssue]),
            LogSource(id: secondSourceID, url: URL(fileURLWithPath: "/tmp/second.log"), entries: [secondIssue])
        ]
        viewModel.displayMode = .timeline
        viewModel.selectedEntryID = firstIssue.id

        viewModel.selectNextIssue()
        XCTAssertEqual(viewModel.selectedEntry?.message, "second issue")

        viewModel.selectPreviousIssue()
        XCTAssertEqual(viewModel.selectedEntry?.message, "first issue")
    }

    func testVisibleEntryNavigationWrapsThroughVisibleRows() {
        let entries = makeEntries()
        let viewModel = makeViewModel(entries: entries, selectedEntry: entries[0])

        viewModel.selectNextVisibleEntry()
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 2)

        viewModel.selectPreviousVisibleEntry()
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 1)

        viewModel.selectPreviousVisibleEntry()
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 5)

        viewModel.selectNextVisibleEntry()
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 1)
    }

    func testVisibleEntryNavigationRespectsCurrentFilters() {
        let entries = makeEntries()
        let viewModel = makeViewModel(entries: entries, selectedEntry: entries[0])

        viewModel.enabledLevels = [.error, .fault]

        viewModel.selectNextVisibleEntry()
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 4)

        viewModel.selectNextVisibleEntry()
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 2)
    }

    func testVisibleEntriesRebuildWhenLevelFilterChanges() {
        let entries = makeEntries()
        let viewModel = makeViewModel(entries: entries, selectedEntry: entries[0])

        viewModel.enabledLevels = [.error]

        XCTAssertEqual(viewModel.visibleEntries.map(\.lineNumber), [2])
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 2)
    }

    func testLevelFilterSetterIsIdempotent() {
        let entries = makeEntries()
        let viewModel = makeViewModel(entries: entries, selectedEntry: entries[0])

        viewModel.setLevel(.debug, enabled: false)
        viewModel.setLevel(.debug, enabled: false)
        viewModel.setLevel(.error, enabled: true)
        viewModel.setLevel(.error, enabled: true)

        XCTAssertFalse(viewModel.enabledLevels.contains(.debug))
        XCTAssertTrue(viewModel.enabledLevels.contains(.error))
    }

    func testSelectedEntryFallsBackToVisibleEntryWhenSelectionIsFilteredOut() {
        let entries = makeEntries()
        let viewModel = makeViewModel(entries: entries, selectedEntry: entries[0])

        viewModel.enabledLevels = [.error]
        viewModel.selectedEntryID = entries[0].id

        XCTAssertEqual(viewModel.visibleEntries.map(\.lineNumber), [2])
        XCTAssertEqual(viewModel.selectedEntry?.lineNumber, 2)
    }

    func testVisibleEntriesRebuildWhenSourceChanges() {
        let firstSourceID = UUID()
        let secondSourceID = UUID()
        let firstSource = LogSource(
            id: firstSourceID,
            url: URL(fileURLWithPath: "/tmp/first.log"),
            entries: [
                LogEntry(sourceID: firstSourceID, lineNumber: 1, timestamp: nil, level: .info, message: "first", rawText: "info first")
            ]
        )
        let secondSource = LogSource(
            id: secondSourceID,
            url: URL(fileURLWithPath: "/tmp/second.log"),
            entries: [
                LogEntry(sourceID: secondSourceID, lineNumber: 1, timestamp: nil, level: .error, message: "second", rawText: "error second")
            ]
        )
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [firstSource, secondSource]
        viewModel.selectedSourceID = secondSourceID

        XCTAssertEqual(viewModel.visibleEntries.map(\.message), ["second"])
        XCTAssertEqual(viewModel.selectedEntry?.message, "second")
    }

    func testStaleSelectedSourceFallsBackToFirstSource() {
        let source = makeSource(path: "/tmp/current.log", messages: ["current"])
        let viewModel = LogWorkspaceViewModel()

        viewModel.selectedSourceID = UUID()
        viewModel.sources = [source]

        XCTAssertEqual(viewModel.selectedSource?.id, source.id)
        XCTAssertEqual(viewModel.visibleEntries.map(\.message), ["current"])
    }

    func testRemoveSelectedSourceSelectsAdjacentSource() {
        let firstSource = makeSource(path: "/tmp/api.log", messages: ["api"])
        let secondSource = makeSource(path: "/tmp/worker.log", messages: ["worker"])
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [firstSource, secondSource]
        viewModel.selectedSourceID = firstSource.id

        viewModel.removeSource(firstSource)

        XCTAssertEqual(viewModel.sources.map(\.id), [secondSource.id])
        XCTAssertEqual(viewModel.selectedSourceID, secondSource.id)
        XCTAssertEqual(viewModel.visibleEntries.map(\.message), ["worker"])
        XCTAssertEqual(viewModel.statusMessage, "api.log을(를) 소스에서 닫았습니다.")
    }

    func testRemoveLastSourceClearsWorkspaceSelection() {
        let source = makeSource(path: "/tmp/only.log", messages: ["only"])
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [source]
        viewModel.selectedSourceID = source.id

        viewModel.removeSource(source)

        XCTAssertTrue(viewModel.sources.isEmpty)
        XCTAssertNil(viewModel.selectedSourceID)
        XCTAssertTrue(viewModel.visibleEntries.isEmpty)
        XCTAssertNil(viewModel.selectedEntry)
    }

    func testTimelineModeMergesSourcesByTimestamp() {
        let firstSourceID = UUID()
        let secondSourceID = UUID()
        let firstSource = LogSource(
            id: firstSourceID,
            url: URL(fileURLWithPath: "/tmp/api.log"),
            name: "api.log",
            entries: [
                LogEntry(sourceID: firstSourceID, lineNumber: 1, timestamp: date(30), level: .info, message: "api later", rawText: "api later"),
                LogEntry(sourceID: firstSourceID, lineNumber: 2, timestamp: nil, level: .info, message: "api no time", rawText: "api no time")
            ]
        )
        let secondSource = LogSource(
            id: secondSourceID,
            url: URL(fileURLWithPath: "/tmp/worker.log"),
            name: "worker.log",
            entries: [
                LogEntry(sourceID: secondSourceID, lineNumber: 1, timestamp: date(10), level: .info, message: "worker first", rawText: "worker first"),
                LogEntry(sourceID: secondSourceID, lineNumber: 2, timestamp: date(20), level: .error, message: "worker error", rawText: "worker error")
            ]
        )
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [firstSource, secondSource]
        viewModel.displayMode = .timeline

        XCTAssertEqual(viewModel.visibleEntries.map(\.message), [
            "worker first",
            "worker error",
            "api later",
            "api no time"
        ])
        XCTAssertEqual(viewModel.totalEntryCount, 4)
        XCTAssertEqual(viewModel.sourceName(for: viewModel.visibleEntries[1]), "worker.log")
    }

    func testTimelineContextUsesOriginalSource() {
        let firstSourceID = UUID()
        let secondSourceID = UUID()
        let selected = LogEntry(sourceID: secondSourceID, lineNumber: 2, timestamp: date(15), level: .error, message: "selected", rawText: "error selected")
        let firstSource = LogSource(
            id: firstSourceID,
            url: URL(fileURLWithPath: "/tmp/first.log"),
            entries: [
                LogEntry(sourceID: firstSourceID, lineNumber: 1, timestamp: date(10), level: .info, message: "other", rawText: "info other")
            ]
        )
        let secondSource = LogSource(
            id: secondSourceID,
            url: URL(fileURLWithPath: "/tmp/second.log"),
            name: "second.log",
            entries: [
                LogEntry(sourceID: secondSourceID, lineNumber: 1, timestamp: date(12), level: .info, message: "before", rawText: "info before"),
                selected,
                LogEntry(sourceID: secondSourceID, lineNumber: 3, timestamp: date(18), level: .info, message: "after", rawText: "info after")
            ]
        )
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [firstSource, secondSource]
        viewModel.displayMode = .timeline
        viewModel.selectedEntryID = selected.id

        XCTAssertEqual(viewModel.selectedEntrySource?.name, "second.log")
        XCTAssertEqual(viewModel.selectedEntryContext.map(\.message), ["before", "selected", "after"])
    }

    func testPinnedTokenFiltersTimelineAcrossSources() {
        let firstSourceID = UUID()
        let secondSourceID = UUID()
        let firstSource = LogSource(
            id: firstSourceID,
            url: URL(fileURLWithPath: "/tmp/api.log"),
            entries: [
                LogEntry(sourceID: firstSourceID, lineNumber: 1, timestamp: date(10), level: .info, message: "api start", rawText: "request_id=REQ-7 api start"),
                LogEntry(sourceID: firstSourceID, lineNumber: 2, timestamp: date(20), level: .info, message: "api other", rawText: "request_id=REQ-8 api other")
            ]
        )
        let secondSource = LogSource(
            id: secondSourceID,
            url: URL(fileURLWithPath: "/tmp/worker.log"),
            entries: [
                LogEntry(sourceID: secondSourceID, lineNumber: 1, timestamp: date(15), level: .error, message: "worker failed", rawText: "trace_id=REQ-7 worker failed")
            ]
        )
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [firstSource, secondSource]
        viewModel.displayMode = .timeline
        viewModel.pin(LogCorrelationToken(kind: .requestID, value: "REQ-7"))

        XCTAssertEqual(viewModel.visibleEntries.map(\.message), ["api start", "worker failed"])
    }

    func testSelectedEntryTokensExposePinCandidates() {
        let sourceID = UUID()
        let entry = LogEntry(
            sourceID: sourceID,
            lineNumber: 1,
            timestamp: nil,
            level: .info,
            message: "selected",
            rawText: "request_id=REQ-7 trace_id=TRACE-9"
        )
        let viewModel = makeViewModel(entries: [entry], selectedEntry: entry)

        XCTAssertEqual(viewModel.selectedEntryTokens.map(\.label), ["요청: REQ-7", "추적: TRACE-9"])
    }

    func testMetadataFiltersNarrowUnifiedLogEntriesAfterLevelFilter() {
        let source = UnifiedLogReader.source(
            from: [
                UnifiedLogRecord(
                    date: date(1),
                    level: .error,
                    subsystem: "com.example.api",
                    category: "network",
                    process: "ExampleApp",
                    sender: "ExampleBinary",
                    message: "api failed"
                ),
                UnifiedLogRecord(
                    date: date(2),
                    level: .info,
                    subsystem: "com.example.api",
                    category: "network",
                    process: "ExampleApp",
                    sender: "ExampleBinary",
                    message: "api ok"
                ),
                UnifiedLogRecord(
                    date: date(3),
                    level: .error,
                    subsystem: "com.example.worker",
                    category: "jobs",
                    process: "Worker",
                    sender: "WorkerBinary",
                    message: "worker failed"
                )
            ]
        )
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [source]
        viewModel.enabledLevels = [.error]
        viewModel.metadataFilters = LogMetadataFilters(subsystem: "api", process: "example", category: "net")

        XCTAssertTrue(viewModel.showsMetadataFilters)
        XCTAssertEqual(viewModel.visibleEntries.map(\.message), ["api failed"])
    }

    func testWhitespaceOnlyMetadataDoesNotEnableMetadataFilters() {
        let sourceID = UUID()
        let source = LogSource(
            id: sourceID,
            url: URL(fileURLWithPath: "/tmp/plain.log"),
            entries: [
                LogEntry(
                    sourceID: sourceID,
                    lineNumber: 1,
                    timestamp: nil,
                    level: .info,
                    message: "plain",
                    rawText: "plain",
                    subsystem: " ",
                    category: "\n",
                    process: "\t",
                    sender: ""
                )
            ]
        )
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [source]

        XCTAssertFalse(viewModel.showsMetadataFilters)
        XCTAssertFalse(viewModel.visibleEntries[0].hasUnifiedMetadata)
    }

    func testClearsMetadataFilters() {
        let viewModel = LogWorkspaceViewModel()

        viewModel.metadataFilters = LogMetadataFilters(subsystem: "api")
        viewModel.clearMetadataFilters()

        XCTAssertEqual(viewModel.metadataFilters, .empty)
    }

    func testReportsActiveFilterStateAndInvalidRegex() {
        let entries = makeEntries()
        let viewModel = makeViewModel(entries: entries, selectedEntry: entries[0])

        XCTAssertFalse(viewModel.hasActiveFilters)
        XCTAssertEqual(viewModel.filterSummary, "전체 5줄")

        viewModel.query = #"/[/"#

        XCTAssertTrue(viewModel.hasActiveFilters)
        XCTAssertEqual(viewModel.queryWarning, "정규식이 올바르지 않습니다.")
        XCTAssertEqual(viewModel.filterSummary, "0 / 5줄 표시 중")
    }

    func testClearAllFiltersResetsVisibleNarrowingState() {
        let entries = makeEntries()
        let viewModel = makeViewModel(entries: entries, selectedEntry: entries[0])

        viewModel.query = "database"
        viewModel.enabledLevels = [.error]
        viewModel.metadataFilters = LogMetadataFilters(subsystem: "api")
        viewModel.pin(LogCorrelationToken(kind: .requestID, value: "REQ-7"))

        viewModel.clearAllFilters()

        XCTAssertFalse(viewModel.hasActiveFilters)
        XCTAssertEqual(viewModel.query, "")
        XCTAssertEqual(viewModel.enabledLevels, Set(LogLevel.allCases))
        XCTAssertEqual(viewModel.metadataFilters, .empty)
        XCTAssertNil(viewModel.pinnedToken)
        XCTAssertEqual(viewModel.statusMessage, "모든 필터를 지웠습니다.")
        XCTAssertEqual(viewModel.visibleEntries.count, entries.count)
    }

    func testWorkspaceSnapshotCapturesSourcesAndFilters() {
        let firstSource = makeSource(path: "/tmp/api.log", messages: ["api"])
        let secondSource = makeSource(path: "/tmp/worker.log", messages: ["worker"])
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [firstSource, secondSource]
        viewModel.selectedSourceID = secondSource.id
        viewModel.displayMode = .timeline
        viewModel.query = "REQ-7"
        viewModel.enabledLevels = [.error, .fault]
        viewModel.metadataFilters = LogMetadataFilters(subsystem: "com.example")
        viewModel.pin(LogCorrelationToken(kind: .requestID, value: "REQ-7"))

        let snapshot = viewModel.workspaceSnapshot()

        XCTAssertEqual(snapshot.sourcePaths, ["/tmp/api.log", "/tmp/worker.log"])
        XCTAssertEqual(snapshot.selectedSourcePath, "/tmp/worker.log")
        XCTAssertEqual(snapshot.displayMode, .timeline)
        XCTAssertEqual(snapshot.query, "REQ-7")
        XCTAssertEqual(snapshot.enabledLevels, [.error, .fault])
        XCTAssertEqual(snapshot.metadataFilters, LogMetadataFilters(subsystem: "com.example"))
        XCTAssertEqual(snapshot.pinnedToken, LogCorrelationToken(kind: .requestID, value: "REQ-7"))
    }

    func testWorkspaceSnapshotSkipsUnifiedLogSources() {
        let fileSource = makeSource(path: "/tmp/api.log", messages: ["api"])
        let unifiedSource = UnifiedLogReader.source(
            from: [
                UnifiedLogRecord(
                    date: date(1),
                    level: .info,
                    subsystem: "com.example",
                    category: "default",
                    process: "Example",
                    sender: "Example",
                    message: "unified"
                )
            ]
        )
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [unifiedSource, fileSource]
        viewModel.selectedSourceID = unifiedSource.id

        let snapshot = viewModel.workspaceSnapshot()

        XCTAssertEqual(snapshot.sourcePaths, ["/tmp/api.log"])
        XCTAssertNil(snapshot.selectedSourcePath)
    }

    func testWorkspaceCanSaveOnlyWhenFileBackedSourcesExist() {
        let unifiedSource = UnifiedLogReader.source(
            from: [
                UnifiedLogRecord(
                    date: date(1),
                    level: .info,
                    subsystem: "com.example",
                    category: "default",
                    process: "Example",
                    sender: "Example",
                    message: "unified"
                )
            ]
        )
        let fileSource = makeSource(path: "/tmp/api.log", messages: ["api"])
        let viewModel = LogWorkspaceViewModel()

        XCTAssertFalse(viewModel.canSaveWorkspace)

        viewModel.sources = [unifiedSource]
        XCTAssertFalse(viewModel.canSaveWorkspace)

        viewModel.sources = [unifiedSource, fileSource]
        XCTAssertTrue(viewModel.canSaveWorkspace)
    }

    func testWorkspaceSnapshotKeepsLogArchiveSources() {
        let archiveURL = URL(fileURLWithPath: "/tmp/system.logarchive")
        let archiveSource = UnifiedLogReader.source(
            from: [
                UnifiedLogRecord(
                    date: date(1),
                    level: .fault,
                    subsystem: "com.example",
                    category: "archive",
                    process: "Example",
                    sender: "Example",
                    message: "archived"
                )
            ],
            name: "system.logarchive",
            url: archiveURL
        )
        let viewModel = LogWorkspaceViewModel()

        viewModel.sources = [archiveSource]
        viewModel.selectedSourceID = archiveSource.id

        let snapshot = viewModel.workspaceSnapshot()

        XCTAssertFalse(archiveSource.supportsTail)
        XCTAssertEqual(snapshot.sourcePaths, [archiveURL.path])
        XCTAssertEqual(snapshot.selectedSourcePath, archiveURL.path)
    }

    func testRestoreWorkspaceAppliesSavedStateToLoadedSources() {
        let firstSource = makeSource(path: "/tmp/api.log", messages: ["request_id=REQ-7 api", "request_id=REQ-8 other"])
        let secondSource = makeSource(path: "/tmp/worker.log", messages: ["REQ-7 worker"])
        let document = LogWorkspaceDocument(
            sourcePaths: ["/tmp/api.log", "/tmp/worker.log"],
            selectedSourcePath: "/tmp/worker.log",
            displayMode: .timeline,
            query: "",
            enabledLevels: [.info],
            pinnedToken: LogCorrelationToken(kind: .requestID, value: "REQ-7")
        )
        let viewModel = LogWorkspaceViewModel()

        viewModel.restoreWorkspace(document, sources: [firstSource, secondSource])

        XCTAssertEqual(viewModel.selectedSourceID, secondSource.id)
        XCTAssertEqual(viewModel.displayMode, .timeline)
        XCTAssertEqual(viewModel.pinnedToken, LogCorrelationToken(kind: .requestID, value: "REQ-7"))
        XCTAssertEqual(viewModel.visibleEntries.map(\.message), ["request_id=REQ-7 api", "REQ-7 worker"])
    }

    func testRestoreWorkspaceAppliesMetadataFilters() {
        let source = UnifiedLogReader.source(
            from: [
                UnifiedLogRecord(
                    date: date(1),
                    level: .info,
                    subsystem: "com.example.api",
                    category: "network",
                    process: "Example",
                    sender: "Example",
                    message: "api"
                ),
                UnifiedLogRecord(
                    date: date(2),
                    level: .info,
                    subsystem: "com.example.worker",
                    category: "jobs",
                    process: "Worker",
                    sender: "Worker",
                    message: "worker"
                )
            ],
            url: URL(fileURLWithPath: "/tmp/system.logarchive")
        )
        let document = LogWorkspaceDocument(
            sourcePaths: ["/tmp/system.logarchive"],
            selectedSourcePath: "/tmp/system.logarchive",
            displayMode: .source,
            query: "",
            enabledLevels: [.info],
            metadataFilters: LogMetadataFilters(subsystem: "api", category: "network"),
            pinnedToken: nil
        )
        let viewModel = LogWorkspaceViewModel()

        viewModel.restoreWorkspace(document, sources: [source])

        XCTAssertEqual(viewModel.metadataFilters, LogMetadataFilters(subsystem: "api", category: "network"))
        XCTAssertEqual(viewModel.visibleEntries.map(\.message), ["api"])
    }

    private func makeViewModel(entries: [LogEntry], selectedEntry: LogEntry) -> LogWorkspaceViewModel {
        let viewModel = LogWorkspaceViewModel()
        let source = LogSource(
            id: selectedEntry.sourceID,
            url: URL(fileURLWithPath: "/tmp/logdeck-test.log"),
            entries: entries
        )

        viewModel.sources = [source]
        viewModel.selectedSourceID = source.id
        viewModel.selectedEntryID = selectedEntry.id
        return viewModel
    }

    private func makeEntries() -> [LogEntry] {
        let sourceID = UUID()
        return [
            LogEntry(sourceID: sourceID, lineNumber: 1, timestamp: nil, level: .info, message: "ready", rawText: "info ready"),
            LogEntry(sourceID: sourceID, lineNumber: 2, timestamp: nil, level: .error, message: "request failed", rawText: "error request failed"),
            LogEntry(sourceID: sourceID, lineNumber: 3, timestamp: nil, level: .warning, message: "cache slow", rawText: "warn cache slow"),
            LogEntry(sourceID: sourceID, lineNumber: 4, timestamp: nil, level: .fault, message: "database panic", rawText: "fatal database panic"),
            LogEntry(sourceID: sourceID, lineNumber: 5, timestamp: nil, level: .info, message: "recovered", rawText: "info recovered")
        ]
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }

    private func makeSource(path: String, messages: [String]) -> LogSource {
        let sourceID = UUID()
        return LogSource(
            id: sourceID,
            url: URL(fileURLWithPath: path),
            entries: messages.enumerated().map { index, message in
                LogEntry(
                    sourceID: sourceID,
                    lineNumber: index + 1,
                    timestamp: date(TimeInterval(index + 1)),
                    level: .info,
                    message: message,
                    rawText: message
                )
            }
        )
    }
}
