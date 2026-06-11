import SwiftUI
import Hanami

struct BookmarkFolderEditSheet: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss

    let folder: BookmarkFolder?

    @State private var name = ""
    @State private var selectedIcon = ListIcon.bookClosed.rawValue
    @State private var allBookmarks: [Article] = []
    @State private var selectedArticleIDs: Set<Int64> = []
    @State private var hasInitialized = false
    @FocusState private var isNameFieldFocused: Bool

    private var isEditing: Bool { folder != nil }

    private var nameAlreadyExists: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return feedManager.bookmarkFolders.contains { existing in
            existing.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
            && existing.id != (folder?.id ?? -1)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !nameAlreadyExists
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(String(localized: "FolderEdit.NamePlaceholder", table: "Articles"),
                              text: $name)
                        .focused($isNameFieldFocused)
                    if nameAlreadyExists {
                        Text(String(localized: "FolderEdit.NameExists", table: "Articles"))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section(String(localized: "FolderEdit.Icon", table: "Articles")) {
                    iconPicker
                }

                if isEditing {
                    Section(String(localized: "FolderEdit.Bookmarks", table: "Articles")) {
                        if allBookmarks.isEmpty {
                            Text(String(localized: "FolderEdit.Bookmarks.Empty", table: "Articles"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(allBookmarks) { article in
                                bookmarkSelectionRow(article)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isEditing
                             ? String(localized: "FolderEdit.Title.Edit", table: "Articles")
                             : String(localized: "FolderEdit.Title.New", table: "Articles"))
            .navigationBarTitleDisplayMode(.inline)
            .compatibleSoftScrollEdgeEffectStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                initializeIfNeeded()
            }
        }
    }

    private var iconPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(
                rows: Array(repeating: GridItem(.fixed(44), spacing: 12), count: 4),
                spacing: 12
            ) {
                ForEach(ListIcon.allCases) { icon in
                    Button {
                        selectedIcon = icon.rawValue
                    } label: {
                        Image(systemName: icon.rawValue)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(
                                selectedIcon == icon.rawValue
                                    ? AnyShapeStyle(.tint.opacity(0.4))
                                    : AnyShapeStyle(.clear)
                            )
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(icon.rawValue)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .listRowInsets(EdgeInsets())
    }

    private func bookmarkSelectionRow(_ article: Article) -> some View {
        Button {
            if selectedArticleIDs.contains(article.id) {
                selectedArticleIDs.remove(article.id)
            } else {
                selectedArticleIDs.insert(article.id)
            }
        } label: {
            HStack(spacing: 12) {
                CachedAsyncImage(url: article.imageURL.flatMap(URL.init(string:)), maxPixelSize: 80) {
                    Image(systemName: "bookmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 28, height: 28)
                .clipShape(.rect(cornerRadius: 6))
                Text(article.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedArticleIDs.contains(article.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.accent)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func initializeIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true
        if let folder {
            allBookmarks = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
            name = folder.name
            selectedIcon = folder.icon
            selectedArticleIDs = feedManager.bookmarkFolderArticleIDs(folder)
        } else {
            isNameFieldFocused = true
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let folder {
            feedManager.setBookmarkFolderMembership(folder, articleIDs: selectedArticleIDs)
            feedManager.updateBookmarkFolder(folder, name: trimmedName, icon: selectedIcon)
        } else {
            try? feedManager.createBookmarkFolder(name: trimmedName, icon: selectedIcon)
        }
        dismiss()
    }
}
