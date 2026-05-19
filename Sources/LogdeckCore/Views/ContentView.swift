import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct ContentView: View {
    @StateObject private var viewModel = LogWorkspaceViewModel()
    @State private var isImporterPresented = false
    @State private var isDropTargeted = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SourceSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 210, ideal: 250)
        } detail: {
            VStack(spacing: 0) {
                toolbar
                Divider()
                if viewModel.showsMetadataFilters {
                    metadataFilterBar
                    Divider()
                }
                LogTableView(viewModel: viewModel)
                Divider()
                statusBar
            }
        }
        .inspector(isPresented: .constant(true)) {
            LogInspectorView(viewModel: viewModel)
                .inspectorColumnWidth(min: 280, ideal: 340, max: 440)
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
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .frame(minWidth: 980, minHeight: 620)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                openWorkspacePanel()
            } label: {
                Label("Open Workspace", systemImage: "folder.badge.gearshape")
            }
            .labelStyle(.iconOnly)
            .help("Open workspace")

            Button {
                saveWorkspacePanel()
            } label: {
                Label("Save Workspace", systemImage: "square.and.arrow.down")
            }
            .labelStyle(.iconOnly)
            .disabled(viewModel.sources.isEmpty)
            .help("Save workspace")

            Button {
                saveDiagnosticsPanel()
            } label: {
                Label("Save Diagnostics", systemImage: "waveform.path.ecg.rectangle")
            }
            .labelStyle(.iconOnly)
            .help("Save diagnostics")

            Divider()
                .frame(height: 24)

            Button {
                isImporterPresented = true
            } label: {
                Label("Open", systemImage: "folder")
            }
            .keyboardShortcut("o")

            Button {
                viewModel.importRecentUnifiedLogs()
            } label: {
                Label("macOS Logs", systemImage: "terminal")
            }
            .help("Import recent macOS unified logs")

            Button {
                openLogArchivePanel()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .help("Open a .logarchive package")

            Divider()
                .frame(height: 24)

            TextField("Search or /regex/", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)

            Picker("View", selection: $viewModel.displayMode) {
                ForEach(LogDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.label)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            if let token = viewModel.pinnedToken {
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.secondary)
                    Text(token.label)
                        .lineLimit(1)
                    Button {
                        viewModel.clearPinnedToken()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .help("Clear pinned token")
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: 240)
            }

            ForEach(LogLevel.allCases, id: \.self) { level in
                Toggle(isOn: levelBinding(level)) {
                    Text(level.label)
                }
                .toggleStyle(.button)
            }

            Spacer()

            Toggle(isOn: $viewModel.tailEnabled) {
                Label("Tail", systemImage: "dot.radiowaves.left.and.right")
            }
            .toggleStyle(.switch)
            .disabled(viewModel.selectedSource?.supportsTail != true)
            .help("Watch the selected log file for appended lines.")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var metadataFilterBar: some View {
        HStack(spacing: 8) {
            Label("Unified", systemImage: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)

            TextField("Subsystem", text: metadataBinding(\.subsystem))
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            TextField("Process", text: metadataBinding(\.process))
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)

            TextField("Category", text: metadataBinding(\.category))
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)

            Button {
                viewModel.clearMetadataFilters()
            } label: {
                Label("Clear Metadata Filters", systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
            .disabled(!viewModel.metadataFilters.isActive)
            .help("Clear metadata filters")

            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private var statusBar: some View {
        HStack {
            Text(viewModel.statusMessage)
                .lineLimit(1)

            Spacer()

            Text("\(viewModel.visibleEntries.count) / \(viewModel.totalEntryCount) lines")
                .monospacedDigit()
                .foregroundStyle(.secondary)
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
        panel.nameFieldStringValue = "Logdeck Workspace.\(LogWorkspaceStore.fileExtension)"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.saveWorkspace(to: url)
        }
    }

    private func saveDiagnosticsPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Logdeck Diagnostics.json"

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

    private func levelBinding(_ level: LogLevel) -> Binding<Bool> {
        Binding {
            viewModel.enabledLevels.contains(level)
        } set: { _ in
            viewModel.toggleLevel(level)
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
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = url(fromDropItem: item) else {
                    return
                }

                Task { @MainActor in
                    viewModel.openFiles([url])
                }
            }
        }

        return true
    }

    private func url(fromDropItem item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data,
           let string = String(data: data, encoding: .utf8) {
            return URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }
}
