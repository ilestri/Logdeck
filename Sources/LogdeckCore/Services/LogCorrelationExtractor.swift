import Foundation

enum LogCorrelationExtractor {
    private struct Pattern {
        let kind: LogCorrelationToken.Kind
        let keyPattern: String
    }

    private struct JSONField {
        let keyPath: String
        let value: String
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

        func append(kind: LogCorrelationToken.Kind, value: String) {
            let token = LogCorrelationToken(kind: kind, value: value)
            if seenIDs.insert(token.id).inserted {
                tokens.append(token)
            }
        }

        for pattern in patterns {
            for value in values(matching: pattern.keyPattern, in: rawText) {
                append(kind: pattern.kind, value: value)
            }
        }

        let jsonFields = jsonFields(from: rawText)
        for pattern in patterns {
            for field in jsonFields where keyPath(field.keyPath, matches: pattern.keyPattern) {
                append(kind: pattern.kind, value: field.value)
            }
        }

        return tokens
    }

    static func matches(_ entry: LogEntry, token: LogCorrelationToken) -> Bool {
        tokens(from: entry).contains(token) || containsRawValue(token.value, in: entry.rawText)
    }

    private static func values(matching keyPattern: String, in rawText: String) -> [String] {
        let pattern = #"(?i)(?:^|[^A-Za-z0-9._-])"?(?:\#(keyPattern))"?\s*[:=]\s*"?([A-Za-z0-9][A-Za-z0-9._:/-]{2,})"?"#
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

    private static func jsonFields(from rawText: String) -> [JSONField] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{",
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return []
        }

        return flattenedJSONFields(in: dictionary)
    }

    private static func flattenedJSONFields(in dictionary: [String: Any], prefix: String = "") -> [JSONField] {
        var fields: [JSONField] = []

        for (key, value) in dictionary {
            let keyPath = prefix.isEmpty ? key : "\(prefix).\(key)"

            if let string = stringValue(from: value),
               let cleaned = clean(string) {
                fields.append(JSONField(keyPath: keyPath, value: cleaned))
            } else if let nested = value as? [String: Any] {
                fields.append(contentsOf: flattenedJSONFields(in: nested, prefix: keyPath))
            }
        }

        return fields
    }

    private static func keyPath(_ keyPath: String, matches keyPattern: String) -> Bool {
        let pattern = #"(?i)^(?:\#(keyPattern))$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }

        return keyPathSuffixes(from: keyPath).contains { suffix in
            let range = NSRange(suffix.startIndex..<suffix.endIndex, in: suffix)
            return regex.firstMatch(in: suffix, range: range) != nil
        }
    }

    private static func keyPathSuffixes(from keyPath: String) -> [String] {
        let components = keyPath.split(separator: ".").map(String.init)
        guard !components.isEmpty else {
            return []
        }

        return components.indices.map { index in
            components[index...].joined(separator: ".")
        }
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

    private static func clean(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .correlationValueTrimCharacters)
        guard trimmed.range(of: #"^[A-Za-z0-9][A-Za-z0-9._:/-]{2,}$"#, options: .regularExpression) != nil else {
            return nil
        }

        return trimmed
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

private extension CharacterSet {
    static let correlationValueTrimCharacters = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: #""',;)]}"#))
}
