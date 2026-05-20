import Foundation

struct LogTailReadResult: Sendable {
    let entries: [LogEntry]
    let nextOffset: UInt64
    let fileIdentity: LogFileIdentity?
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
        let fileIdentity = try FileManager.default.fileIdentity(at: source.url)
        let didReset = fileSize < source.lastReadOffset || didReplaceFile(source, with: fileIdentity)
        let readOffset = didReset ? 0 : source.lastReadOffset
        let effectivePendingText = didReset ? "" : pendingText

        guard fileSize > readOffset else {
            return LogTailReadResult(
                entries: [],
                nextOffset: fileSize,
                fileIdentity: fileIdentity,
                pendingText: effectivePendingText,
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
        let combinedText = effectivePendingText + appendedText
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
            fileIdentity: fileIdentity,
            pendingText: split.pendingText,
            didReset: didReset
        )
    }

    private static func didReplaceFile(_ source: LogSource, with fileIdentity: LogFileIdentity?) -> Bool {
        guard let originalIdentity = source.fileIdentity, let fileIdentity else {
            return false
        }

        return originalIdentity != fileIdentity
    }

    private static func splitCompleteLines(from text: String) -> (completeText: String, pendingText: String) {
        let searchText = text.hasSuffix(String.carriageReturn)
            ? text.dropLast()
            : text[...]

        guard let lastNewline = searchText.lastIndex(where: \.isNewline) else {
            return ("", text)
        }

        let completeEnd = text.index(after: lastNewline)
        return (String(text[..<completeEnd]), String(text[completeEnd...]))
    }
}

private extension String {
    static let carriageReturn = "\r"
}
