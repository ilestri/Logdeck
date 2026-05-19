import Foundation

struct DiagnosticReport: Codable, Equatable, Sendable {
    let generatedAt: Date
    let app: DiagnosticAppInfo
    let system: DiagnosticSystemInfo
    let workspace: DiagnosticWorkspaceSnapshot
    let recentEvents: [DiagnosticEvent]
}

struct DiagnosticAppInfo: Codable, Equatable, Sendable {
    let name: String
    let version: String
    let build: String
}

struct DiagnosticSystemInfo: Codable, Equatable, Sendable {
    let operatingSystem: String
    let processorCount: Int
    let physicalMemoryBytes: UInt64
}

struct DiagnosticWorkspaceSnapshot: Codable, Equatable, Sendable {
    let displayMode: LogDisplayMode
    let queryActive: Bool
    let enabledLevels: [LogLevel]
    let metadataFiltersActive: Bool
    let pinnedTokenLabel: String?
    let selectedSourceName: String?
    let totalEntryCount: Int
    let visibleEntryCount: Int
    let issueEntryCount: Int
    let sources: [DiagnosticSourceSnapshot]
}

struct DiagnosticSourceSnapshot: Codable, Equatable, Sendable {
    let name: String
    let kind: DiagnosticSourceKind
    let entryCount: Int
    let isTruncated: Bool
    let supportsTail: Bool
    let loadedAt: Date
}

enum DiagnosticSourceKind: String, Codable, Equatable, Sendable {
    case file
    case unifiedLog
    case logArchive
}

struct DiagnosticEvent: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let severity: DiagnosticSeverity
    let category: String
    let message: String
}

enum DiagnosticSeverity: String, Codable, Equatable, Sendable {
    case info
    case warning
    case error
}
