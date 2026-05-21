import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct ContentView: View {
    @StateObject private var viewModel = LogWorkspaceViewModel()
    @State private var isImporterPresented = false
    @State private var isDropTargeted = false
    @State private var isInspectorPresented = true
    @State private var isMetadataFilterBarPresented = false
    @State private var didOpenInitialFileURLs = false
    @ObservedObject private var fileOpenCoordinator: LogFileOpenCoordinator
    private let initialFileURLs: [URL]

    @MainActor public init(initialFileURLs: [URL] = []) {
        self.initialFileURLs = initialFileURLs
        self.fileOpenCoordinator = LogFileOpenCoordinator.shared
    }

    @MainActor public init(initialFileURLs: [URL], fileOpenCoordinator: LogFileOpenCoordinator) {
        self.initialFileURLs = initialFileURLs
        self.fileOpenCoordinator = fileOpenCoordinator
    }

    public var body: some View {
        NavigationSplitView {
            SourceSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            VStack(spacing: 0) {
                toolbar
                Divider()
                if viewModel.hasActiveFilters {
                    filterStatusBar
                    Divider()
                }
                if shouldShowMetadataFilterBar {
                    metadataFilterBar
                    Divider()
                }
                LogTableView(
                    viewModel: viewModel,
                    openFile: {
                        isImporterPresented = true
                    },
                    importMacOSLogs: {
                        viewModel.importRecentUnifiedLogs()
                    },
                    openArchive: {
                        openLogArchivePanel()
                    },
                    openWorkspace: {
                        openWorkspacePanel()
                    },
                    clearFilters: {
                        viewModel.clearAllFilters()
                    }
                )
                Divider()
                statusBar
            }
        }
        .inspector(isPresented: inspectorPresentation) {
            LogInspectorView(viewModel: viewModel)
                .inspectorColumnWidth(min: 320, ideal: 360, max: 520)
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: supportedLogTypes,
            allowsMultipleSelection: true
        ) { result in
            if case let .success(urls) = result {
                viewModel.openFiles(urls)
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            importDroppedFiles(providers)
        }
        .onOpenURL { url in
            viewModel.openFiles([url.standardizedFileURL])
        }
        .onReceive(fileOpenCoordinator.$request.compactMap { $0 }) { request in
            viewModel.openFiles(request.urls)
        }
        .onAppear {
            openInitialFileURLsIfNeeded()
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .frame(minWidth: 1120, minHeight: 660)
    }

    private func openInitialFileURLsIfNeeded() {
        guard !didOpenInitialFileURLs, !initialFileURLs.isEmpty else {
            return
        }

        didOpenInitialFileURLs = true
        viewModel.openFiles(initialFileURLs)
    }

    private var canShowInspector: Bool {
        viewModel.selectedEntry != nil
    }

    private var isInspectorVisible: Bool {
        isInspectorPresented && canShowInspector
    }

    private var inspectorPresentation: Binding<Bool> {
        Binding {
            isInspectorVisible
        } set: { isPresented in
            isInspectorPresented = isPresented
        }
    }

    private var toolbar: some View {
        VStack(spacing: 6) {
            if viewModel.sources.isEmpty {
                emptyWorkspaceToolbar
            } else {
                HStack(spacing: 10) {
                    importActions

                    Divider()
                        .frame(height: 24)

                    searchControls

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    levelFilterStrip

                    Spacer(minLength: 8)

                    if viewModel.issueCount > 0 {
                        issueJumpButton
                    }
                }
                .font(.caption)

                HStack(spacing: 10) {
                    viewControls

                    Spacer(minLength: 8)

                    Text(viewModel.filterSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 240, alignment: .trailing)

                    Divider()
                        .frame(height: 20)

                    workspaceActions

                    inspectorToggle
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private var emptyWorkspaceToolbar: some View {
        HStack(spacing: 10) {
            importActions

            Text("로그를 열면 검색, 심각도 필터, 보기 전환이 활성화됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)
        }
        .frame(height: 28)
    }

    private var workspaceActions: some View {
        Menu {
            Button {
                openWorkspacePanel()
            } label: {
                Label("작업공간 열기", systemImage: "folder.badge.gearshape")
            }

            Button {
                saveWorkspacePanel()
            } label: {
                Label("작업공간 저장", systemImage: "square.and.arrow.down")
            }
            .disabled(!viewModel.canSaveWorkspace)

            Button {
                saveDiagnosticsPanel()
            } label: {
                Label("진단 저장", systemImage: "waveform.path.ecg.rectangle")
            }
        } label: {
            Label("작업공간", systemImage: "rectangle.3.group")
        }
        .frame(width: 132, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var inspectorToggle: some View {
        Button {
            isInspectorPresented.toggle()
        } label: {
            Image(systemName: "sidebar.right")
                .foregroundStyle(isInspectorVisible ? Color.accentColor : Color.secondary)
                .frame(width: 18, height: 16)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .frame(width: 34)
        .disabled(!canShowInspector)
        .help(inspectorToggleHelp)
        .accessibilityLabel("상세 패널")
        .accessibilityValue(inspectorToggleAccessibilityValue)
    }

    private var inspectorToggleHelp: String {
        if !canShowInspector {
            return "로그를 선택하면 상세 패널을 볼 수 있습니다."
        }

        return isInspectorVisible ? "상세 패널 숨기기" : "상세 패널 보이기"
    }

    private var inspectorToggleAccessibilityValue: String {
        if !canShowInspector {
            return "선택된 로그 없음"
        }

        return isInspectorVisible ? "표시 중" : "숨김"
    }

    private var importActions: some View {
        Menu {
            Button {
                isImporterPresented = true
            } label: {
                Label("로그 파일 열기", systemImage: "folder")
            }
            .keyboardShortcut("o")

            Button {
                viewModel.importRecentUnifiedLogs()
            } label: {
                Label("macOS 로그", systemImage: "terminal")
            }
            .help("최근 macOS 통합 로그 가져오기")

            Button {
                openLogArchivePanel()
            } label: {
                Label("아카이브", systemImage: "archivebox")
            }
            .help(".logarchive 패키지 열기")

            Divider()

            Button {
                openWorkspacePanel()
            } label: {
                Label("작업공간 열기", systemImage: "folder.badge.gearshape")
            }
        } label: {
            Label("가져오기", systemImage: "square.and.arrow.down")
        }
        .frame(width: 142, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .help("로그 파일, macOS 통합 로그, .logarchive를 가져옵니다.")
    }

    private var searchControls: some View {
        let hasQuery = !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return HStack(spacing: 8) {
            Label("검색", systemImage: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("검색어 또는 /정규식/", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 240, idealWidth: 340, maxWidth: 520)
                .help("일반 텍스트나 슬래시로 감싼 정규식을 검색합니다.")

            Button {
                viewModel.query = ""
                viewModel.statusMessage = "검색어를 지웠습니다."
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .opacity(hasQuery ? 1 : 0)
            .disabled(!hasQuery)
            .help("검색어 지우기")
            .accessibilityLabel("검색어 지우기")
            .accessibilityHidden(!hasQuery)
        }
    }

    private var viewControls: some View {
        HStack(spacing: 10) {
            Picker("보기", selection: $viewModel.displayMode) {
                ForEach(LogDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.label)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            tailToggle

            metadataFilterToggle
        }
    }

    private var tailToggle: some View {
        HStack(spacing: 6) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(.secondary)

            Text("실시간")
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Toggle("실시간 추적", isOn: $viewModel.tailEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .frame(width: 132, alignment: .leading)
        .disabled(viewModel.selectedSource?.supportsTail != true)
        .help("선택한 로그 파일에 추가되는 줄을 따라갑니다.")
    }

    private var metadataFilterToggle: some View {
        let isActive = viewModel.metadataFilters.isActive
        let isPresented = shouldShowMetadataFilterBar

        return Button {
            isMetadataFilterBarPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isPresented ? "tag.fill" : "tag")
                    .frame(width: 14)

                Text(isActive ? "메타 적용" : "메타")
                    .lineLimit(1)
            }
            .frame(width: 76, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
        .disabled(!viewModel.showsMetadataFilters)
        .help(isPresented ? "메타데이터 필터 숨기기" : "메타데이터 필터 보이기")
        .accessibilityLabel("메타데이터 필터")
        .accessibilityValue(isActive ? "필터 적용 중" : (isPresented ? "필터 막대 표시 중" : "필터 막대 숨김"))
    }

    private var levelFilterStrip: some View {
        HStack(spacing: 6) {
            let levelCounts = viewModel.levelCountsForCurrentMode()

            Label("심각도", systemImage: "slider.horizontal.3")
                .foregroundStyle(.secondary)

            ForEach(LogLevel.allCases, id: \.self) { level in
                LevelFilterButton(
                    level: level,
                    count: levelCounts[level, default: 0],
                    isSelected: viewModel.enabledLevels.contains(level)
                ) {
                    viewModel.toggleLevel(level)
                }
                .help("\(level.label) 로그 표시 여부를 바꿉니다.")
            }

            Divider()
                .frame(height: 18)

            Button("전체") {
                viewModel.showAllLevels()
            }
            .controlSize(.small)
            .disabled(viewModel.enabledLevels.count == LogLevel.allCases.count)
            .help("모든 심각도를 표시합니다.")

            Button("이슈만") {
                viewModel.showIssueLevelsOnly()
            }
            .controlSize(.small)
            .disabled(viewModel.enabledLevels == [.error, .fault])
            .help("오류와 장애만 표시합니다.")
        }
    }

    private var issueJumpButton: some View {
        Button {
            viewModel.selectNextIssue()
        } label: {
            Label("이슈 \(viewModel.issueCount)개", systemImage: "exclamationmark.triangle.fill")
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.orange)
        .help("다음 오류 또는 장애로 이동")
        .accessibilityLabel("다음 이슈로 이동, 이슈 \(viewModel.issueCount)개")
    }

    private var filterStatusBar: some View {
        HStack(spacing: 8) {
            if let queryWarning = viewModel.queryWarning {
                Label(queryWarning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            } else {
                Label(viewModel.filterSummary, systemImage: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        removableFilterChip("검색", systemImage: "magnifyingglass", help: "검색어 지우기") {
                            viewModel.query = ""
                        }
                    }

                    if viewModel.enabledLevels.count != LogLevel.allCases.count {
                        removableFilterChip(
                            "심각도 \(viewModel.enabledLevels.count)/\(LogLevel.allCases.count)",
                            systemImage: "slider.horizontal.3",
                            help: "심각도 필터 지우기"
                        ) {
                            viewModel.showAllLevels()
                        }
                    }

                    if viewModel.metadataFilters.isActive {
                        removableFilterChip("메타데이터", systemImage: "tag", help: "메타데이터 필터 지우기") {
                            viewModel.clearMetadataFilters()
                        }
                    }

                    if let token = viewModel.pinnedToken {
                        removableFilterChip(token.label, systemImage: "pin.fill", help: "고정값 해제") {
                            viewModel.clearPinnedToken()
                        }
                        .frame(maxWidth: 260)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.clearAllFilters()
            } label: {
                Label("필터 지우기", systemImage: "xmark.circle")
            }
            .disabled(!viewModel.hasActiveFilters)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private func removableFilterChip(
        _ title: String,
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .imageScale(.small)

                Text(title)
                    .lineLimit(1)

                Image(systemName: "xmark.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private var metadataFilterBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                metadataFilterTitle
                metadataFilterFields
                metadataFilterClearButton
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    metadataFilterTitle
                    Spacer(minLength: 0)
                    metadataFilterClearButton
                }

                metadataFilterFields
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private var metadataFilterTitle: some View {
        Label("메타데이터", systemImage: "tag")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var metadataFilterFields: some View {
        HStack(spacing: 8) {
            metadataTextField("서브시스템", text: metadataBinding(\.subsystem), idealWidth: 220)
            metadataTextField("프로세스", text: metadataBinding(\.process), idealWidth: 160)
            metadataTextField("카테고리", text: metadataBinding(\.category), idealWidth: 160)
        }
    }

    private var metadataFilterClearButton: some View {
        Button {
            viewModel.clearMetadataFilters()
        } label: {
            Label("메타데이터 필터 지우기", systemImage: "xmark.circle")
        }
        .labelStyle(.iconOnly)
        .disabled(!viewModel.metadataFilters.isActive)
        .help("메타데이터 필터 지우기")
        .accessibilityLabel("메타데이터 필터 지우기")
    }

    private func metadataTextField(
        _ placeholder: String,
        text: Binding<String>,
        idealWidth: CGFloat
    ) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 120, idealWidth: idealWidth, maxWidth: idealWidth)
    }

    private var shouldShowMetadataFilterBar: Bool {
        viewModel.metadataFilters.isActive || (isMetadataFilterBarPresented && viewModel.showsMetadataFilters)
    }

    private var statusBar: some View {
        HStack {
            Text(viewModel.statusMessage)
                .lineLimit(1)

            Spacer()

            if !viewModel.sources.isEmpty {
                if let queryWarning = viewModel.queryWarning {
                    Label(queryWarning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                if viewModel.issueCount > 0 {
                    Label("\(viewModel.issueCount)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                Text("\(viewModel.visibleEntries.count) / \(viewModel.totalEntryCount)줄")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private var supportedLogTypes: [UTType] {
        var types: [UTType] = [.plainText, .text, .json, .data]
        if let log = UTType(filenameExtension: "log") {
            types.append(log)
        }
        if let jsonl = UTType(filenameExtension: "jsonl") {
            types.append(jsonl)
        }
        if let logArchive = UTType(filenameExtension: UnifiedLogReader.archiveExtension) {
            types.append(logArchive)
        }
        return types
    }

    private var workspaceContentType: UTType {
        UTType(filenameExtension: LogWorkspaceStore.fileExtension) ?? .json
    }

    private var logArchiveContentType: UTType {
        UTType(filenameExtension: UnifiedLogReader.archiveExtension) ?? .package
    }

    private func openWorkspacePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [workspaceContentType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.openWorkspace(url)
        }
    }

    private func saveWorkspacePanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [workspaceContentType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Logdeck 작업공간.\(LogWorkspaceStore.fileExtension)"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.saveWorkspace(to: url)
        }
    }

    private func saveDiagnosticsPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Logdeck 진단.json"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.saveDiagnosticReport(to: url)
        }
    }

    private func openLogArchivePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [logArchiveContentType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.openLogArchive(url)
        }
    }

    private func metadataBinding(_ keyPath: WritableKeyPath<LogMetadataFilters, String>) -> Binding<String> {
        Binding {
            viewModel.metadataFilters[keyPath: keyPath]
        } set: { value in
            var filters = viewModel.metadataFilters
            filters[keyPath: keyPath] = value
            viewModel.metadataFilters = filters
        }
    }

    private func importDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        var didAcceptProvider = false

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            didAcceptProvider = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = DroppedFileURLDecoder.url(from: item) else {
                    return
                }

                Task { @MainActor in
                    viewModel.openFiles([url])
                }
            }
        }

        return didAcceptProvider
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

private struct LevelFilterButton: View {
    let level: LogLevel
    let count: Int
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)

                Text(level.label)

                Text("\(count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(level.isIssueLevel ? .semibold : .regular))
            .foregroundStyle(isSelected ? foregroundStyle : AnyShapeStyle(.secondary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundStyle)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(borderStyle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .opacity(isSelected ? 1 : 0.48)
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
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

    private var foregroundStyle: AnyShapeStyle {
        if level.isIssueLevel || level == .warning {
            return AnyShapeStyle(tint)
        }

        return AnyShapeStyle(.primary)
    }

    private var backgroundStyle: Color {
        guard isSelected else {
            return Color.clear
        }

        if level.isIssueLevel || level == .warning {
            return tint.opacity(0.16)
        }

        return Color.secondary.opacity(0.09)
    }

    private var borderStyle: Color {
        guard isSelected else {
            return Color.secondary.opacity(0.18)
        }

        if level.isIssueLevel || level == .warning {
            return tint.opacity(0.42)
        }

        return Color.secondary.opacity(0.18)
    }
}
