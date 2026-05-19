import Foundation

struct LogEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let sourceID: UUID
    let lineNumber: Int
    let timestamp: Date?
    let level: LogLevel
    let message: String
    let rawText: String
    let subsystem: String?
    let category: String?
    let process: String?
    let sender: String?

    init(
        id: UUID = UUID(),
        sourceID: UUID,
        lineNumber: Int,
        timestamp: Date?,
        level: LogLevel,
        message: String,
        rawText: String,
        subsystem: String? = nil,
        category: String? = nil,
        process: String? = nil,
        sender: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.lineNumber = lineNumber
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.rawText = rawText
        self.subsystem = subsystem
        self.category = category
        self.process = process
        self.sender = sender
    }

    var hasUnifiedMetadata: Bool {
        subsystem != nil || category != nil || process != nil || sender != nil
    }
}
