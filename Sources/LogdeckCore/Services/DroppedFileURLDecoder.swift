import Foundation

enum DroppedFileURLDecoder {
    static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return fileURL(url)
        }

        if let url = item as? NSURL {
            return fileURL(url as URL)
        }

        if let string = item as? String {
            return fileURL(from: string)
        }

        if let data = item as? Data,
           let string = String(data: data, encoding: .utf8) {
            return fileURL(from: string)
        }

        return nil
    }

    private static func fileURL(_ url: URL) -> URL? {
        url.isFileURL ? url : nil
    }

    private static func fileURL(from string: String) -> URL? {
        let trimmed = nullSeparatedSegments(in: string)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let trimmed, !trimmed.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmed), url.isFileURL {
            return url
        }

        guard trimmed.hasPrefix("/") else {
            return nil
        }

        return URL(fileURLWithPath: trimmed)
    }

    private static func nullSeparatedSegments(in string: String) -> [String] {
        string
            .split(separator: "\0", omittingEmptySubsequences: false)
            .map(String.init)
    }
}
