import SwiftUI

struct SourceSidebarView: View {
    @ObservedObject var viewModel: LogWorkspaceViewModel
    @State private var hoveredSourceID: LogSource.ID?

    var body: some View {
        List(selection: $viewModel.selectedSourceID) {
            Section("작업공간") {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.3.group")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        if viewModel.sources.isEmpty {
                            Text("소스 없음")
                        } else {
                            Text("소스 \(viewModel.sources.count)개")
                            Text("현재 \(viewModel.totalEntryCount)줄")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .accessibilityLabel(workspaceSummaryAccessibilityLabel)
            }

            if !viewModel.sources.isEmpty {
                Section("소스") {
                    ForEach(viewModel.sources) { source in
                        sourceRow(source)
                            .tag(source.id)
                            .accessibilityLabel(accessibilityLabel(for: source))
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.removeSource(source)
                                } label: {
                                    Label("소스 닫기", systemImage: "xmark.circle")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Logdeck")
    }

    private func sourceRow(_ source: LogSource) -> some View {
        let isSelected = viewModel.selectedSourceID == source.id && viewModel.displayMode == .source
        let showsRemoveButton = isSelected || hoveredSourceID == source.id

        return HStack(spacing: 8) {
            Button {
                viewModel.selectSource(source)
            } label: {
                sourceSummary(source, isSelected: isSelected)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 6)

            Button {
                viewModel.removeSource(source)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                    .frame(width: 18, height: 18)
                    .opacity(showsRemoveButton ? 1 : 0)
                    .accessibilityHidden(!showsRemoveButton)
            }
            .buttonStyle(.plain)
            .disabled(!showsRemoveButton)
            .help("\(source.name) 닫기")
            .accessibilityLabel("\(source.name) 소스 닫기")
            .accessibilityHidden(!showsRemoveButton)
        }
        .contentShape(Rectangle())
        .onHover { isHovered in
            hoveredSourceID = isHovered ? source.id : (hoveredSourceID == source.id ? nil : hoveredSourceID)
        }
    }

    private func sourceSummary(_ source: LogSource, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: sourceIcon(for: source))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(source.entries.count)줄")

                    let issueCount = viewModel.issueCount(for: source)
                    if issueCount > 0 {
                        Label("\(issueCount)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }

                    if source.isTruncated {
                        Label("잘림", systemImage: "scissors")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .imageScale(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func sourceIcon(for source: LogSource) -> String {
        if source.url.pathExtension.lowercased() == UnifiedLogReader.archiveExtension {
            return "archivebox"
        }

        return source.isFileBacked ? "doc.text" : "terminal"
    }

    private var workspaceSummaryAccessibilityLabel: String {
        if viewModel.sources.isEmpty {
            return "작업공간, 소스 없음"
        }

        return "작업공간, 소스 \(viewModel.sources.count)개, 현재 \(viewModel.totalEntryCount)줄"
    }

    private func accessibilityLabel(for source: LogSource) -> String {
        let issueCount = viewModel.issueCount(for: source)
        if issueCount > 0 {
            return "\(source.name), \(source.entries.count)줄, 이슈 \(issueCount)개"
        }

        return "\(source.name), \(source.entries.count)줄"
    }
}
