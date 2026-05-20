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

        switch parsedQuery(from: trimmedQuery) {
        case let .regex(regex):
            return levelFiltered.filter { entry in
                let range = NSRange(entry.rawText.startIndex..<entry.rawText.endIndex, in: entry.rawText)
                return regex.firstMatch(in: entry.rawText, range: range) != nil
            }
        case .invalidRegex:
            return []
        case let .text(text):
            return levelFiltered.filter {
                $0.rawText.localizedCaseInsensitiveContains(text)
            }
        }
    }

    private func parsedQuery(from query: String) -> ParsedQuery {
        guard query.count >= 2, query.hasPrefix("/"), query.hasSuffix("/") else {
            return .text(query)
        }

        let pattern = String(query.dropFirst().dropLast())
        guard !pattern.isEmpty else {
            return .text(query)
        }

        do {
            return .regex(try NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))
        } catch {
            return .invalidRegex
        }
    }
}

private enum ParsedQuery {
    case text(String)
    case regex(NSRegularExpression)
    case invalidRegex
}
