import Foundation

enum LogLevel: String, CaseIterable, Codable, Hashable, Sendable {
    case debug
    case info
    case warning
    case error
    case fault

    init?(logValue value: String) {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "debug", "trace", "verbose", "7", "10":
            self = .debug
        case "info", "information", "notice", "5", "6", "20":
            self = .info
        case "warning", "warn", "4", "30":
            self = .warning
        case "error", "err", "exception", "failed", "3", "40":
            self = .error
        case "fault", "fatal", "critical", "crit", "panic", "emergency", "emerg", "alert", "0", "1", "2", "50", "60":
            self = .fault
        default:
            return nil
        }
    }

    var label: String {
        switch self {
        case .debug:
            return "Debug"
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .fault:
            return "Fault"
        }
    }

    var isIssueLevel: Bool {
        switch self {
        case .error, .fault:
            return true
        case .debug, .info, .warning:
            return false
        }
    }
}
