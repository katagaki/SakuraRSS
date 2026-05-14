import SwiftUI
import Hanami

struct LogModuleView: View {

    let module: String

    @State private var contents: String = ""
    @State private var isLoading: Bool = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LogTextView(text: contents)
                    .ignoresSafeArea(.container)
            }
        }
        .sakuraBackground()
        .navigationTitle(module)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let fileURL = LogManager.shared.fileURL(for: module),
                   FileManager.default.fileExists(atPath: fileURL.path) {
                    ShareLink(item: fileURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await loadContents()
        }
    }

    private func loadContents() async {
        let module = module
        let text = await Task.detached(priority: .utility) {
            LogManager.shared.contents(for: module)
        }.value
        contents = text
        isLoading = false
    }
}
