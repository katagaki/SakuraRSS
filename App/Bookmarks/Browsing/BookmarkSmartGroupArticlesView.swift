import SwiftUI
import Hanami

struct BookmarkSmartGroupArticlesView: View {

    @Environment(FeedManager.self) private var feedManager

    let group: BookmarkSmartGroup

    @State private var articles: [Article] = []
    @State private var articleIDs: [Int64] = []
    @State private var displayStyle: FeedDisplayStyle

    init(group: BookmarkSmartGroup) {
        self.group = group
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
                    Label(String(localized: "Bookmarks.Empty.Title", table: "Articles"),
                          systemImage: "bookmark")
                } description: {
                    Text(String(localized: "Bookmarks.Empty.Description", table: "Articles"))
                }
            } else {
                DisplayStyleContentView(style: effectiveDisplayStyle, articles: articles)
            }
        }
        .environment(\.isBookmarksSurface, true)
        .bookmarkDetailSheet()
        .bookmarkReadingOptions()
        .sakuraBackground()
        .navigationTitle(BookmarkSmartGroupLabel.title(for: group))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
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
        .animation(.smooth.speed(2.0), value: articleIDs)
        .task(id: feedManager.dataRevision) {
            await reloadArticles()
        }
    }

    private func reloadArticles() async {
        let group = group
        let loaded = await Task.detached {
            let database = DatabaseManager.shared
            return switch group {
            case .all: (try? database.bookmarkedArticles()) ?? []
            case .unread: (try? database.unreadBookmarkedArticles()) ?? []
            case .unsorted: (try? database.unorganizedBookmarkedArticles()) ?? []
            }
        }.value
        if Task.isCancelled { return }
        articles = loaded
        articleIDs = loaded.map(\.id)
    }
}
