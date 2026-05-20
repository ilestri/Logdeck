import Combine
import Foundation

@MainActor
final class LogWorkspaceViewModel: ObservableObject {
    private static let contextRadius = 3
    private let diagnosticReporter: DiagnosticReporter

    @Published var sources: [LogSource] = [] {
        didSet {
            rebuildVisibleEntries()
        }
    }
    @Published var selectedSourceID: LogSource.ID? {
        didSet {
            guard oldValue != selectedSourceID else {
                return
            }

            rebuildVisibleEntries(resetSelectionIfNeeded: true)
        }
    }
    @Published var displayMode: LogDisplayMode = .source {
        didSet {
            guard oldValue != displayMode else {
                return
            }

            rebuildVisibleEntries(resetSelectionIfNeeded: true)
        }
    }
    @Published var selectedEntryID: LogEntry.ID?
    @Published var query = "" {
        didSet {
            guard oldValue != query else {
                return
            }

            rebuildVisibleEntries(resetSelectionIfNeeded: true)
        }
    }
    @Published var enabledLevels = Set(LogLevel.allCases) {
        didSet {
            guard oldValue != enabledLevels else {
                return
            }

            rebuildVisibleEntries(resetSelectionIfNeeded: true)
        }
    }
    @Published var metadataFilters = LogMetadataFilters.empty {
        didSet {
            guard oldValue != metadataFilters else {
                return
            }

            rebuildVisibleEntries(resetSelectionIfNeeded: true)
        }
    }
    @Published var pinnedToken: LogCorrelationToken? {
        didSet {
            guard oldValue != pinnedToken else {
                return
            }

            rebuildVisibleEntries(resetSelectionIfNeeded: true)
        }
    }
    @Published var tailEnabled = false {
        didSet {
            guard oldValue != tailEnabled else {
                return
            }

            tailEnabled ? startTail() : stopTail()
        }
    }
    @Published var statusMessage = "Open a log file to begin."
    @Published private(set) var visibleEntries: [LogEntry] = []

    private var tailTask: Task<Void, Never>?
    private var tailPendingText: [LogSource.ID: String] = [:]

    init(diagnosticReporter: DiagnosticReporter = DiagnosticReporter()) {
        self.diagnosticReporter = diagnosticReporter
    }

    var selectedSource: LogSource? {
        guard let selectedSourceID else {
            return sources.first
        }

        return sources.first { $0.id == selectedSourceID } ?? sources.first
    }

    var selectedEntry: LogEntry? {
        guard let selectedEntryID else {
            return visibleEntries.first
        }

        return visibleEntries.first { $0.id == selectedEntryID } ?? visibleEntries.first
    }

    var selectedEntrySource: LogSource? {
        guard let selectedEntry else {
            return nil
        }

        return source(containing: selectedEntry)
    }

    var selectedEntryContext: [LogEntry] {
        guard
            let selectedEntry,
            let source = source(containing: selectedEntry),
            let selectedIndex = source.entries.firstIndex(where: { $0.id == selectedEntry.id })
        else {
            return []
        }

        let startIndex = max(0, selectedIndex - Self.contextRadius)
        let endIndex = min(source.entries.count, selectedIndex + Self.contextRadius + 1)
        return Array(source.entries[startIndex..<endIndex])
    }

    var selectedEntryTokens: [LogCorrelationToken] {
        guard let selectedEntry else {
            return []
        }

        return LogCorrelationExtractor.tokens(from: selectedEntry)
    }

    var visibleIssueEntries: [LogEntry] {
        visibleEntries.filter(\.level.isIssueLevel)
    }

    var canNavigateIssues: Bool {
        !visibleIssueEntries.isEmpty
    }

    var canSaveWorkspace: Bool {
        sources.contains(where: \.isFileBacked)
    }

    var issueStatusLabel: String {
        let issues = visibleIssueEntries
        guard !issues.isEmpty else {
            return "No issues"
        }

        guard
            let selectedEntry,
            let issueIndex = issues.firstIndex(where: { $0.id == selectedEntry.id })
        else {
            return "\(issues.count) issues"
        }

        return "\(issueIndex + 1) / \(issues.count) issues"
    }

    var totalEntryCount: Int {
        switch displayMode {
        case .source:
            return selectedSource?.entries.count ?? 0
        case .timeline:
            return sources.reduce(0) { $0 + $1.entries.count }
        }
    }

    var showsMetadataFilters: Bool {
        metadataFilters.isActive || sources.contains { source in
            source.entries.contains(where: \.hasUnifiedMetadata)
        }
    }

    func openFiles(_ urls: [URL]) {
        for url in urls {
            openFile(url)
        }
    }

    func importRecentUnifiedLogs() {
        statusMessage = "Loading recent macOS logs..."

        Task {
            do {
                let source = try await Task.detached(priority: .userInitiated) {
                    try UnifiedLogReader.readLocal()
                }.value

                sources.append(source)
                selectedSourceID = source.id
                displayMode = .source
                rebuildVisibleEntries(resetSelectionIfNeeded: true)
                updateStatus(
                    "Loaded \(source.entries.count) recent macOS log entries.",
                    category: "unified-log"
                )
            } catch {
                updateStatus(
                    "Failed to read macOS logs: \(error.localizedDescription)",
                    severity: .error,
                    category: "unified-log"
                )
            }
        }
    }

    func openLogArchive(_ url: URL) {
        statusMessage = "Loading \(url.lastPathComponent)..."

        Task {
            do {
                let source = try await Task.detached(priority: .userInitiated) {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if didAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    return try UnifiedLogReader.readArchive(url: url)
                }.value

                sources.append(source)
                selectedSourceID = source.id
                displayMode = .source
                rebuildVisibleEntries(resetSelectionIfNeeded: true)
                updateStatus(
                    "Loaded \(source.entries.count) entries from \(source.name).",
                    category: "log-archive"
                )
            } catch {
                updateStatus(
                    "Failed to open \(url.lastPathComponent): \(error.localizedDescription)",
                    severity: .error,
                    category: "log-archive"
                )
            }
        }
    }

    func saveWorkspace(to url: URL) {
        guard canSaveWorkspace else {
            updateStatus(
                "Open file-backed log sources before saving a workspace.",
                severity: .warning,
                category: "workspace"
            )
            return
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try LogWorkspaceStore.write(workspaceSnapshot(), to: url)
            updateStatus("Saved workspace \(url.lastPathComponent).", category: "workspace")
        } catch {
            updateStatus(
                "Failed to save workspace: \(error.localizedDescription)",
                severity: .error,
                category: "workspace"
            )
        }
    }

    func openWorkspace(_ url: URL) {
        statusMessage = "Opening workspace \(url.lastPathComponent)..."

        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if didAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    let document = try LogWorkspaceStore.read(from: url)
                    return WorkspaceLoadResult(
                        document: document,
                        sources: loadWorkspaceSources(from: document.sourcePaths)
                    )
                }.value

                restoreWorkspace(result.document, sources: result.sources.loaded)
                if result.sources.loaded.isEmpty, !result.document.sourcePaths.isEmpty {
                    updateStatus(
                        "Workspace opened, but no log files could be loaded.",
                        severity: .warning,
                        category: "workspace"
                    )
                } else if result.sources.failedPaths.isEmpty {
                    updateStatus(
                        "Restored \(result.sources.loaded.count) sources from \(url.lastPathComponent).",
                        category: "workspace"
                    )
                } else {
                    updateStatus(
                        "Restored \(result.sources.loaded.count) sources; skipped \(result.sources.failedPaths.count) unavailable files.",
                        severity: .warning,
                        category: "workspace"
                    )
                }
            } catch {
                updateStatus(
                    "Failed to open workspace: \(error.localizedDescription)",
                    severity: .error,
                    category: "workspace"
                )
            }
        }
    }

    func openFile(_ url: URL) {
        guard !UnifiedLogReader.isLogArchive(url) else {
            openLogArchive(url)
            return
        }

        statusMessage = "Loading \(url.lastPathComponent)..."

        Task {
            do {
                let source = try await Task.detached(priority: .userInitiated) {
                    try LogFileLoader.load(url: url)
                }.value

                sources.append(source)
                selectedSourceID = source.id
                rebuildVisibleEntries(resetSelectionIfNeeded: true)

                let truncationNote = source.isTruncated ? " Loaded last 20 MB." : ""
                updateStatus(
                    "Loaded \(source.entries.count) lines from \(source.name).\(truncationNote)",
                    category: "file"
                )
                restartTailIfNeeded()
            } catch {
                updateStatus(
                    "Failed to open \(url.lastPathComponent): \(error.localizedDescription)",
                    severity: .error,
                    category: "file"
                )
            }
        }
    }

    func selectSource(_ source: LogSource) {
        selectedSourceID = source.id
        displayMode = .source
        restartTailIfNeeded()
    }

    func toggleLevel(_ level: LogLevel) {
        setLevel(level, enabled: !enabledLevels.contains(level))
    }

    func setLevel(_ level: LogLevel, enabled: Bool) {
        if enabled {
            enabledLevels.insert(level)
        } else {
            enabledLevels.remove(level)
        }
    }

    func selectPreviousIssue() {
        selectIssue(forward: false)
    }

    func selectNextIssue() {
        selectIssue(forward: true)
    }

    func sourceName(for entry: LogEntry) -> String {
        source(for: entry.sourceID)?.name ?? "Unknown"
    }

    func pin(_ token: LogCorrelationToken) {
        pinnedToken = token
        statusMessage = "Pinned \(token.label)."
    }

    func clearPinnedToken() {
        guard let pinnedToken else {
            return
        }

        self.pinnedToken = nil
        statusMessage = "Cleared \(pinnedToken.label)."
    }

    func clearMetadataFilters() {
        metadataFilters = .empty
        statusMessage = "Cleared metadata filters."
    }

    func makeDiagnosticReport() -> DiagnosticReport {
        diagnosticReporter.makeReport(workspace: diagnosticWorkspaceSnapshot())
    }

    func saveDiagnosticReport(to url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try diagnosticReporter.write(makeDiagnosticReport(), to: url)
            updateStatus("Saved diagnostics \(url.lastPathComponent).", category: "diagnostics")
        } catch {
            updateStatus(
                "Failed to save diagnostics: \(error.localizedDescription)",
                severity: .error,
                category: "diagnostics"
            )
        }
    }

    func workspaceSnapshot() -> LogWorkspaceDocument {
        let fileBackedSources = sources.filter(\.isFileBacked)
        let selectedFileSourcePath = selectedSource.flatMap { selectedSource in
            selectedSource.isFileBacked ? selectedSource.url.path : nil
        }

        return LogWorkspaceDocument(
            sourcePaths: fileBackedSources.map(\.url.path),
            selectedSourcePath: selectedFileSourcePath,
            displayMode: displayMode,
            query: query,
            enabledLevels: LogLevel.allCases.filter { enabledLevels.contains($0) },
            metadataFilters: metadataFilters.isActive ? metadataFilters : nil,
            pinnedToken: pinnedToken
        )
    }

    func restoreWorkspace(_ document: LogWorkspaceDocument, sources loadedSources: [LogSource]) {
        sources = loadedSources
        displayMode = document.displayMode
        query = document.query
        enabledLevels = Set(document.enabledLevels)
        metadataFilters = document.metadataFilters ?? .empty
        pinnedToken = document.pinnedToken

        if let selectedSourcePath = document.selectedSourcePath,
           let selectedSource = loadedSources.first(where: { $0.url.path == selectedSourcePath }) {
            selectedSourceID = selectedSource.id
        } else {
            selectedSourceID = loadedSources.first?.id
        }

        selectedEntryID = nil
        rebuildVisibleEntries(resetSelectionIfNeeded: true)
    }

    private func selectIssue(forward: Bool) {
        let issues = visibleIssueEntries
        guard let target = issueTarget(in: issues, forward: forward) else {
            updateStatus(
                "No visible error or fault entries.",
                severity: .warning,
                category: "navigation"
            )
            return
        }

        selectedEntryID = target.id
        statusMessage = "Selected \(target.level.label.lowercased()) at line \(target.lineNumber)."
    }

    private func issueTarget(in issues: [LogEntry], forward: Bool) -> LogEntry? {
        guard !issues.isEmpty else {
            return nil
        }

        guard let selectedEntry,
              let selectedIndex = visibleEntries.firstIndex(where: { $0.id == selectedEntry.id })
        else {
            return forward ? issues.first : issues.last
        }

        var index = forward ? selectedIndex + 1 : selectedIndex - 1
        for _ in 0..<visibleEntries.count {
            if index == visibleEntries.count {
                index = 0
            } else if index < 0 {
                index = visibleEntries.count - 1
            }

            let candidate = visibleEntries[index]
            if candidate.level.isIssueLevel {
                return candidate
            }

            index += forward ? 1 : -1
        }

        return forward ? issues.first : issues.last
    }

    private func rebuildVisibleEntries(resetSelectionIfNeeded: Bool = false) {
        guard !sources.isEmpty else {
            visibleEntries = []
            selectedEntryID = nil
            return
        }

        let baseEntries = entriesForCurrentMode()
        let filteredEntries = LogQueryFilter(query: query, enabledLevels: enabledLevels)
            .apply(to: baseEntries)
        let metadataFilteredEntries = metadataFilters.apply(to: filteredEntries)
        let pinnedEntries = applyPinnedToken(to: metadataFilteredEntries)

        visibleEntries = displayMode == .timeline
            ? sortedTimelineEntries(pinnedEntries)
            : pinnedEntries

        guard resetSelectionIfNeeded else {
            return
        }

        if let selectedEntryID,
           visibleEntries.contains(where: { $0.id == selectedEntryID }) {
            return
        }

        selectedEntryID = visibleEntries.first?.id
    }

    private func applyPinnedToken(to entries: [LogEntry]) -> [LogEntry] {
        guard let pinnedToken else {
            return entries
        }

        return entries.filter { LogCorrelationExtractor.matches($0, token: pinnedToken) }
    }

    private func entriesForCurrentMode() -> [LogEntry] {
        switch displayMode {
        case .source:
            return selectedSource?.entries ?? []
        case .timeline:
            return sources.flatMap(\.entries)
        }
    }

    private func sortedTimelineEntries(_ entries: [LogEntry]) -> [LogEntry] {
        let sourceOrder = Dictionary(uniqueKeysWithValues: sources.enumerated().map { index, source in
            (source.id, index)
        })

        return entries.sorted { lhs, rhs in
            if let lhsTimestamp = lhs.timestamp,
               let rhsTimestamp = rhs.timestamp,
               lhsTimestamp != rhsTimestamp {
                return lhsTimestamp < rhsTimestamp
            }

            if lhs.timestamp != nil, rhs.timestamp == nil {
                return true
            }

            if lhs.timestamp == nil, rhs.timestamp != nil {
                return false
            }

            let lhsSourceOrder = sourceOrder[lhs.sourceID] ?? Int.max
            let rhsSourceOrder = sourceOrder[rhs.sourceID] ?? Int.max
            if lhsSourceOrder != rhsSourceOrder {
                return lhsSourceOrder < rhsSourceOrder
            }

            return lhs.lineNumber < rhs.lineNumber
        }
    }

    private func source(containing entry: LogEntry) -> LogSource? {
        source(for: entry.sourceID)
    }

    private func source(for sourceID: LogSource.ID) -> LogSource? {
        sources.first { $0.id == sourceID }
    }

    private func startTail() {
        guard let selectedSource else {
            updateStatus(
                "Open a log file before enabling tail mode.",
                severity: .warning,
                category: "tail"
            )
            tailEnabled = false
            return
        }

        guard selectedSource.supportsTail else {
            updateStatus(
                "Tail mode only supports file-backed log sources.",
                severity: .warning,
                category: "tail"
            )
            tailEnabled = false
            return
        }

        tailTask?.cancel()
        statusMessage = "Tail mode enabled."
        tailTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.readTailOnce()

                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }
        }
    }

    private func stopTail() {
        tailTask?.cancel()
        tailTask = nil
        statusMessage = selectedSource.map { "Tail mode disabled for \($0.name)." } ?? "Tail mode disabled."
    }

    private func restartTailIfNeeded() {
        guard tailEnabled else {
            return
        }

        startTail()
    }

    private func readTailOnce() async {
        guard let source = selectedSource else {
            return
        }

        let sourceID = source.id
        let pendingText = tailPendingText[sourceID] ?? ""

        do {
            let result = try await Task.detached(priority: .utility) {
                try LogTailReader.readAppendedEntries(from: source, pendingText: pendingText)
            }.value

            applyTailResult(result, to: sourceID)
        } catch {
            updateStatus(
                "Tail read failed for \(source.name): \(error.localizedDescription)",
                severity: .error,
                category: "tail"
            )
        }
    }

    private func applyTailResult(_ result: LogTailReadResult, to sourceID: LogSource.ID) {
        guard let index = sources.firstIndex(where: { $0.id == sourceID }) else {
            return
        }

        tailPendingText[sourceID] = result.pendingText
        sources[index].fileIdentity = result.fileIdentity
        sources[index].lastReadOffset = result.nextOffset

        if result.didReset {
            sources[index].entries = result.entries
            selectedEntryID = result.entries.last?.id
            rebuildVisibleEntries()
            updateStatus(
                "Tail detected file reset and reloaded \(result.entries.count) lines.",
                severity: .warning,
                category: "tail"
            )
            return
        }

        guard !result.entries.isEmpty else {
            return
        }

        sources[index].entries.append(contentsOf: result.entries)
        selectedEntryID = result.entries.last?.id
        rebuildVisibleEntries()
        statusMessage = "Tail appended \(result.entries.count) lines to \(sources[index].name)."
    }

    private func updateStatus(
        _ message: String,
        severity: DiagnosticSeverity = .info,
        category: String
    ) {
        statusMessage = message
        diagnosticReporter.record(severity: severity, category: category, message: message)
    }

    private func diagnosticWorkspaceSnapshot() -> DiagnosticWorkspaceSnapshot {
        DiagnosticWorkspaceSnapshot(
            displayMode: displayMode,
            queryActive: !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            enabledLevels: LogLevel.allCases.filter { enabledLevels.contains($0) },
            metadataFiltersActive: metadataFilters.isActive,
            pinnedTokenLabel: pinnedToken?.label,
            selectedSourceName: selectedSource?.name,
            totalEntryCount: totalEntryCount,
            visibleEntryCount: visibleEntries.count,
            issueEntryCount: visibleIssueEntries.count,
            sources: sources.map(diagnosticSourceSnapshot)
        )
    }

    private func diagnosticSourceSnapshot(_ source: LogSource) -> DiagnosticSourceSnapshot {
        DiagnosticSourceSnapshot(
            name: source.name,
            kind: diagnosticSourceKind(source),
            entryCount: source.entries.count,
            isTruncated: source.isTruncated,
            supportsTail: source.supportsTail,
            loadedAt: source.loadedAt
        )
    }

    private func diagnosticSourceKind(_ source: LogSource) -> DiagnosticSourceKind {
        if source.url == UnifiedLogReader.sourceURL {
            return .unifiedLog
        }

        if UnifiedLogReader.isLogArchive(source.url) {
            return .logArchive
        }

        return .file
    }
}

private struct WorkspaceLoadResult: Sendable {
    let document: LogWorkspaceDocument
    let sources: WorkspaceSourceLoadResult
}

private struct WorkspaceSourceLoadResult: Sendable {
    let loaded: [LogSource]
    let failedPaths: [String]
}

private func loadWorkspaceSources(from paths: [String]) -> WorkspaceSourceLoadResult {
    var loaded: [LogSource] = []
    var failedPaths: [String] = []

    for path in paths {
        do {
            let url = URL(fileURLWithPath: path)
            if UnifiedLogReader.isLogArchive(url) {
                loaded.append(try UnifiedLogReader.readArchive(url: url))
            } else {
                loaded.append(try LogFileLoader.load(url: url))
            }
        } catch {
            failedPaths.append(path)
        }
    }

    return WorkspaceSourceLoadResult(loaded: loaded, failedPaths: failedPaths)
}
