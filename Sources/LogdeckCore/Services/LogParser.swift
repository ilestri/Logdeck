import Foundation

enum LogParser {
    static func parse(text: String, sourceID: UUID, startingLineNumber: Int = 1) -> [LogEntry] {
        lines(in: text)
            .enumerated()
            .map { index, line in
                parseLine(String(line), lineNumber: startingLineNumber + index, sourceID: sourceID)
            }
    }

    static func parseLine(_ rawText: String, lineNumber: Int, sourceID: UUID) -> LogEntry {
        let fields = parseJSONFields(from: rawText)
        let level = fields.level ?? inferLevel(from: rawText)
        let message = fields.message ?? rawText
        let timestamp = fields.timestamp ?? parseTimestampPrefix(rawText)

        return LogEntry(
            sourceID: sourceID,
            lineNumber: lineNumber,
            timestamp: timestamp,
            level: level,
            message: message,
            rawText: rawText
        )
    }

    private static func parseJSONFields(from rawText: String) -> (level: LogLevel?, message: String?, timestamp: Date?) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{", let data = trimmed.data(using: .utf8) else {
            return (nil, nil, nil)
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            return (nil, nil, nil)
        }

        let levelValue = firstString(in: dictionary, keys: ["level", "severity", "status"])
            .flatMap(LogLevel.init)
        let message = firstString(in: dictionary, keys: ["message", "msg", "event", "text"])
        let timestamp = firstString(in: dictionary, keys: ["timestamp", "time", "ts", "date"])
            .flatMap(parseTimestamp)

        return (levelValue, message, timestamp)
    }

    private static func firstString(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String {
                return value
            }
        }

        return nil
    }

    private static func lines(in text: String) -> [Substring] {
        guard !text.isEmpty else {
            return []
        }

        var lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        if text.last?.isNewline == true {
            lines.removeLast()
        }

        return lines
    }

    private static func inferLevel(from rawText: String) -> LogLevel {
        let lowercased = rawText.lowercased()

        if lowercased.contains("fault") || lowercased.contains("fatal") || lowercased.contains("panic") {
            return .fault
        }

        if lowercased.contains("error") || lowercased.contains("exception") || lowercased.contains("failed") {
            return .error
        }

        if lowercased.contains("warn") {
            return .warning
        }

        if lowercased.contains("debug") || lowercased.contains("trace") {
            return .debug
        }

        return .info
    }

    private static func parseTimestampPrefix(_ rawText: String) -> Date? {
        let normalizedPrefix = rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "[("))
        let prefix = String(normalizedPrefix.prefix(32))
        let separators = CharacterSet(charactersIn: " ]")
        let firstToken = prefix.components(separatedBy: separators).first ?? prefix
        let dateAndTime = String(prefix.prefix(19))

        return parseTimestamp(firstToken) ?? parseTimestamp(dateAndTime)
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFraction.date(from: value) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }
}
