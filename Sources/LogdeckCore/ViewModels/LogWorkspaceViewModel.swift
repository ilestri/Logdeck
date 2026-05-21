import Combine
import Foundation

@MainActor
final class LogWorkspaceViewModel: ObservableObject {
    private static let contextRadius = 3
    private static let allLevels = Set(LogLevel.allCases)
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
    @Published var statusMessage = "로그 파일을 열어 시작하세요."
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
            return "이슈 없음"
        }

        guard
            let selectedEntry,
            let issueIndex = issues.firstIndex(where: { $0.id == selectedEntry.id })
        else {
            return "\(issues.count)개 이슈"
        }

        return "이슈 \(issueIndex + 1) / \(issues.count)"
    }

    var totalEntryCount: Int {
        switch displayMode {
        case .source:
            return selectedSource?.entries.count ?? 0
        case .timeline:
            return sources.reduce(0) { $0 + $1.entries.count }
        }
    }

    var issueCount: Int {
        visibleIssueEntries.count
    }

    var queryWarning: String? {
        LogQueryFilter.validationMessage(for: query)
    }

    var hasActiveFilters: Bool {
        isQueryActive
            || enabledLevels != Self.allLevels
            || metadataFilters.isActive
            || pinnedToken != nil
    }

    var filterSummary: String {
        guard hasActiveFilters else {
            return "전체 \(totalEntryCount)줄"
        }

        return "\(visibleEntries.count) / \(totalEntryCount)줄 표시 중"
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
        statusMessage = "최근 macOS 로그를 불러오는 중..."

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
                    "최근 macOS 로그 \(source.entries.count)개를 불러왔습니다.",
                    category: "unified-log"
                )
            } catch {
                updateStatus(
                    "macOS 로그를 읽지 못했습니다: \(error.localizedDescription)",
                    severity: .error,
                    category: "unified-log"
                )
            }
        }
    }

    func openLogArchive(_ url: URL) {
        statusMessage = "\(url.lastPathComponent)을(를) 불러오는 중..."

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
                    "\(source.name)에서 \(source.entries.count)개 항목을 불러왔습니다.",
                    category: "log-archive"
                )
            } catch {
                updateStatus(
                    "\(url.lastPathComponent)을(를) 열지 못했습니다: \(error.localizedDescription)",
                    severity: .error,
                    category: "log-archive"
                )
            }
        }
    }

    func saveWorkspace(to url: URL) {
        guard canSaveWorkspace else {
            updateStatus(
                "작업공간을 저장하려면 파일 기반 로그 소스를 먼저 열어야 합니다.",
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
            updateStatus("작업공간 \(url.lastPathComponent)을(를) 저장했습니다.", category: "workspace")
        } catch {
            updateStatus(
                "작업공간을 저장하지 못했습니다: \(error.localizedDescription)",
                severity: .error,
                category: "workspace"
            )
        }
    }

    func openWorkspace(_ url: URL) {
        statusMessage = "작업공간 \(url.lastPathComponent)을(를) 여는 중..."

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
                        "작업공간은 열렸지만 불러올 수 있는 로그 파일이 없습니다.",
                        severity: .warning,
                        category: "workspace"
                    )
                } else if result.sources.failedPaths.isEmpty {
                    updateStatus(
                        "\(url.lastPathComponent)에서 소스 \(result.sources.loaded.count)개를 복원했습니다.",
                        category: "workspace"
                    )
                } else {
                    updateStatus(
                        "소스 \(result.sources.loaded.count)개를 복원했고, 사용할 수 없는 파일 \(result.sources.failedPaths.count)개는 건너뛰었습니다.",
                        severity: .warning,
                        category: "workspace"
                    )
                }
            } catch {
                updateStatus(
                    "작업공간을 열지 못했습니다: \(error.localizedDescription)",
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

        statusMessage = "\(url.lastPathComponent)을(를) 불러오는 중..."

        Task {
            do {
                let source = try await Task.detached(priority: .userInitiated) {
                    try LogFileLoader.load(url: url)
                }.value

                sources.append(source)
                selectedSourceID = source.id
                rebuildVisibleEntries(resetSelectionIfNeeded: true)

                let truncationNote = source.isTruncated ? " 마지막 20MB만 불러왔습니다." : ""
                updateStatus(
                    "\(source.name)에서 \(source.entries.count)줄을 불러왔습니다.\(truncationNote)",
                    category: "file"
                )
                restartTailIfNeeded()
            } catch {
                updateStatus(
                    "\(url.lastPathComponent)을(를) 열지 못했습니다: \(error.localizedDescription)",
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

    func removeSource(_ source: LogSource) {
        guard let removedIndex = sources.firstIndex(where: { $0.id == source.id }) else {
            return
        }

        let removedSource = sources[removedIndex]
        let removedWasSelected = selectedSource?.id == removedSource.id
        let remainingSources = sources.filter { $0.id != removedSource.id }
        let nextSelectedSourceID = nextSourceIDAfterRemoval(
            removedIndex: removedIndex,
            removedWasSelected: removedWasSelected,
            remainingSources: remainingSources
        )

        if removedWasSelected, tailEnabled {
            tailEnabled = false
        }

        tailPendingText[removedSource.id] = nil
        sources = remainingSources
        selectedSourceID = nextSelectedSourceID
        rebuildVisibleEntries(resetSelectionIfNeeded: true)
        updateStatus("\(removedSource.name)을(를) 소스에서 닫았습니다.", category: "source")
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

    func showAllLevels() {
        enabledLevels = Self.allLevels
        statusMessage = "모든 심각도를 표시합니다."
    }

    func showIssueLevelsOnly() {
        enabledLevels = [.error, .fault]
        statusMessage = "오류와 장애만 표시합니다."
    }

    func selectPreviousIssue() {
        selectIssue(forward: false)
    }

    func selectNextIssue() {
        selectIssue(forward: true)
    }

    func selectPreviousVisibleEntry() {
        selectVisibleEntry(forward: false)
    }

    func selectNextVisibleEntry() {
        selectVisibleEntry(forward: true)
    }

    func sourceName(for entry: LogEntry) -> String {
        source(for: entry.sourceID)?.name ?? "알 수 없음"
    }

    func pin(_ token: LogCorrelationToken) {
        pinnedToken = token
        statusMessage = "\(token.label)을(를) 고정했습니다."
    }

    func clearPinnedToken() {
        guard let pinnedToken else {
            return
        }

        self.pinnedToken = nil
        statusMessage = "\(pinnedToken.label) 고정을 해제했습니다."
    }

    func clearMetadataFilters() {
        metadataFilters = .empty
        statusMessage = "메타데이터 필터를 지웠습니다."
    }

    func clearAllFilters() {
        query = ""
        enabledLevels = Self.allLevels
        metadataFilters = .empty
        pinnedToken = nil
        statusMessage = "모든 필터를 지웠습니다."
    }

    func levelCountsForCurrentMode() -> [LogLevel: Int] {
        entriesForCurrentMode().reduce(into: [:]) { counts, entry in
            counts[entry.level, default: 0] += 1
        }
    }

    func issueCount(for source: LogSource) -> Int {
        source.entries.filter(\.level.isIssueLevel).count
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
            updateStatus("진단 파일 \(url.lastPathComponent)을(를) 저장했습니다.", category: "diagnostics")
        } catch {
            updateStatus(
                "진단 파일을 저장하지 못했습니다: \(error.localizedDescription)",
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
                "현재 보이는 오류 또는 장애 항목이 없습니다.",
                severity: .warning,
                category: "navigation"
            )
            return
        }

        selectedEntryID = target.id
        statusMessage = "\(target.lineNumber)번째 줄의 \(target.level.label) 항목을 선택했습니다."
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

    private func selectVisibleEntry(forward: Bool) {
        guard !visibleEntries.isEmpty else {
            return
        }

        guard let selectedEntry,
              let selectedIndex = visibleEntries.firstIndex(where: { $0.id == selectedEntry.id })
        else {
            selectedEntryID = forward ? visibleEntries.first?.id : visibleEntries.last?.id
            return
        }

        let nextIndex: Int
        if forward {
            nextIndex = selectedIndex == visibleEntries.count - 1 ? 0 : selectedIndex + 1
        } else {
            nextIndex = selectedIndex == 0 ? visibleEntries.count - 1 : selectedIndex - 1
        }

        selectedEntryID = visibleEntries[nextIndex].id
    }

    private func nextSourceIDAfterRemoval(
        removedIndex: Int,
        removedWasSelected: Bool,
        remainingSources: [LogSource]
    ) -> LogSource.ID? {
        guard !remainingSources.isEmpty else {
            return nil
        }

        if !removedWasSelected,
           let selectedSourceID,
           remainingSources.contains(where: { $0.id == selectedSourceID }) {
            return selectedSourceID
        }

        if removedIndex < remainingSources.count {
            return remainingSources[removedIndex].id
        }

        return remainingSources.last?.id
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

        let nextSelectionID = visibleEntries.first?.id
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            if let selectedEntryID,
               self.visibleEntries.contains(where: { $0.id == selectedEntryID }) {
                return
            }

            guard nextSelectionID == nil || self.visibleEntries.contains(where: { $0.id == nextSelectionID }) else {
                return
            }

            self.selectedEntryID = nextSelectionID
        }
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

    private var isQueryActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func startTail() {
        guard let selectedSource else {
            updateStatus(
                "실시간 추적을 켜려면 로그 파일을 먼저 열어야 합니다.",
                severity: .warning,
                category: "tail"
            )
            tailEnabled = false
            return
        }

        guard selectedSource.supportsTail else {
            updateStatus(
                "실시간 추적은 파일 기반 로그 소스에서만 사용할 수 있습니다.",
                severity: .warning,
                category: "tail"
            )
            tailEnabled = false
            return
        }

        tailTask?.cancel()
        statusMessage = "실시간 추적을 켰습니다."
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
        statusMessage = selectedSource.map { "\($0.name)의 실시간 추적을 껐습니다." } ?? "실시간 추적을 껐습니다."
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
                "\(source.name)의 추가 로그를 읽지 못했습니다: \(error.localizedDescription)",
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
                "파일이 다시 생성되어 \(result.entries.count)줄을 다시 불러왔습니다.",
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
        statusMessage = "\(sources[index].name)에 새 로그 \(result.entries.count)줄을 추가했습니다."
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
