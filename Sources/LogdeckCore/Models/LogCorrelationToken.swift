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
                return "Request"
            case .traceID:
                return "Trace"
            case .correlationID:
                return "Correlation"
            case .sessionID:
                return "Session"
            case .transactionID:
                return "Transaction"
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
