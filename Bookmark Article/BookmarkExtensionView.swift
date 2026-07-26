import SwiftUI
import UniformTypeIdentifiers
import Hanami

struct BookmarkExtensionView: View {

    weak var extensionContext: NSExtensionContext?

    @State private var url: URL?
    @State private var pageTitle = ""
    @State private var folders: [BookmarkFolder] = []
    @State private var selectedFolderID: Int64?
    @State private var isLoading = true
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "BookmarkArticle.Title", table: "Articles"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) { complete() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) { save() }
                            .disabled(url == nil || didSave)
                    }
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let url {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayTitle(for: url))
                            .font(.headline)
                            .lineLimit(2)
                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Section {
                    Picker(selection: $selectedFolderID) {
                        Text(String(localized: "BookmarkArticle.NoFolder", table: "Articles"))
                            .tag(Int64?.none)
                        ForEach(folders) { folder in
                            Label(folder.name, systemImage: folder.icon)
                                .tag(Int64?.some(folder.id))
                        }
                    } label: {
                        Text(String(localized: "BookmarkArticle.Folder", table: "Articles"))
                    }
                } header: {
                    Text(String(localized: "BookmarkArticle.Folder.Header", table: "Articles"))
                }
            }
        } else {
            ContentUnavailableView(
                String(localized: "BookmarkArticle.NoURL", table: "Articles"),
                systemImage: "link.badge.plus"
            )
        }
    }

    private func displayTitle(for url: URL) -> String {
        pageTitle.isEmpty ? (url.host ?? url.absoluteString) : pageTitle
    }

    private func load() async {
        folders = (try? DatabaseManager.shared.allBookmarkFolders()) ?? []
        await extractSharedURL()
        isLoading = false
    }

    private func extractSharedURL() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        for item in items {
            if let text = item.attributedContentText?.string, !text.isEmpty {
                pageTitle = text
            }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                   let sharedURL = loaded as? URL {
                    url = sharedURL
                    return
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                   let text = loaded as? String,
                   let parsed = URL(string: text) {
                    url = parsed
                    return
                }
            }
        }
    }

    private func save() {
        guard let url else { return }
        try? DatabaseManager.shared.insertExternalBookmark(
            url: url.absoluteString,
            title: displayTitle(for: url),
            folderID: selectedFolderID
        )
        didSave = true
        complete()
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
