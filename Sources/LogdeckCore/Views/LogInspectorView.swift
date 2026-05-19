import SwiftUI

struct LogInspectorView: View {
    @ObservedObject var viewModel: LogWorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let entry = viewModel.selectedEntry {
                issueNavigator

                metadata(entry)

                correlationTokens

                Divider()

                context(entry)

                Divider()

                Text("Raw")
                    .font(.headline)

                ScrollView {
                    Text(entry.rawText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Select a log line.")
                )
            }

            Spacer()
        }
        .padding(16)
    }

    private var issueNavigator: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.selectPreviousIssue()
            } label: {
                Label("Previous Issue", systemImage: "chevron.up")
            }
            .labelStyle(.iconOnly)
            .help("Previous visible error or fault")
            .disabled(!viewModel.canNavigateIssues)

            Button {
                viewModel.selectNextIssue()
            } label: {
                Label("Next Issue", systemImage: "chevron.down")
            }
            .labelStyle(.iconOnly)
            .help("Next visible error or fault")
            .disabled(!viewModel.canNavigateIssues)

            Text(viewModel.issueStatusLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    @ViewBuilder
    private var correlationTokens: some View {
        let tokens = viewModel.selectedEntryTokens
        if !tokens.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pins")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tokens) { token in
                            Button {
                                viewModel.pin(token)
                            } label: {
                                Label(token.label, systemImage: viewModel.pinnedToken == token ? "pin.fill" : "pin")
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private func metadata(_ entry: LogEntry) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                Text("Source")
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedEntrySource?.name ?? "Unknown")
                    .lineLimit(1)
            }

            GridRow {
                Text("Line")
                    .foregroundStyle(.secondary)
                Text("\(entry.lineNumber)")
                    .monospacedDigit()
            }

            GridRow {
                Text("Level")
                    .foregroundStyle(.secondary)
                Text(entry.level.label)
            }

            GridRow {
                Text("Time")
                    .foregroundStyle(.secondary)
                if let timestamp = entry.timestamp {
                    Text(timestamp, format: .dateTime.year().month().day().hour().minute().second())
                        .monospacedDigit()
                } else {
                    Text("-")
                        .foregroundStyle(.tertiary)
                }
            }

            metadataRow("Process", entry.process)
            metadataRow("Subsystem", entry.subsystem)
            metadataRow("Category", entry.category)
            metadataRow("Sender", entry.sender)
        }
        .font(.callout)
    }

    @ViewBuilder
    private func metadataRow(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            GridRow {
                Text(title)
                    .foregroundStyle(.secondary)
                Text(value)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
        }
    }

    private func context(_ selectedEntry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Context")
                .font(.headline)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.selectedEntryContext) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(entry.lineNumber)")
                                .frame(width: 42, alignment: .trailing)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)

                            Text(entry.rawText)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(3)
                                .textSelection(.enabled)
                                .foregroundStyle(entry.id == selectedEntry.id ? .primary : .secondary)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                        .background(entry.id == selectedEntry.id ? Color.accentColor.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 120, idealHeight: 170, maxHeight: 220)
        }
    }
}
