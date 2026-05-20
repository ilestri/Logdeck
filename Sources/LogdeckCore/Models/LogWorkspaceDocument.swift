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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        sourcePaths = try container.decode([String].self, forKey: .sourcePaths)
        selectedSourcePath = try container.decodeIfPresent(String.self, forKey: .selectedSourcePath)
        displayMode = try container.decode(LogDisplayMode.self, forKey: .displayMode)
        query = try container.decode(String.self, forKey: .query)
        enabledLevels = try container.decode([LogLevel].self, forKey: .enabledLevels)
        metadataFilters = try container.decodeIfPresent(LogMetadataFilters.self, forKey: .metadataFilters)
        pinnedToken = try container.decodeIfPresent(LogCorrelationToken.self, forKey: .pinnedToken)
    }
}
