import Foundation

struct LogMetadataFilters: Codable, Equatable, Sendable {
    static let empty = LogMetadataFilters()

    var subsystem: String
    var process: String
    var category: String

    init(subsystem: String = "", process: String = "", category: String = "") {
        self.subsystem = subsystem
        self.process = process
        self.category = category
    }

    var isActive: Bool {
        !normalized(subsystem).isEmpty || !normalized(process).isEmpty || !normalized(category).isEmpty
    }

    func apply(to entries: [LogEntry]) -> [LogEntry] {
        guard isActive else {
            return entries
        }

        return entries.filter(matches)
    }

    private func matches(_ entry: LogEntry) -> Bool {
        matches(value: entry.subsystem, filter: subsystem)
            && matches(value: entry.process, filter: process)
            && matches(value: entry.category, filter: category)
    }

    private func matches(value: String?, filter: String) -> Bool {
        let trimmedFilter = normalized(filter)
        guard !trimmedFilter.isEmpty else {
            return true
        }

        guard let value else {
            return false
        }

        return normalized(value).contains(trimmedFilter)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }
}
