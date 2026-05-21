import SwiftUI

struct LogTableView: View {
    @ObservedObject var viewModel: LogWorkspaceViewModel
    var openFile: () -> Void = {}
    var importMacOSLogs: () -> Void = {}
    var openArchive: () -> Void = {}
    var openWorkspace: () -> Void = {}
    var clearFilters: () -> Void = {}
    @State private var hoveredEntryID: LogEntry.ID?
    @FocusState private var isEntryListFocused: Bool

    var body: some View {
        if viewModel.sources.isEmpty {
            noLogsState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                header
                Divider()
                entriesList
            }
            .overlay {
                if viewModel.visibleEntries.isEmpty {
                    noMatchesState
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            headerCell("#", width: 44, alignment: .trailing)
            headerCell("소스", width: 130)
            headerCell("시간", width: 152)
            headerCell("심각도", width: 82)
            headerCell("메시지")
            headerCell("", width: 28)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private var entriesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.visibleEntries) { entry in
                        row(entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .focusable()
            .focused($isEntryListFocused)
            .focusEffectDisabled()
            .onAppear {
                if !viewModel.visibleEntries.isEmpty {
                    isEntryListFocused = true
                }
            }
            .onChange(of: viewModel.sources.isEmpty) { _, isEmpty in
                if !isEmpty {
                    isEntryListFocused = true
                }
            }
            .onMoveCommand { direction in
                switch direction {
                case .up:
                    viewModel.selectPreviousVisibleEntry()
                case .down:
                    viewModel.selectNextVisibleEntry()
                default:
                    break
                }
            }
            .onChange(of: viewModel.selectedEntryID) { _, selectedEntryID in
                guard let selectedEntryID else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(selectedEntryID, anchor: .center)
                }
            }
        }
    }

    private var noLogsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("열린 로그가 없습니다")
                .font(.title2.weight(.semibold))

            Text("로그 파일이나 .logarchive를 열고, 파일은 이 창에 바로 드래그할 수도 있습니다.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            emptyActionButtons
        }
        .padding(24)
    }

    private var emptyActionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                openLogButton
                openArchiveButton
                importMacOSLogsButton
                openWorkspaceButton
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    openLogButton
                    openArchiveButton
                }

                HStack(spacing: 8) {
                    importMacOSLogsButton
                    openWorkspaceButton
                }
            }
        }
        .controlSize(.large)
    }

    private var openLogButton: some View {
        Button {
            openFile()
        } label: {
            Label("로그 열기", systemImage: "folder")
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .help("로그 파일 열기")
    }

    private var openArchiveButton: some View {
        Button {
            openArchive()
        } label: {
            Label("아카이브 열기", systemImage: "archivebox")
        }
        .buttonStyle(.bordered)
        .help(".logarchive 패키지 열기")
    }

    private var importMacOSLogsButton: some View {
        Button {
            importMacOSLogs()
        } label: {
            Label("macOS 로그", systemImage: "terminal")
        }
        .buttonStyle(.bordered)
        .help("최근 macOS 통합 로그 가져오기")
    }

    private var openWorkspaceButton: some View {
        Button {
            openWorkspace()
        } label: {
            Label("작업공간 열기", systemImage: "folder.badge.gearshape")
        }
        .buttonStyle(.bordered)
        .help("저장한 Logdeck 작업공간 열기")
    }

    private var noMatchesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("조건에 맞는 로그가 없습니다")
                .font(.title2.weight(.semibold))

            if let queryWarning = viewModel.queryWarning {
                Text(queryWarning)
                    .foregroundStyle(.orange)
            } else {
                Text("검색어, 심각도, 메타데이터, 고정값 필터를 줄여보세요.")
                    .foregroundStyle(.secondary)
            }

            if viewModel.hasActiveFilters {
                Button {
                    clearFilters()
                } label: {
                    Label("필터 지우기", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
    }

    private func headerCell(
        _ title: String,
        width: CGFloat? = nil,
        alignment: Alignment = .leading
    ) -> some View {
        Text(title)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
            .padding(.horizontal, 8)
    }

    private func row(_ entry: LogEntry) -> some View {
        let isSelected = viewModel.selectedEntryID == entry.id
        let isHovered = hoveredEntryID == entry.id

        return HStack(spacing: 0) {
            Rectangle()
                .fill(rowAccent(for: entry, isSelected: isSelected))
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            Text("\(entry.lineNumber)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 41, alignment: .trailing)
                .padding(.horizontal, 8)

            Text(viewModel.sourceName(for: entry))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
                .padding(.horizontal, 8)

            timestamp(entry)
                .foregroundStyle(.secondary)
                .frame(width: 152, alignment: .leading)
                .padding(.horizontal, 8)

            LogLevelBadgeView(level: entry.level)
                .frame(width: 82, alignment: .leading)
                .padding(.horizontal, 8)

            Text(entry.message)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
                .help(entry.rawText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)

            Image(systemName: "sidebar.right")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .opacity(isSelected || isHovered ? 1 : 0)
                .frame(width: 28)
                .accessibilityHidden(true)
        }
        .frame(height: 30)
        .background(rowBackground(for: entry, isSelected: isSelected, isHovered: isHovered))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedEntryID = entry.id
            isEntryListFocused = true
        }
        .onHover { isHovered in
            hoveredEntryID = isHovered ? entry.id : (hoveredEntryID == entry.id ? nil : hoveredEntryID)
        }
        .help("상세 검사기에서 보기")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.level.label), \(entry.lineNumber)번째 줄, \(entry.message)")
        .accessibilityHint("상세 검사기에서 이 로그를 봅니다.")
    }

    @ViewBuilder
    private func timestamp(_ entry: LogEntry) -> some View {
        if let timestamp = entry.timestamp {
            Text(timestamp.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day().hour().minute().second()))
                .monospacedDigit()
        } else {
            Text("-")
                .foregroundStyle(.tertiary)
        }
    }

    private func rowBackground(for entry: LogEntry, isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.20)
        }

        if entry.level.isIssueLevel {
            return rowTint(for: entry.level).opacity(isHovered ? 0.10 : 0.055)
        }

        if isHovered {
            return Color.secondary.opacity(0.07)
        }

        return Color.clear
    }

    private func rowAccent(for entry: LogEntry, isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor
        }

        return entry.level.isIssueLevel ? rowTint(for: entry.level) : Color.clear
    }

    private func rowTint(for level: LogLevel) -> Color {
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
