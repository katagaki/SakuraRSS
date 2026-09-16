import SwiftUI
import Hanami

/// Stackless bookmarks view used inside a parent `NavigationStack`
/// (the Home tab and the iPad sidebar detail column).
struct BookmarksContentView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace

    @State private var bookmarkedArticles: [Article] = []
    @State private var bookmarkedArticleIDs: [Int64] = []
    @State private var displayStyle: FeedDisplayStyle
    @State private var showingDeleteReadAlert = false
    @State private var isCreatingFolder = false
    @State private var isExporting = false
    @State private var searchText = ""
    @State private var tagNamesByArticleID: [Int64: [String]] = [:]
    @AppStorage(BookmarkSortOrder.storageKey) private var sortOrder: BookmarkSortOrder = .newest

    /// Sheets want an inline title; the tab and sidebar hosts want the large one.
    private let titleDisplayMode: ToolbarTitleDisplayMode

    @Namespace private var newFolderNamespace
    private let newFolderTransitionID = "NewFolder"

    private var hasImages: Bool {
        visibleArticles.contains { $0.imageURL != nil }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Search and sort are applied to the loaded page rather than re-queried,
    /// so typing stays responsive on a large collection.
    private var visibleArticles: [Article] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let matched = query.isEmpty ? bookmarkedArticles : bookmarkedArticles.filter { article in
            BookmarkSorting.matches(
                article,
                query: query,
                tagNames: tagNamesByArticleID[article.id] ?? []
            )
        }
        return BookmarkSorting.sorted(matched, by: sortOrder) { article in
            feedManager.feed(forArticle: article)?.title
                ?? URL(string: article.url)?.host()
                ?? article.url
        }
    }

    private var hasFolders: Bool {
        !feedManager.bookmarkFolders.isEmpty
    }

    init(titleDisplayMode: ToolbarTitleDisplayMode = .inlineLarge) {
        self.titleDisplayMode = titleDisplayMode
        let raw = UserDefaults.standard.string(forKey: "Display.DefaultBookmarksStyle")
        let defaultRaw = UserDefaults.standard.string(forKey: "Display.DefaultStyle") ?? FeedDisplayStyle.inbox.rawValue
        let fallback = FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox
        self._displayStyle = State(initialValue: raw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? fallback)
    }

    var body: some View {
        let effectiveStyle = effectiveDisplayStyle
        Group {
            if visibleArticles.isEmpty && isSearching {
                ContentUnavailableView.search(text: searchText)
            } else if bookmarkedArticles.isEmpty && !hasFolders {
                ContentUnavailableView {
                    Label(String(localized: "Bookmarks.Empty.Title", table: "Articles"),
                          systemImage: "bookmark")
                } description: {
                    Text(String(localized: "Bookmarks.Empty.Description", table: "Articles"))
                }
            } else {
                DisplayStyleContentView(
                    style: effectiveStyle,
                    articles: visibleArticles,
                    headerView: isSearching ? nil : AnyView(BookmarksHeaderSections()),
                    usesStackLayout: true
                )
            }
        }
        .environment(\.isBookmarksSurface, true)
        .bookmarkDetailSheet()
        .bookmarkReadingOptions()
        .navigationTitle("Tabs.Bookmarks")
        .toolbarTitleDisplayMode(titleDisplayMode)
        .sakuraBackground()
        .searchable(text: $searchText,
                    prompt: String(localized: "Bookmarks.Search.Prompt", table: "Articles"))
        .navigationDestination(for: BookmarkSmartGroup.self) { group in
            BookmarkSmartGroupArticlesView(group: group)
                .environment(\.zoomNamespace, zoomNamespace)
        }
        .navigationDestination(for: BookmarkTag.self) { tag in
            BookmarkTagArticlesView(tag: tag)
                .environment(\.zoomNamespace, zoomNamespace)
        }
        .navigationDestination(for: BookmarkFolder.self) { folder in
            // Destinations don't inherit the environment applied around
            // this view, so the host's zoom namespace is forwarded manually.
            BookmarkFolderArticlesView(folder: folder)
                .environment(\.zoomNamespace, zoomNamespace)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isCreatingFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .matchedTransitionSource(id: newFolderTransitionID, in: newFolderNamespace)
                }
                .accessibilityLabel(String(localized: "Folders.New", table: "Articles"))
            }
            if !bookmarkedArticles.isEmpty {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingDeleteReadAlert = true
                    } label: {
                        Image(systemName: "bookmark.slash")
                    }
                }
                #if !os(visionOS)
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                #endif
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isExporting = true
                        } label: {
                            Label(String(localized: "BookmarksExport.Title", table: "Articles"),
                                  systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        BookmarkSortMenu(sortOrder: $sortOrder)
                        Divider()
                        DisplayStylePicker(
                            displayStyle: $displayStyle,
                            hasImages: hasImages,
                            showCards: false,
                            showScroll: false
                        )
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .menuActionDismissBehavior(.disabled)
                }
            }
        }
        .animation(.smooth.speed(2.0), value: displayStyle)
        .animation(.smooth.speed(2.0), value: bookmarkedArticleIDs)
        .animation(.smooth.speed(2.0), value: sortOrder)
        .alert(String(localized: "Bookmarks.DeleteAllRead", table: "Articles"), isPresented: $showingDeleteReadAlert) {
            Button(String(localized: "Bookmarks.DeleteAllRead.Confirm", table: "Articles"), role: .destructive) {
                try? DatabaseManager.shared.removeReadBookmarks()
                Task { await reloadBookmarks() }
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text(String(localized: "Bookmarks.DeleteAllRead.Message", table: "Articles"))
        }
        .sheet(isPresented: $isExporting) {
            BookmarkExportSheet()
        }
        .sheet(isPresented: $isCreatingFolder) {
            BookmarkFolderEditSheet(folder: nil)
                .environment(feedManager)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
                .navigationTransition(.zoom(sourceID: newFolderTransitionID, in: newFolderNamespace))
        }
        .onChange(of: displayStyle) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "Display.DefaultBookmarksStyle")
        }
        .task(id: feedManager.dataRevision) {
            await reloadBookmarks()
        }
    }

    private func reloadBookmarks() async {
        let (loaded, tagNames) = await Task.detached {
            let database = DatabaseManager.shared
            return (
                (try? database.unorganizedBookmarkedArticles()) ?? [],
                (try? database.bookmarkTagNamesByArticleID()) ?? [:]
            )
        }.value
        if Task.isCancelled { return }
        bookmarkedArticles = loaded
        bookmarkedArticleIDs = loaded.map(\.id)
        tagNamesByArticleID = tagNames
    }

    private var effectiveDisplayStyle: FeedDisplayStyle {
        if !hasImages && displayStyle.requiresImages {
            return .inbox
        }
        // Immersive styles can't host the folder grid or the move-to-folder
        // interactions, so they are unavailable in Bookmarks.
        if displayStyle == .podcast || displayStyle == .cards || displayStyle == .scroll {
            return .inbox
        }
        return displayStyle
    }
}
