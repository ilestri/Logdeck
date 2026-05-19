import Foundation

final class DiagnosticReporter {
    private let maxEvents: Int
    private let currentDate: () -> Date
    private var events: [DiagnosticEvent] = []

    init(maxEvents: Int = 100, currentDate: @escaping () -> Date = Date.init) {
        self.maxEvents = maxEvents
        self.currentDate = currentDate
    }

    func record(severity: DiagnosticSeverity, category: String, message: String) {
        events.append(
            DiagnosticEvent(
                id: UUID(),
                date: currentDate(),
                severity: severity,
                category: category,
                message: Self.redacted(message)
            )
        )

        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    func makeReport(workspace: DiagnosticWorkspaceSnapshot) -> DiagnosticReport {
        DiagnosticReport(
            generatedAt: currentDate(),
            app: Self.appInfo(),
            system: Self.systemInfo(),
            workspace: workspace,
            recentEvents: events
        )
    }

    func write(_ report: DiagnosticReport, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try data.write(to: url, options: .atomic)
    }

    private static func appInfo(bundle: Bundle = .main) -> DiagnosticAppInfo {
        let info = bundle.infoDictionary ?? [:]
        return DiagnosticAppInfo(
            name: info["CFBundleName"] as? String ?? "Logdeck",
            version: info["CFBundleShortVersionString"] as? String ?? "0.1.0",
            build: info["CFBundleVersion"] as? String ?? "dev"
        )
    }

    private static func systemInfo(processInfo: ProcessInfo = .processInfo) -> DiagnosticSystemInfo {
        DiagnosticSystemInfo(
            operatingSystem: processInfo.operatingSystemVersionString,
            processorCount: processInfo.processorCount,
            physicalMemoryBytes: processInfo.physicalMemory
        )
    }

    private static func redacted(_ message: String) -> String {
        let homeDirectory = NSHomeDirectory()
        guard !homeDirectory.isEmpty else {
            return message
        }

        return message.replacingOccurrences(of: homeDirectory, with: "~")
    }
}
