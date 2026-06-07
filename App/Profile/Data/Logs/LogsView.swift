import SwiftUI
import Hanami

struct LogsView: View {

    @State private var modules: [LogModuleEntry] = []
    @State private var isShowingClearConfirmation: Bool = false

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isShowingClearConfirmation = true
                } label: {
                    Label(String(localized: "Logs.Clear", table: "DataManagement"),
                          systemImage: "trash")
                }
                .tint(.red)
                .disabled(modules.isEmpty)
            }
        }
        .alert(
            String(localized: "Logs.Clear.Confirm", table: "DataManagement"),
            isPresented: $isShowingClearConfirmation
        ) {
            Button(String(localized: "Logs.Clear", table: "DataManagement"),
                   role: .destructive) {
                clearAllLogs()
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text(String(localized: "Logs.Clear.Message", table: "DataManagement"))
        }
        .task {
            await loadModules()
        }
    }

    private func clearAllLogs() {
        LogManager.shared.clearAll()
        withAnimation {
            modules = []
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
