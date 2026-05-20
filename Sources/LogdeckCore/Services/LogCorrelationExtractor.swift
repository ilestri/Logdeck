import Foundation

enum LogCorrelationExtractor {
    private struct Pattern {
        let kind: LogCorrelationToken.Kind
        let keyPattern: String
    }

    private static let patterns: [Pattern] = [
        Pattern(kind: .requestID, keyPattern: #"request[._-]?id|req[._-]?id|x-request-id"#),
        Pattern(kind: .traceID, keyPattern: #"trace[._-]?id|traceid|span[._-]?id"#),
        Pattern(kind: .correlationID, keyPattern: #"correlation[._-]?id|corr[._-]?id"#),
        Pattern(kind: .sessionID, keyPattern: #"session[._-]?id|sid"#),
        Pattern(kind: .transactionID, keyPattern: #"transaction[._-]?id|tx[._-]?id|txn[._-]?id"#)
    ]

    static func tokens(from entry: LogEntry) -> [LogCorrelationToken] {
        tokens(from: entry.rawText)
    }

    static func tokens(from rawText: String) -> [LogCorrelationToken] {
        var tokens: [LogCorrelationToken] = []
        var seenIDs = Set<String>()

        for pattern in patterns {
            for value in values(matching: pattern.keyPattern, in: rawText) {
                let token = LogCorrelationToken(kind: pattern.kind, value: value)
                if seenIDs.insert(token.id).inserted {
                    tokens.append(token)
                }
            }
        }

        return tokens
    }

    static func matches(_ entry: LogEntry, token: LogCorrelationToken) -> Bool {
        tokens(from: entry).contains(token) || containsRawValue(token.value, in: entry.rawText)
    }

    private static func values(matching keyPattern: String, in rawText: String) -> [String] {
        let pattern = #"(?i)"?(?:\#(keyPattern))"?\s*[:=]\s*"?([A-Za-z0-9][A-Za-z0-9._:/-]{2,})"?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(rawText.startIndex..<rawText.endIndex, in: rawText)
        return regex.matches(in: rawText, range: range).compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: rawText) else {
                return nil
            }

            return clean(String(rawText[valueRange]))
        }
    }

    private static func clean(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: #""',;)]}"#))
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func containsRawValue(_ value: String, in rawText: String) -> Bool {
        let escapedValue = NSRegularExpression.escapedPattern(for: value)
        let pattern = #"(?i)(^|[^A-Za-z0-9._:/-])\#(escapedValue)(?=$|[^A-Za-z0-9._:/-])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }

        let range = NSRange(rawText.startIndex..<rawText.endIndex, in: rawText)
        return regex.firstMatch(in: rawText, range: range) != nil
    }
}
