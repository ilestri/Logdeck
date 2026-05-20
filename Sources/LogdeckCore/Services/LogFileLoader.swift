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
            fileIdentity: try FileManager.default.fileIdentity(at: url),
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

        if previousByte == ASCIIByte.newline {
            return true
        }

        if previousByte == ASCIIByte.carriageReturn {
            return try currentByte(at: readOffset, handle: handle) != ASCIIByte.newline
        }

        return false
    }

    private static func currentByte(at offset: Int, handle: FileHandle) throws -> UInt8? {
        try handle.seek(toOffset: UInt64(offset))
        return try handle.read(upToCount: 1)?.first
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

    func fileIdentity(at url: URL) throws -> LogFileIdentity? {
        let attributes = try attributesOfItem(atPath: url.path)
        guard
            let systemNumber = unsignedIntegerAttribute(.systemNumber, in: attributes),
            let fileNumber = unsignedIntegerAttribute(.systemFileNumber, in: attributes)
        else {
            return nil
        }

        return LogFileIdentity(systemNumber: systemNumber, fileNumber: fileNumber)
    }

    private func unsignedIntegerAttribute(
        _ key: FileAttributeKey,
        in attributes: [FileAttributeKey: Any]
    ) -> UInt64? {
        if let number = attributes[key] as? NSNumber {
            return number.uint64Value
        }

        if let integer = attributes[key] as? Int {
            return UInt64(integer)
        }

        return nil
    }
}
