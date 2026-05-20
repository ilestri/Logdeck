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
        let trimmed = string
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
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
}
