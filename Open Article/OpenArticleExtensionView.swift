import SwiftUI
import UniformTypeIdentifiers

struct OpenArticleExtensionView: View {

    weak var extensionContext: NSExtensionContext?
    let onOpen: (URL) -> Void

    @State private var sourceURL: URL?
    @State private var status: Status = .loading
    @State private var selectedMode: OpenArticleRequest.Mode = .viewer

    enum Status {
        case loading
        case ready
        case noURL
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "OpenArticle.Title", table: "OpenArticle"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            extensionContext?.completeRequest(returningItems: nil)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "OpenArticle.Open", table: "OpenArticle")) {
                            openInHost()
                        }
                        .disabled(status != .ready)
                    }
                }
        }
        .task {
            await loadSourceURL()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .loading:
            ContentUnavailableView {
                ProgressView()
            } description: {
                Text(String(localized: "OpenArticle.Loading", table: "OpenArticle"))
            }
        case .noURL:
            ContentUnavailableView(
                String(localized: "OpenArticle.NoURL", table: "OpenArticle"),
                systemImage: "link.badge.plus"
            )
        case .ready:
            form
        }
    }

    private var form: some View {
        Form {
            if let sourceURL {
                Section {
                    Text(sourceURL.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .truncationMode(.middle)
                } header: {
                    Text(String(localized: "OpenArticle.Section.URL", table: "OpenArticle"))
                }
            }

            Section {
                Picker(
                    String(localized: "FeedEdit.OpenIn", table: "OpenArticle"),
                    selection: $selectedMode
                ) {
                    Text(String(localized: "FeedEdit.OpenIn.InAppViewer", table: "OpenArticle"))
                        .tag(OpenArticleRequest.Mode.viewer)
                    Text(String(localized: "FeedEdit.OpenIn.ClearThisPage", table: "OpenArticle"))
                        .tag(OpenArticleRequest.Mode.clearThisPage)
                    Text(String(localized: "FeedEdit.OpenIn.Readability", table: "OpenArticle"))
                        .tag(OpenArticleRequest.Mode.readability)
                    Text(String(localized: "FeedEdit.OpenIn.ArchivePh", table: "OpenArticle"))
                        .tag(OpenArticleRequest.Mode.archiveToday)
                }
            } header: {
                Text(String(localized: "FeedEdit.Behavior", table: "OpenArticle"))
            }
        }
    }

    private func openInHost() {
        guard let sourceURL else { return }
        let request = OpenArticleRequest(
            url: sourceURL.absoluteString,
            mode: selectedMode,
            textMode: .fetch
        )
        guard let url = request.makeURL() else { return }
        onOpen(url)
    }

    private func loadSourceURL() async {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            status = .noURL
            return
        }
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let value = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                   let url = value as? URL {
                    sourceURL = url
                    status = .ready
                    return
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let value = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                   let text = value as? String,
                   let url = URL(string: text) {
                    sourceURL = url
                    status = .ready
                    return
                }
            }
        }
        status = .noURL
    }
}
