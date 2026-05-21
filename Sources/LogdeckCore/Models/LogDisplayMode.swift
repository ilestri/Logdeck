import Foundation

enum LogDisplayMode: String, CaseIterable, Codable, Hashable, Sendable {
    case source
    case timeline

    var label: String {
        switch self {
        case .source:
            return "소스"
        case .timeline:
            return "타임라인"
        }
    }
}
