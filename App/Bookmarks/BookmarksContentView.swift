import SwiftUI
import Hanami

/// Stackless bookmarks view used inside a parent `NavigationStack`
/// (the Home tab and the iPad sidebar detail column).
struct BookmarksContentView: View {

    @Environment(FeedManager.self) var feedManager

    @State private var bookmarkedArticles: [Article] = []
    @State private var displayStyle: FeedDisplayStyle
    @State private var showingDeleteReadAlert = false
    @State private var isCreatingFolder = false
    @State private var selectedFolder: BookmarkFolder?

    private var hasImages: Bool {
        bookmarkedArticles.contains { $0.imageURL != nil }
    }

    private var hasFolders: Bool {
        !feedManager.bookmarkFolders.isEmpty
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "Display.DefaultBookmarksStyle")
        let defaultRaw = UserDefaults.standard.string(forKey: "Display.DefaultStyle") ?? FeedDisplayStyle.inbox.rawValue
        let fallback = FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox
        self._displayStyle = State(initialValue: raw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? fallback)
    }

    var body: some View {
        let effectiveStyle = effectiveDisplayStyle
        Group {
            if bookmarkedArticles.isEmpty && !hasFolders {
                ContentUnavailableView {
                    Label(String(localized: "Bookmarks.Empty.Title", table: "Articles"),
                          systemImage: "bookmark")
                } description: {
                    Text(String(localized: "Bookmarks.Empty.Description", table: "Articles"))
                }
            } else {
                DisplayStyleContentView(
                    style: effectiveStyle,
                    articles: bookmarkedArticles,
                    headerView: hasFolders
                        ? AnyView(BookmarkFoldersGridSection { folder in
                            selectedFolder = folder
                        })
                        : nil
                )
            }
        }
        .navigationTitle("Tabs.Bookmarks")
        .toolbarTitleDisplayMode(.inlineLarge)
        .sakuraBackground()
        .navigationDestination(item: $selectedFolder) { folder in
            BookmarkFolderArticlesView(folder: folder)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isCreatingFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
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
                        DisplayStylePicker(
                            displayStyle: $displayStyle,
                            hasImages: hasImages,
                            showCards: false
                        )
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .menuActionDismissBehavior(.disabled)
                }
            }
        }
        .animation(.smooth.speed(2.0), value: displayStyle)
        .animation(.smooth.speed(2.0), value: bookmarkedArticles)
        .alert(String(localized: "Bookmarks.DeleteAllRead", table: "Articles"), isPresented: $showingDeleteReadAlert) {
            Button(String(localized: "Bookmarks.DeleteAllRead.Confirm", table: "Articles"), role: .destructive) {
                try? DatabaseManager.shared.removeReadBookmarks()
                reloadBookmarks()
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text(String(localized: "Bookmarks.DeleteAllRead.Message", table: "Articles"))
        }
        .sheet(isPresented: $isCreatingFolder) {
            BookmarkFolderEditSheet(folder: nil)
                .environment(feedManager)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
        }
        .onChange(of: displayStyle) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "Display.DefaultBookmarksStyle")
        }
        .onAppear {
            reloadBookmarks()
        }
        .onChange(of: feedManager.dataRevision) {
            reloadBookmarks()
        }
    }

    private func reloadBookmarks() {
        bookmarkedArticles = feedManager.unorganizedBookmarkedArticles()
    }

    private var effectiveDisplayStyle: FeedDisplayStyle {
        if !hasImages && displayStyle.requiresImages {
            return .inbox
        }
        if displayStyle == .podcast {
            return .inbox
        }
        return displayStyle
    }
}
