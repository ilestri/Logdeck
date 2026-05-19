import Foundation

enum LogDisplayMode: String, CaseIterable, Codable, Hashable, Sendable {
    case source
    case timeline

    var label: String {
        switch self {
        case .source:
            return "Source"
        case .timeline:
            return "Timeline"
        }
    }
}
