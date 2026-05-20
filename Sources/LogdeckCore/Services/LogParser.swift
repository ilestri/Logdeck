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
            rawText: rawText,
            subsystem: fields.subsystem,
            category: fields.category,
            process: fields.process,
            sender: fields.sender
        )
    }

    private static func parseJSONFields(from rawText: String) -> ParsedJSONFields {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{", let data = trimmed.data(using: .utf8) else {
            return .empty
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            return .empty
        }

        let levelValue = firstString(
            in: dictionary,
            keys: ["level", "severity", "status", "severity_text", "severityText", "levelname", "level_name", "log.level"]
        )
        .flatMap(LogLevel.init(logValue:))
        let message = firstString(in: dictionary, keys: ["message", "msg", "event", "text", "body"])
        let timestamp = firstString(in: dictionary, keys: ["timestamp", "time", "ts", "date", "@timestamp"])
            .flatMap(parseTimestamp)
        let subsystem = firstNonEmptyString(in: dictionary, keys: ["subsystem", "log.subsystem"])
        let category = firstNonEmptyString(in: dictionary, keys: ["category", "log.category"])
        let process = firstNonEmptyString(in: dictionary, keys: ["process", "process.name", "processName"])
        let sender = firstNonEmptyString(in: dictionary, keys: ["sender", "sender.name", "senderName"])

        return ParsedJSONFields(
            level: levelValue,
            message: message,
            timestamp: timestamp,
            subsystem: subsystem,
            category: category,
            process: process,
            sender: sender
        )
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

    private static func firstNonEmptyString(in dictionary: [String: Any], keys: [String]) -> String? {
        guard let value = firstString(in: dictionary, keys: keys)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty else {
            return nil
        }

        return value
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
        if let epochDate = parseEpochTimestamp(value) {
            return epochDate
        }

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

    private static func parseEpochTimestamp(_ value: String) -> Date? {
        guard let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              number.isFinite,
              abs(number) >= 100_000_000 else {
            return nil
        }

        let absoluteValue = abs(number)
        let seconds: TimeInterval
        if absoluteValue >= 1_000_000_000_000_000_000 {
            seconds = number / 1_000_000_000
        } else if absoluteValue >= 1_000_000_000_000_000 {
            seconds = number / 1_000_000
        } else if absoluteValue >= 1_000_000_000_000 {
            seconds = number / 1_000
        } else {
            seconds = number
        }

        return Date(timeIntervalSince1970: seconds)
    }
}

private struct ParsedJSONFields: Sendable {
    static let empty = ParsedJSONFields()

    let level: LogLevel?
    let message: String?
    let timestamp: Date?
    let subsystem: String?
    let category: String?
    let process: String?
    let sender: String?

    init(
        level: LogLevel? = nil,
        message: String? = nil,
        timestamp: Date? = nil,
        subsystem: String? = nil,
        category: String? = nil,
        process: String? = nil,
        sender: String? = nil
    ) {
        self.level = level
        self.message = message
        self.timestamp = timestamp
        self.subsystem = subsystem
        self.category = category
        self.process = process
        self.sender = sender
    }
}

private extension CharacterSet {
    static let logWordSeparators = CharacterSet(charactersIn: #"[](){}<>"'`,;:|=+*/\"#)
    static let logWordTrimCharacters = CharacterSet(charactersIn: #".-_"#)

    func contains(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(contains)
    }
}
