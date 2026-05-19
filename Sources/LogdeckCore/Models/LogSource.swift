import Foundation

struct LogSource: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let name: String
    let loadedAt: Date
    let isTruncated: Bool
    var lastReadOffset: UInt64
    var entries: [LogEntry]

    init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        loadedAt: Date = Date(),
        isTruncated: Bool = false,
        lastReadOffset: UInt64 = 0,
        entries: [LogEntry]
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.loadedAt = loadedAt
        self.isTruncated = isTruncated
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
