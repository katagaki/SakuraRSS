import SwiftUI
import Hanami

struct LogsView: View {

    @State private var modules: [LogModuleEntry] = []

    var body: some View {
        List {
            if modules.isEmpty {
                Section {
                    Text(String(localized: "Logs.Empty", table: "DataManagement"))
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(modules) { entry in
                        NavigationLink {
                            LogModuleView(module: entry.module)
                        } label: {
                            HStack {
                                Text(entry.module)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: entry.bytes, countStyle: .file))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .sakuraBackground()
        .navigationTitle(String(localized: "Section.Logs", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
        .task {
            await loadModules()
        }
    }

    private func loadModules() async {
        let entries = await Task.detached(priority: .utility) {
            let manager = LogManager.shared
            return manager.availableModules().map { module in
                LogModuleEntry(module: module, bytes: manager.size(for: module))
            }
        }.value
        modules = entries
    }
}

private struct LogModuleEntry: Identifiable, Sendable {
    let module: String
    let bytes: Int64
    var id: String { module }
}
