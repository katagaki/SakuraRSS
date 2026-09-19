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
    @State private var isSaving = false
    @State private var customTitle = ""
    @State private var suggestedTags: [String] = []
    @State private var acceptedTags: Set<String> = []

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
                        Button(role: .confirm) {
                            Task { await save() }
                        }
                        .disabled(url == nil || didSave || isSaving)
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
                    TextField(displayTitle(for: url), text: $customTitle, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text(String(localized: "BookmarkArticle.Title.Header", table: "Articles"))
                } footer: {
                    Text(String(localized: "BookmarkArticle.Title.Footer", table: "Articles"))
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

                if !suggestedTags.isEmpty {
                    Section {
                        ForEach(suggestedTags, id: \.self) { tag in
                            Toggle(tag, isOn: Binding(
                                get: { acceptedTags.contains(tag) },
                                set: { isOn in
                                    if isOn { acceptedTags.insert(tag) } else { acceptedTags.remove(tag) }
                                }
                            ))
                        }
                    } header: {
                        Text(String(localized: "BookmarkArticle.Tags.Header", table: "Articles"))
                    } footer: {
                        Text(String(localized: "BookmarkArticle.Tags.Footer", table: "Articles"))
                    }
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
        if let url {
            suggestedTags = BookmarkAutoTagger.suggestedTags(
                title: displayTitle(for: url),
                url: url.absoluteString
            )
            acceptedTags = Set(suggestedTags)
        }
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

    private func save() async {
        guard let url else { return }
        isSaving = true
        let database = DatabaseManager.shared
        let articleID = try? database.insertExternalBookmark(
            url: url.absoluteString,
            title: displayTitle(for: url),
            folderID: selectedFolderID
        )
        let trimmedTitle = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let articleID, !trimmedTitle.isEmpty, trimmedTitle != displayTitle(for: url) {
            try? database.setCustomTitle(trimmedTitle, forArticleID: articleID)
        }
        if let articleID {
            for tag in suggestedTags where acceptedTags.contains(tag) {
                try? database.addBookmarkTag(named: tag, toArticleID: articleID, isAutomatic: true)
            }
        }
        didSave = true
        // The extension is the only chance to reach the page while it is still
        // in the share context; the app backfills anything missed here.
        if let articleID {
            await BookmarkPreviewResolver.resolvePreview(
                forArticleID: articleID,
                url: url.absoluteString
            )
        }
        complete()
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
