import SwiftUI

struct LogTableView: View {
    @ObservedObject var viewModel: LogWorkspaceViewModel

    var body: some View {
        Table(viewModel.visibleEntries, selection: $viewModel.selectedEntryID) {
            TableColumn("#") { entry in
                Text("\(entry.lineNumber)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 54, ideal: 64, max: 80)

            TableColumn("Source") { entry in
                Text(viewModel.sourceName(for: entry))
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 160, max: 220)

            TableColumn("Time") { entry in
                if let timestamp = entry.timestamp {
                    Text(timestamp, format: .dateTime.month().day().hour().minute().second())
                        .monospacedDigit()
                } else {
                    Text("-")
                        .foregroundStyle(.tertiary)
                }
            }
            .width(min: 120, ideal: 150, max: 180)

            TableColumn("Level") { entry in
                Text(entry.level.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(levelTint(entry.level))
            }
            .width(min: 78, ideal: 86, max: 100)

            TableColumn("Message") { entry in
                Text(entry.message)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
            }
        }
        .overlay {
            if viewModel.sources.isEmpty {
                ContentUnavailableView(
                    "No Logs Open",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Open or drop a log file or workspace.")
                )
            } else if viewModel.visibleEntries.isEmpty {
                ContentUnavailableView.search
            }
        }
    }

    private func levelTint(_ level: LogLevel) -> Color {
        switch level {
        case .debug:
            return .secondary
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .fault:
            return .purple
        }
    }
}
