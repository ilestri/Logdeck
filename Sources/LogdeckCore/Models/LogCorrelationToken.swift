import Foundation

struct LogCorrelationToken: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Codable, Hashable, Sendable {
        case requestID
        case traceID
        case correlationID
        case sessionID
        case transactionID

        var label: String {
            switch self {
            case .requestID:
                return "요청"
            case .traceID:
                return "추적"
            case .correlationID:
                return "상관"
            case .sessionID:
                return "세션"
            case .transactionID:
                return "트랜잭션"
            }
        }
    }

    let kind: Kind
    let value: String

    var id: String {
        "\(kind.rawValue):\(value)"
    }

    var label: String {
        "\(kind.label): \(value)"
    }
}
