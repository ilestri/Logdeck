import Foundation
import OSLog

enum UnifiedLogReader {
    static let archiveExtension = "logarchive"
    static let sourceURL = URL(string: "logdeck://macos-unified-logs")!
    static let sourceName = "macOS 통합 로그"

    static func readLocal(query: UnifiedLogQuery = .defaultRecent) throws -> LogSource {
        guard query.limit > 0 else {
            return source(from: [], name: sourceName, url: sourceURL)
        }

        let store = try OSLogStore.local()
        let position = query.intervalSinceEnd.map { store.position(timeIntervalSinceEnd: -$0) }
        return try read(store: store, position: position, query: query, name: sourceName, url: sourceURL)
    }

    static func readArchive(url: URL, query: UnifiedLogQuery = .defaultArchive) throws -> LogSource {
        guard query.limit > 0 else {
            return source(from: [], name: url.lastPathComponent, url: url)
        }

        let store = try OSLogStore(url: url)
        let position = query.intervalSinceEnd.map { store.position(timeIntervalSinceEnd: -$0) }
        return try read(store: store, position: position, query: query, name: url.lastPathComponent, url: url)
    }

    static func isLogArchive(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == archiveExtension
    }

    static func source(
        from records: [UnifiedLogRecord],
        name: String = sourceName,
        url: URL = sourceURL,
        loadedAt: Date = Date()
    ) -> LogSource {
        let sourceID = UUID()
        let entries = records.enumerated().map { index, record in
            LogEntry(
                sourceID: sourceID,
                lineNumber: index + 1,
                timestamp: record.date,
                level: record.level,
                message: record.message,
                rawText: rawText(for: record),
                subsystem: record.subsystem,
                category: record.category,
                process: record.process,
                sender: record.sender
            )
        }

        return LogSource(
            id: sourceID,
            url: url,
            name: name,
            loadedAt: loadedAt,
            entries: entries
        )
    }

    private static func read(
        store: OSLogStore,
        position: OSLogPosition?,
        query: UnifiedLogQuery,
        name: String,
        url: URL
    ) throws -> LogSource {
        let entries = try store.getEntries(with: [], at: position, matching: nil)

        var records: [UnifiedLogRecord] = []
        records.reserveCapacity(min(query.limit, 512))

        for entry in entries {
            guard let logEntry = entry as? OSLogEntryLog else {
                continue
            }

            records.append(record(from: logEntry))
            if records.count >= query.limit {
                break
            }
        }

        return source(from: records, name: name, url: url)
    }

    private static func record(from entry: OSLogEntryLog) -> UnifiedLogRecord {
        UnifiedLogRecord(
            date: entry.date,
            level: level(from: entry.level),
            subsystem: entry.subsystem,
            category: entry.category,
            process: entry.process,
            sender: entry.sender,
            message: entry.composedMessage
        )
    }

    private static func level(from level: OSLogEntryLog.Level) -> LogLevel {
        switch level {
        case .debug:
            return .debug
        case .info, .notice, .undefined:
            return .info
        case .error:
            return .error
        case .fault:
            return .fault
        @unknown default:
            return .info
        }
    }

    private static func rawText(for record: UnifiedLogRecord) -> String {
        let timestamp = ISO8601DateFormatter().string(from: record.date)
        let metadata = [
            "process=\(record.process)",
            "sender=\(record.sender)",
            "subsystem=\(record.subsystem)",
            "category=\(record.category)"
        ].joined(separator: " ")

        return "\(timestamp) \(record.level.rawValue.uppercased()) \(metadata) \(record.message)"
    }
}
