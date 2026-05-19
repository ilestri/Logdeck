import Foundation

struct UnifiedLogQuery: Equatable, Sendable {
    static let defaultRecent = UnifiedLogQuery(intervalSinceEnd: 15 * 60, limit: 2_000)
    static let defaultArchive = UnifiedLogQuery(intervalSinceEnd: nil, limit: 5_000)

    let intervalSinceEnd: TimeInterval?
    let limit: Int

    init(intervalSinceEnd: TimeInterval?, limit: Int) {
        self.intervalSinceEnd = intervalSinceEnd
        self.limit = limit
    }
}
