import Foundation

struct UnifiedLogRecord: Equatable, Sendable {
    let date: Date
    let level: LogLevel
    let subsystem: String
    let category: String
    let process: String
    let sender: String
    let message: String
}
