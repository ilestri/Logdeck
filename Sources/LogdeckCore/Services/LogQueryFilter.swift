import Foundation

struct LogQueryFilter {
    var query: String
    var enabledLevels: Set<LogLevel>

    func apply(to entries: [LogEntry]) -> [LogEntry] {
        let levelFiltered = entries.filter { enabledLevels.contains($0.level) }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return levelFiltered
        }

        if let regex = makeRegex(from: trimmedQuery) {
            return levelFiltered.filter { entry in
                let range = NSRange(entry.rawText.startIndex..<entry.rawText.endIndex, in: entry.rawText)
                return regex.firstMatch(in: entry.rawText, range: range) != nil
            }
        }

        return levelFiltered.filter {
            $0.rawText.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private func makeRegex(from query: String) -> NSRegularExpression? {
        guard query.count >= 2, query.hasPrefix("/"), query.hasSuffix("/") else {
            return nil
        }

        let pattern = String(query.dropFirst().dropLast())
        guard !pattern.isEmpty else {
            return nil
        }

        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}

