import Foundation

enum LogLevel: String, CaseIterable, Codable, Hashable, Sendable {
    case debug
    case info
    case warning
    case error
    case fault

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
