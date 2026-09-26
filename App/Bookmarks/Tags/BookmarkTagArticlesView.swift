import EnhancedNavigation
import SwiftUI
import Hanami

struct BookmarkTagArticlesView: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isBrowserChromeActive) private var isBrowserChromeActive

    let tag: BookmarkTag

    @State private var articles: [Article] = []
    @State private var articleIDs: [Int64] = []
    @State private var displayStyle: FeedDisplayStyle

    init(tag: BookmarkTag) {
        self.tag = tag
        let raw = UserDefaults.standard.string(forKey: "Display.DefaultBookmarksStyle")
        self._displayStyle = State(initialValue: raw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? .inbox)
    }

    private var hasImages: Bool {
        articles.contains { $0.imageURL != nil }
    }

    private var effectiveDisplayStyle: FeedDisplayStyle {
        if !hasImages && displayStyle.requiresImages { return .inbox }
        if displayStyle == .podcast || displayStyle == .cards || displayStyle == .scroll { return .inbox }
        return displayStyle
    }

    var body: some View {
        Group {
            if articles.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Tag.Empty.Title", table: "Articles"), systemImage: "tag")
                } description: {
                    Text(String(localized: "Tag.Empty.Description", table: "Articles"))
                }
            } else {
                DisplayStyleContentView(
                    style: effectiveDisplayStyle,
                    articles: articles
                )
            }
        }
        .environment(\.isBookmarksSurface, true)
        .bookmarkDetailSheet()
        .bookmarkReadingOptions()
        .sakuraBackground()
        .navigationTitle(tag.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !isBrowserChromeActive {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
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
        .animation(.smooth.speed(2.0), value: articleIDs)
        .tabOmniboxAccessory(isEnabled: isBrowserChromeActive) {
            BrowserPageDisplayMenu(options: browserDisplayStyleOptions)
        }
        .task(id: feedManager.dataRevision) {
            await reloadArticles()
        }
    }

    private func reloadArticles() async {
        let tagID = tag.id
        let loaded = await Task.detached {
            (try? DatabaseManager.shared.bookmarkedArticles(taggedWithID: tagID)) ?? []
        }.value
        if Task.isCancelled { return }
        if loaded.isEmpty, !feedManager.allBookmarkTags().contains(where: { $0.id == tagID }) {
            dismiss()
            return
        }
        articles = loaded
        articleIDs = loaded.map(\.id)
    }

    /// The browser hides the top bar, so the display style goes in the
    /// omnibox's menu instead.
    private var browserDisplayStyleOptions: BrowserDisplayStyleOptions {
        BrowserDisplayStyleOptions(
            displayStyle: $displayStyle,
            hasImages: hasImages,
            showsPodcast: false,
            showsCards: false,
            showsScroll: false
        )
    }
}
