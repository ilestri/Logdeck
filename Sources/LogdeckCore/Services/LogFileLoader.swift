import Foundation

enum LogFileLoader {
    static let defaultMaxBytes = 20 * 1024 * 1024

    static func load(url: URL, maxBytes: Int = defaultMaxBytes) throws -> LogSource {
        let sourceID = UUID()
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileSize = try FileManager.default.fileSize(at: url)
        let byteLimit = max(0, maxBytes)
        let readOffset = max(0, fileSize - byteLimit)
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        let startsAtLineBoundary = try startsAtLineBoundary(readOffset: readOffset, handle: handle)
        if readOffset > 0 {
            try handle.seek(toOffset: UInt64(readOffset))
        }

        let data = try handle.readToEnd() ?? Data()
        var text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)

        if !startsAtLineBoundary, let firstNewline = text.firstIndex(where: \.isNewline) {
            text.removeSubrange(...firstNewline)
        }

        return LogSource(
            id: sourceID,
            url: url,
            isTruncated: readOffset > 0,
            lastReadOffset: UInt64(fileSize),
            entries: LogParser.parse(text: text, sourceID: sourceID)
        )
    }

    private static func startsAtLineBoundary(readOffset: Int, handle: FileHandle) throws -> Bool {
        guard readOffset > 0 else {
            return true
        }

        try handle.seek(toOffset: UInt64(readOffset - 1))
        guard let previousByte = try handle.read(upToCount: 1)?.first else {
            return false
        }

        return previousByte == ASCIIByte.newline || previousByte == ASCIIByte.carriageReturn
    }
}

private enum ASCIIByte {
    static let newline: UInt8 = 10
    static let carriageReturn: UInt8 = 13
}

extension FileManager {
    func fileSize(at url: URL) throws -> Int {
        let attributes = try attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int ?? 0
    }
}
