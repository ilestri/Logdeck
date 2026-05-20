import Foundation

struct LogFileIdentity: Hashable, Sendable {
    let systemNumber: UInt64
    let fileNumber: UInt64
}

struct LogSource: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let name: String
    let loadedAt: Date
    let isTruncated: Bool
    var fileIdentity: LogFileIdentity?
    var lastReadOffset: UInt64
    var entries: [LogEntry]

    init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        loadedAt: Date = Date(),
        isTruncated: Bool = false,
        fileIdentity: LogFileIdentity? = nil,
        lastReadOffset: UInt64 = 0,
        entries: [LogEntry]
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.loadedAt = loadedAt
        self.isTruncated = isTruncated
        self.fileIdentity = fileIdentity
        self.lastReadOffset = lastReadOffset
        self.entries = entries
    }

    var isFileBacked: Bool {
        url.isFileURL
    }

    var supportsTail: Bool {
        url.isFileURL && url.pathExtension.lowercased() != "logarchive"
    }
}
