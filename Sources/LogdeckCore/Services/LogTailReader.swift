import Foundation

struct LogTailReadResult: Sendable {
    let entries: [LogEntry]
    let nextOffset: UInt64
    let pendingText: String
    let didReset: Bool
}

enum LogTailReader {
    static func readAppendedEntries(
        from source: LogSource,
        pendingText: String = ""
    ) throws -> LogTailReadResult {
        let didAccess = source.url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                source.url.stopAccessingSecurityScopedResource()
            }
        }

        let fileSize = UInt64(try FileManager.default.fileSize(at: source.url))
        let didReset = fileSize < source.lastReadOffset
        let readOffset = didReset ? 0 : source.lastReadOffset

        guard fileSize > readOffset else {
            return LogTailReadResult(
                entries: [],
                nextOffset: fileSize,
                pendingText: pendingText,
                didReset: didReset
            )
        }

        let handle = try FileHandle(forReadingFrom: source.url)
        defer {
            try? handle.close()
        }

        try handle.seek(toOffset: readOffset)
        let data = try handle.readToEnd() ?? Data()
        let appendedText = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let combinedText = pendingText + appendedText
        let split = splitCompleteLines(from: combinedText)
        let startingLineNumber = didReset ? 1 : source.entries.count + 1
        let entries = LogParser.parse(
            text: split.completeText,
            sourceID: source.id,
            startingLineNumber: startingLineNumber
        )

        return LogTailReadResult(
            entries: entries,
            nextOffset: fileSize,
            pendingText: split.pendingText,
            didReset: didReset
        )
    }

    private static func splitCompleteLines(from text: String) -> (completeText: String, pendingText: String) {
        guard let lastNewline = text.lastIndex(where: \.isNewline) else {
            return ("", text)
        }

        let completeEnd = text.index(after: lastNewline)
        return (String(text[..<completeEnd]), String(text[completeEnd...]))
    }
}
