import Foundation

enum LogWorkspaceStore {
    static let fileExtension = "logdeck"

    static func write(_ document: LogWorkspaceDocument, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
    }

    static func read(from url: URL) throws -> LogWorkspaceDocument {
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(LogWorkspaceDocument.self, from: data)

        guard document.version <= LogWorkspaceDocument.currentVersion else {
            throw LogWorkspaceStoreError.unsupportedVersion(document.version)
        }

        return document
    }
}

enum LogWorkspaceStoreError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            return "지원하지 않는 작업공간 버전입니다. 버전: \(version)"
        }
    }
}
