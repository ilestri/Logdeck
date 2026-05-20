import Combine
import Foundation

public struct LogFileOpenRequest: Identifiable {
    public let id = UUID()
    public let urls: [URL]
}

@MainActor
public final class LogFileOpenCoordinator: ObservableObject {
    public static let shared = LogFileOpenCoordinator()

    @Published public private(set) var request: LogFileOpenRequest?

    private init() {}

    public func open(_ urls: [URL]) {
        let standardizedURLs = urls.map(\.standardizedFileURL)
        guard !standardizedURLs.isEmpty else {
            return
        }

        request = LogFileOpenRequest(urls: standardizedURLs)
    }
}
