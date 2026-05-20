import Foundation

enum LogParser {
    static func parse(text: String, sourceID: UUID, startingLineNumber: Int = 1) -> [LogEntry] {
        let timestampParser = TimestampParser()
        return lines(in: text)
            .enumerated()
            .map { index, line in
                parseLine(
                    String(line),
                    lineNumber: startingLineNumber + index,
                    sourceID: sourceID,
                    timestampParser: timestampParser
                )
            }
    }

    static func parseLine(_ rawText: String, lineNumber: Int, sourceID: UUID) -> LogEntry {
        parseLine(
            rawText,
            lineNumber: lineNumber,
            sourceID: sourceID,
            timestampParser: TimestampParser()
        )
    }

    private static func parseLine(
        _ rawText: String,
        lineNumber: Int,
        sourceID: UUID,
        timestampParser: TimestampParser
    ) -> LogEntry {
        let fields = parseJSONFields(from: rawText, timestampParser: timestampParser)
        let level = fields.level ?? inferLevel(from: rawText)
        let message = fields.message ?? rawText
        let timestamp = fields.timestamp ?? parseTimestampPrefix(rawText, timestampParser: timestampParser)

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

    private static func parseJSONFields(from rawText: String, timestampParser: TimestampParser) -> ParsedJSONFields {
        guard rawText.first == "{" || rawText.first?.isWhitespace == true else {
            return .empty
        }

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

        let levelValue = firstMappedValue(
            in: dictionary,
            keys: ["level", "severity", "status", "severity_text", "severityText", "levelname", "level_name", "log.level"],
            transform: LogLevel.init(logValue:)
        )
        let message = firstNonEmptyString(in: dictionary, keys: ["message", "msg", "event", "text", "body"])
        let timestamp = firstMappedValue(
            in: dictionary,
            keys: ["timestamp", "time", "ts", "date", "@timestamp"],
            transform: timestampParser.parse
        )
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

    private static func firstMappedValue<T>(
        in dictionary: [String: Any],
        keys: [String],
        transform: (String) -> T?
    ) -> T? {
        for key in keys {
            guard let value = value(in: dictionary, forKey: key),
                  let string = stringValue(from: value),
                  let mappedValue = transform(string) else {
                continue
            }

            return mappedValue
        }

        return nil
    }

    private static func value(in dictionary: [String: Any], forKey key: String) -> Any? {
        let lookup = caseInsensitiveLookup(from: dictionary)
        let normalizedKey = key.lowercased()

        if let value = lookup[normalizedKey] {
            return value
        }

        guard normalizedKey.contains(".") else {
            return nil
        }

        var current: Any = dictionary
        for component in normalizedKey.split(separator: ".").map(String.init) {
            guard let currentDictionary = current as? [String: Any],
                  let next = caseInsensitiveLookup(from: currentDictionary)[component] else {
                return nil
            }

            current = next
        }

        return current
    }

    private static func caseInsensitiveLookup(from dictionary: [String: Any]) -> [String: Any] {
        var lookup: [String: Any] = [:]
        for (key, value) in dictionary where lookup[key.lowercased()] == nil {
            lookup[key.lowercased()] = value
        }

        return lookup
    }

    private static func firstNonEmptyString(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = value(in: dictionary, forKey: key),
                  let string = stringValue(from: value)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !string.isEmpty else {
                continue
            }

            return string
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
        if let level = rawText.utf8.withContiguousStorageIfAvailable(inferLevel) {
            return level
        }

        let bytes = Array(rawText.utf8)
        return bytes.withUnsafeBufferPointer(inferLevel)
    }

    private static func inferLevel(in bytes: UnsafeBufferPointer<UInt8>) -> LogLevel {
        var inferredLevel = LogLevel.info
        var tokenStart: Int?

        for index in bytes.indices {
            if isLogWordSeparator(bytes[index]) {
                if let start = tokenStart {
                    inferredLevel = highestPriorityLevel(
                        inferredLevel,
                        tokenLevel(in: bytes, start: start, end: index)
                    )
                    if inferredLevel == .fault {
                        return inferredLevel
                    }
                }
                tokenStart = nil
            } else if tokenStart == nil {
                tokenStart = index
            }
        }

        if let start = tokenStart {
            inferredLevel = highestPriorityLevel(
                inferredLevel,
                tokenLevel(in: bytes, start: start, end: bytes.endIndex)
            )
        }

        return inferredLevel
    }

    private static func highestPriorityLevel(_ current: LogLevel, _ candidate: LogLevel?) -> LogLevel {
        guard let candidate else {
            return current
        }

        return levelPriority(candidate) > levelPriority(current) ? candidate : current
    }

    private static func levelPriority(_ level: LogLevel) -> Int {
        switch level {
        case .info:
            return 0
        case .debug:
            return 1
        case .warning:
            return 2
        case .error:
            return 3
        case .fault:
            return 4
        }
    }

    private static func tokenLevel(
        in bytes: UnsafeBufferPointer<UInt8>,
        start originalStart: Int,
        end originalEnd: Int
    ) -> LogLevel? {
        var start = originalStart
        var end = originalEnd

        while start < end, isLogWordTrimByte(bytes[start]) {
            start += 1
        }

        while end > start, isLogWordTrimByte(bytes[end - 1]) {
            end -= 1
        }

        switch end - start {
        case 3:
            if asciiEquals(bytes, start: start, "err") {
                return .error
            }
        case 4:
            if asciiEquals(bytes, start: start, "warn") {
                return .warning
            }
            if asciiEquals(bytes, start: start, "crit") {
                return .fault
            }
        case 5:
            if asciiEquals(bytes, start: start, "error") {
                return .error
            }
            if asciiEquals(bytes, start: start, "debug") || asciiEquals(bytes, start: start, "trace") {
                return .debug
            }
            if asciiEquals(bytes, start: start, "fault") || asciiEquals(bytes, start: start, "fatal") ||
                asciiEquals(bytes, start: start, "panic") ||
                asciiEquals(bytes, start: start, "emerg") ||
                asciiEquals(bytes, start: start, "alert") {
                return .fault
            }
        case 6:
            if asciiEquals(bytes, start: start, "failed") {
                return .error
            }
        case 7:
            if asciiEquals(bytes, start: start, "warning") {
                return .warning
            }
        case 8:
            if asciiEquals(bytes, start: start, "critical") {
                return .fault
            }
        case 9:
            if asciiEquals(bytes, start: start, "exception") {
                return .error
            }
            if asciiEquals(bytes, start: start, "emergency") {
                return .fault
            }
        default:
            break
        }

        return nil
    }

    private static func asciiEquals(
        _ bytes: UnsafeBufferPointer<UInt8>,
        start: Int,
        _ lowercaseASCII: StaticString
    ) -> Bool {
        lowercaseASCII.withUTF8Buffer { expected in
            guard start + expected.count <= bytes.endIndex else {
                return false
            }

            for offset in expected.indices {
                guard asciiLowercased(bytes[start + offset]) == expected[offset] else {
                    return false
                }
            }

            return true
        }
    }

    private static func asciiLowercased(_ byte: UInt8) -> UInt8 {
        guard byte >= ASCII.upperA, byte <= ASCII.upperZ else {
            return byte
        }

        return byte + 32
    }

    private static func isLogWordSeparator(_ byte: UInt8) -> Bool {
        switch byte {
        case ASCII.tab, ASCII.newline, ASCII.verticalTab, ASCII.formFeed, ASCII.carriageReturn, ASCII.space,
             ASCII.leftBracket, ASCII.rightBracket, ASCII.leftParenthesis, ASCII.rightParenthesis,
             ASCII.leftBrace, ASCII.rightBrace, ASCII.lessThan, ASCII.greaterThan,
             ASCII.doubleQuote, ASCII.singleQuote, ASCII.backtick, ASCII.comma, ASCII.semicolon,
             ASCII.colon, ASCII.pipe, ASCII.equals, ASCII.plus, ASCII.asterisk, ASCII.slash,
             ASCII.backslash, ASCII.exclamationMark, ASCII.questionMark:
            return true
        default:
            return false
        }
    }

    private static func isLogWordTrimByte(_ byte: UInt8) -> Bool {
        byte == ASCII.period || byte == ASCII.hyphen || byte == ASCII.underscore
    }

    private static func parseTimestampPrefix(_ rawText: String, timestampParser: TimestampParser) -> Date? {
        for candidate in timestampPrefixCandidates(from: rawText) {
            if let timestamp = timestampParser.parse(candidate) {
                return timestamp
            }
        }

        return nil
    }

    private static func timestampPrefixCandidates(from rawText: String) -> [String] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let tokenSource: Substring
        var candidates: [String] = []
        if let first = trimmed.first, first == "[" || first == "(" {
            let body = trimmed.dropFirst()
            let closing: Character = first == "[" ? "]" : ")"
            if let closingIndex = body.firstIndex(of: closing) {
                let wrappedCandidate = String(body[..<closingIndex])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !wrappedCandidate.isEmpty {
                    candidates.append(wrappedCandidate)
                }

                let remainderStart = body.index(after: closingIndex)
                let remainder = String(body[remainderStart...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !remainder.isEmpty {
                    candidates.append(contentsOf: leadingTimestampCandidates(from: remainder[...]))
                }

                return uniqueCandidates(candidates)
            }

            tokenSource = body
        } else {
            tokenSource = trimmed[trimmed.startIndex...]
        }

        candidates.append(contentsOf: leadingTimestampCandidates(from: tokenSource))
        return uniqueCandidates(candidates)
    }

    private static func leadingTimestampCandidates(from tokenSource: Substring) -> [String] {
        var candidates: [String] = []

        if let whitespaceIndex = tokenSource.firstIndex(where: \.isWhitespace) {
            candidates.append(String(tokenSource[..<whitespaceIndex]))
        } else {
            candidates.append(String(tokenSource))
        }

        let dateTimeWithMilliseconds = String(tokenSource.prefix(23))
        if dateTimeWithMilliseconds.count == 23 {
            candidates.append(dateTimeWithMilliseconds)
        }

        let dateAndTime = String(tokenSource.prefix(19))
        if dateAndTime.count == 19 {
            candidates.append(dateAndTime)
        }

        return candidates
    }

    private static func uniqueCandidates(_ candidates: [String]) -> [String] {
        var seen = Set<String>()
        return candidates.filter { candidate in
            guard !candidate.isEmpty, !seen.contains(candidate) else {
                return false
            }

            seen.insert(candidate)
            return true
        }
    }

    private static func timestampCandidates(from value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let commaFraction = trimmed.replacingOccurrences(of: ",", with: ".")
        guard commaFraction != trimmed else {
            return [trimmed]
        }

        return [trimmed, commaFraction]
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

    private final class TimestampParser {
        private let isoWithFraction: ISO8601DateFormatter
        private let iso: ISO8601DateFormatter
        private let dateFormatters: [DateFormatter]
        private let timeZone: TimeZone
        private var timeZoneOffsetByDay: [Int: Int] = [:]

        init() {
            isoWithFraction = ISO8601DateFormatter()
            isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]

            timeZone = .current

            dateFormatters = Self.dateFormatStrings.map { dateFormat in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = .current
                formatter.dateFormat = dateFormat
                return formatter
            }
        }

        func parse(_ value: String) -> Date? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard mightBeTimestamp(trimmed) else {
                return nil
            }

            if let date = parseLocalTimestamp(trimmed) {
                return date
            }

            if let epochDate = LogParser.parseEpochTimestamp(trimmed) {
                return epochDate
            }

            let candidates = LogParser.timestampCandidates(from: trimmed)
            guard !candidates.isEmpty else {
                return nil
            }

            for candidate in candidates {
                if let date = parseLocalTimestamp(candidate) {
                    return date
                }
            }

            for candidate in candidates {
                if let date = isoWithFraction.date(from: candidate) {
                    return date
                }
            }

            for candidate in candidates {
                if let date = iso.date(from: candidate) {
                    return date
                }
            }

            for formatter in dateFormatters {
                for candidate in candidates {
                    if let date = formatter.date(from: candidate) {
                        return date
                    }
                }
            }

            return nil
        }

        private func parseLocalTimestamp(_ value: String) -> Date? {
            if let date = value.utf8.withContiguousStorageIfAvailable(parseLocalTimestamp) {
                return date
            }

            let bytes = Array(value.utf8)
            return bytes.withUnsafeBufferPointer(parseLocalTimestamp)
        }

        private func parseLocalTimestamp(_ bytes: UnsafeBufferPointer<UInt8>) -> Date? {
            guard bytes.count >= 19,
                  isDateSeparator(bytes[4]),
                  bytes[7] == bytes[4],
                  bytes[10] == ASCII.space,
                  bytes[13] == ASCII.colon,
                  bytes[16] == ASCII.colon,
                  let year = decimalValue(bytes, offset: 0, count: 4),
                  let month = decimalValue(bytes, offset: 5, count: 2),
                  let day = decimalValue(bytes, offset: 8, count: 2),
                  let hour = decimalValue(bytes, offset: 11, count: 2),
                  let minute = decimalValue(bytes, offset: 14, count: 2),
                  let second = decimalValue(bytes, offset: 17, count: 2)
            else {
                return nil
            }

            let nanosecond = fractionalNanosecond(bytes)
            let seconds = secondsSinceUnixEpoch(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
            let offset = timeZoneOffset(year: year, month: month, day: day)
            let interval = TimeInterval(seconds - offset) + TimeInterval(nanosecond) / 1_000_000_000
            return Date(timeIntervalSince1970: interval)
        }

        private func fractionalNanosecond(_ bytes: UnsafeBufferPointer<UInt8>) -> Int {
            guard bytes.count > 20,
                  bytes[19] == ASCII.comma || bytes[19] == ASCII.period || bytes[19] == ASCII.colon
            else {
                return 0
            }

            var value = 0
            var digits = 0
            var index = 20
            while index < bytes.count, digits < 9, let digit = decimalDigit(bytes[index]) {
                value = value * 10 + digit
                digits += 1
                index += 1
            }

            guard digits > 0 else {
                return 0
            }

            for _ in digits..<9 {
                value *= 10
            }
            return value
        }

        private func decimalValue(_ bytes: UnsafeBufferPointer<UInt8>, offset: Int, count: Int) -> Int? {
            guard offset + count <= bytes.count else {
                return nil
            }

            var value = 0
            for index in offset..<(offset + count) {
                guard let digit = decimalDigit(bytes[index]) else {
                    return nil
                }
                value = value * 10 + digit
            }
            return value
        }

        private func decimalDigit(_ byte: UInt8) -> Int? {
            guard byte >= ASCII.zero, byte <= ASCII.nine else {
                return nil
            }

            return Int(byte - ASCII.zero)
        }

        private func isDateSeparator(_ byte: UInt8) -> Bool {
            byte == ASCII.hyphen || byte == ASCII.period
        }

        private func secondsSinceUnixEpoch(
            year: Int,
            month: Int,
            day: Int,
            hour: Int,
            minute: Int,
            second: Int
        ) -> Int {
            let days = daysSinceUnixEpoch(year: year, month: month, day: day)
            return days * 86_400 + hour * 3_600 + minute * 60 + second
        }

        private func daysSinceUnixEpoch(year: Int, month: Int, day: Int) -> Int {
            var adjustedYear = year
            var adjustedMonth = month
            adjustedYear -= adjustedMonth <= 2 ? 1 : 0
            let era = (adjustedYear >= 0 ? adjustedYear : adjustedYear - 399) / 400
            let yearOfEra = adjustedYear - era * 400
            adjustedMonth += adjustedMonth > 2 ? -3 : 9
            let dayOfYear = (153 * adjustedMonth + 2) / 5 + day - 1
            let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
            return era * 146_097 + dayOfEra - 719_468
        }

        private func timeZoneOffset(year: Int, month: Int, day: Int) -> Int {
            let dayKey = year * 10_000 + month * 100 + day
            if let offset = timeZoneOffsetByDay[dayKey] {
                return offset
            }

            let noonSeconds = secondsSinceUnixEpoch(
                year: year,
                month: month,
                day: day,
                hour: 12,
                minute: 0,
                second: 0
            )
            let offset = timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: TimeInterval(noonSeconds)))
            timeZoneOffsetByDay[dayKey] = offset
            return offset
        }

        private func mightBeTimestamp(_ value: String) -> Bool {
            guard let firstByte = value.utf8.first else {
                return false
            }

            return firstByte >= ASCII.zero && firstByte <= ASCII.nine
        }

        private static let dateFormatStrings = [
            "yyyy-MM-dd HH:mm:ss,SSS",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy.MM.dd HH:mm:ss:SSS",
            "yyyy.MM.dd HH:mm:ss.SSS",
            "yyyy.MM.dd HH:mm:ss"
        ]
    }
}

private enum ASCII {
    static let tab: UInt8 = 9
    static let newline: UInt8 = 10
    static let verticalTab: UInt8 = 11
    static let formFeed: UInt8 = 12
    static let carriageReturn: UInt8 = 13
    static let space: UInt8 = 32
    static let doubleQuote: UInt8 = 34
    static let singleQuote: UInt8 = 39
    static let leftParenthesis: UInt8 = 40
    static let rightParenthesis: UInt8 = 41
    static let asterisk: UInt8 = 42
    static let plus: UInt8 = 43
    static let comma: UInt8 = 44
    static let hyphen: UInt8 = 45
    static let period: UInt8 = 46
    static let slash: UInt8 = 47
    static let colon: UInt8 = 58
    static let semicolon: UInt8 = 59
    static let lessThan: UInt8 = 60
    static let equals: UInt8 = 61
    static let greaterThan: UInt8 = 62
    static let questionMark: UInt8 = 63
    static let upperA: UInt8 = 65
    static let upperZ: UInt8 = 90
    static let leftBracket: UInt8 = 91
    static let backslash: UInt8 = 92
    static let rightBracket: UInt8 = 93
    static let underscore: UInt8 = 95
    static let backtick: UInt8 = 96
    static let leftBrace: UInt8 = 123
    static let pipe: UInt8 = 124
    static let rightBrace: UInt8 = 125
    static let zero: UInt8 = 48
    static let nine: UInt8 = 57
    static let exclamationMark: UInt8 = 33
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
