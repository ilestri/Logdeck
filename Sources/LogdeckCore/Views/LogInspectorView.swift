import AppKit
import SwiftUI

struct LogInspectorView: View {
    @ObservedObject var viewModel: LogWorkspaceViewModel
    @State private var hoveredContextEntryID: LogEntry.ID?
    @State private var copiedRawEntryID: LogEntry.ID?
    @State private var rawCopyFeedbackToken: UUID?

    var body: some View {
        Group {
            if let entry = viewModel.selectedEntry {
                ScrollView {
                    inspectorContent(entry)
                        .padding(16)
                }
            } else {
                ContentUnavailableView(
                    "선택된 로그가 없습니다",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("중앙 목록에서 로그 한 줄을 선택하세요.")
                )
                .padding(16)
            }
        }
    }

    private func inspectorContent(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            selectedEntryHeader(entry)

            Divider()

            metadata(entry)

            correlationTokens

            Divider()

            context(entry)

            Divider()

            rawText(entry)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func selectedEntryHeader(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("선택 로그")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(viewModel.issueStatusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                issueNavigator
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                LogLevelBadgeView(level: entry.level)

                Text("\(entry.lineNumber)번째 줄")
                    .font(.headline)
                    .monospacedDigit()

                Spacer(minLength: 8)
            }

            Text(entry.message)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                detailLine("소스", viewModel.selectedEntrySource?.name ?? "알 수 없음")

                if let timestamp = entry.timestamp {
                    detailLine("시간", fullTimestamp(timestamp))
                }
            }
            .font(.caption)
        }
    }

    private var issueNavigator: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.selectPreviousIssue()
            } label: {
                Image(systemName: "chevron.up")
                    .frame(width: 14, height: 14)
            }
            .help("이전 오류 또는 장애")
            .accessibilityLabel("이전 이슈")
            .disabled(!viewModel.canNavigateIssues)

            Button {
                viewModel.selectNextIssue()
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 14, height: 14)
            }
            .help("다음 오류 또는 장애")
            .accessibilityLabel("다음 이슈")
            .disabled(!viewModel.canNavigateIssues)
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var correlationTokens: some View {
        let tokens = viewModel.selectedEntryTokens
        if !tokens.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("고정값")

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
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("상세")

            VStack(alignment: .leading, spacing: 7) {
                detailLine("심각도", entry.level.label)
                metadataLine("프로세스", entry.process)
                metadataLine("서브시스템", entry.subsystem)
                metadataLine("카테고리", entry.category)
                metadataLine("발신자", entry.sender)
            }
            .font(.callout)
        }
    }

    @ViewBuilder
    private func metadataLine(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            detailLine(title, value)
        }
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            Text(value)
                .lineLimit(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func context(_ selectedEntry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("주변 로그")

            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(viewModel.selectedEntryContext) { entry in
                    contextRow(entry, selectedEntry: selectedEntry)
                }
            }
        }
    }

    private func contextRow(_ entry: LogEntry, selectedEntry: LogEntry) -> some View {
        let isSelected = entry.id == selectedEntry.id
        let isHovered = hoveredContextEntryID == entry.id

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(entry.lineNumber)")
                .frame(width: 42, alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            LogLevelBadgeView(level: entry.level)

            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(2)
                .textSelection(.enabled)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 5)
        .background(contextRowBackground(isSelected: isSelected, isHovered: isHovered))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedEntryID = entry.id
        }
        .onHover { isHovered in
            hoveredContextEntryID = isHovered ? entry.id : (hoveredContextEntryID == entry.id ? nil : hoveredContextEntryID)
        }
        .help("이 줄 선택")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.level.label), \(entry.lineNumber)번째 줄, \(entry.message)")
        .accessibilityHint("선택 로그로 이동합니다.")
    }

    private func contextRowBackground(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.14)
        }

        if isHovered {
            return Color.secondary.opacity(0.08)
        }

        return Color.clear
    }

    private func rawText(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("원문")

                Spacer()

                if copiedRawEntryID == entry.id {
                    Label("복사됨", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("원문 복사 완료")
                }

                Button {
                    copyRawText(entry)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("원문 복사")
                .accessibilityLabel("선택 로그 원문 복사")
            }

            ScrollView {
                Text(entry.rawText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 160, idealHeight: 220, maxHeight: 300)
        }
    }

    private func copyRawText(_ entry: LogEntry) {
        let feedbackToken = UUID()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.rawText, forType: .string)
        copiedRawEntryID = entry.id
        rawCopyFeedbackToken = feedbackToken
        viewModel.statusMessage = "\(entry.lineNumber)번째 줄 원문을 클립보드에 복사했습니다."

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if rawCopyFeedbackToken == feedbackToken {
                copiedRawEntryID = nil
                rawCopyFeedbackToken = nil
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func fullTimestamp(_ timestamp: Date) -> String {
        timestamp.formatted(
            .dateTime
                .locale(Locale(identifier: "ko_KR"))
                .year()
                .month()
                .day()
                .hour()
                .minute()
                .second()
        )
    }
}
