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

        let levelValue = firstString(
            in: dictionary,
            keys: ["level", "severity", "status", "severity_text", "severityText", "levelname", "level_name", "log.level"]
        )
        .flatMap(LogLevel.init(logValue:))
        let message = firstString(in: dictionary, keys: ["message", "msg", "event", "text", "body"])
        let timestamp = firstString(in: dictionary, keys: ["timestamp", "time", "ts", "date", "@timestamp"])
            .flatMap(parseTimestamp)

        return (levelValue, message, timestamp)
    }

    private static func firstString(in dictionary: [String: Any], keys: [String]) -> String? {
        var lowercaseDictionary: [String: Any] = [:]
        for (key, value) in dictionary where lowercaseDictionary[key.lowercased()] == nil {
            lowercaseDictionary[key.lowercased()] = value
        }

        for key in keys {
            if let value = lowercaseDictionary[key.lowercased()],
               let string = stringValue(from: value) {
                return string
            }
        }

        return nil
    }

    private static func stringValue(from value: Any) -> String? {
        if let string = value as? String {
            return string
        }

        if let number = value as? NSNumber {
            return number.stringValue
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
        let words = logWords(in: lowercased)

        if words.contains("fault") || words.contains("fatal") || words.contains("panic") ||
            words.contains("critical") || words.contains("crit") ||
            words.contains("emergency") || words.contains("emerg") || words.contains("alert") {
            return .fault
        }

        if words.contains("error") || words.contains("err") || words.contains("exception") || words.contains("failed") {
            return .error
        }

        if words.contains("warning") || words.contains("warn") {
            return .warning
        }

        if words.contains("debug") || words.contains("trace") {
            return .debug
        }

        return .info
    }

    private static func logWords(in rawText: String) -> Set<String> {
        Set(
            rawText
                .split { character in
                    character.isWhitespace || CharacterSet.logWordSeparators.contains(character)
                }
                .compactMap { word in
                    let trimmed = String(word).trimmingCharacters(in: .logWordTrimCharacters)
                    return trimmed.isEmpty ? nil : trimmed
                }
        )
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

private extension CharacterSet {
    static let logWordSeparators = CharacterSet(charactersIn: #"[](){}<>"'`,;:|=+*/\"#)
    static let logWordTrimCharacters = CharacterSet(charactersIn: #".-_"#)

    func contains(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(contains)
    }
}
