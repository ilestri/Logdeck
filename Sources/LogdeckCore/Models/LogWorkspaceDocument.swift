import Foundation

struct LogWorkspaceDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    var sourcePaths: [String]
    var selectedSourcePath: String?
    var displayMode: LogDisplayMode
    var query: String
    var enabledLevels: [LogLevel]
    var metadataFilters: LogMetadataFilters?
    var pinnedToken: LogCorrelationToken?

    init(
        version: Int = Self.currentVersion,
        sourcePaths: [String],
        selectedSourcePath: String?,
        displayMode: LogDisplayMode,
        query: String,
        enabledLevels: [LogLevel],
        metadataFilters: LogMetadataFilters? = nil,
        pinnedToken: LogCorrelationToken?
    ) {
        self.version = version
        self.sourcePaths = sourcePaths
        self.selectedSourcePath = selectedSourcePath
        self.displayMode = displayMode
        self.query = query
        self.enabledLevels = enabledLevels
        self.metadataFilters = metadataFilters
        self.pinnedToken = pinnedToken
    }
}
