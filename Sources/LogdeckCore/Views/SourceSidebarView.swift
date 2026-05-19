import SwiftUI

struct SourceSidebarView: View {
    @ObservedObject var viewModel: LogWorkspaceViewModel

    var body: some View {
        List(selection: $viewModel.selectedSourceID) {
            Section("Sources") {
                ForEach(viewModel.sources) { source in
                    Button {
                        viewModel.selectSource(source)
                    } label: {
                        HStack {
                            Image(systemName: source.isFileBacked ? "doc.text" : "terminal")
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name)
                                    .lineLimit(1)
                                Text("\(source.entries.count) lines")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .tag(source.id)
                }
            }
        }
        .navigationTitle("Logdeck")
    }
}
