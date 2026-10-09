import Hanami
import SwiftUI

/// The grid styles, which fill the page instead of sitting beside the reader;
/// content opens full width, as it does from Today.
struct ContentGridPage: View {

    let location: BrowserLocation
    let style: FeedDisplayStyle
    let feedManager: FeedManager
    let actions: TodayActions
    let revisions: WindowDataRevisions
    @State private var articles: [Article] = []
    @State private var allArticles: [Article] = []
    @State private var presentation = ContentPresentation()
    @State private var presentedLocation: BrowserLocation?

    var body: some View {
        Group {
            if style == .scroll {
                ContentScrollPager(articles: articles) { article in item(article) }
            } else {
                ScrollView {
                    content
                        .padding(20)
                }
            }
        }
        .overlay {
            if articles.isEmpty {
                ContentEmptyStateView()
            }
        }
        .environment(feedManager)
        .task(id: "\(location.persistenceToken)|\(revisions.dataRevision)") {
            let loaded = ContentQuery(feedManager: feedManager).articles(for: location)
            if presentedLocation == location {
                presentation.absorb(loaded, isRead: feedManager.isRead)
            } else {
                presentedLocation = location
                presentation.begin(with: loaded, isRead: feedManager.isRead, settings: currentSettings)
            }
            allArticles = loaded
            articles = presentation.present(loaded)
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            restartIfSettingsChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: FeedManager.pagePreferencesDidChangeNotification)) { _ in
            restartIfSettingsChanged()
        }
    }

    private var currentSettings: ContentPresentation.Settings {
        .current(for: location, in: feedManager)
    }

    private func restartIfSettingsChanged() {
        guard presentation.settings != currentSettings else { return }
        presentation.begin(with: allArticles, isRead: feedManager.isRead, settings: currentSettings)
        articles = presentation.present(allArticles)
    }

    /// Batching reveals the next batch once the last item shows.
    private func loadMoreIfLast(_ article: Article) {
        guard article.id == articles.last?.id, presentation.canLoadMore(allArticles) else { return }
        presentation.loadMore(of: allArticles)
        articles = presentation.present(allArticles)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .masonry:
            ContentMasonryGrid(articles: articles) { article in item(article) }
        case .cards:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: spacing)], spacing: spacing) {
                ForEach(articles) { article in
                    item(article)
                        .aspectRatio(ContentImmersiveTile.cardAspectRatio, contentMode: .fit)
                }
            }
        default:
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: spacing, alignment: .top)],
                spacing: spacing
            ) {
                ForEach(articles) { article in item(article) }
            }
        }
    }

    private func item(_ article: Article) -> some View {
        Button {
            actions.open(.article(article.id))
        } label: {
            if style == .cards || style == .scroll {
                ContentImmersiveTile(
                    article: article,
                    feed: feedManager.feedsByID[article.feedID],
                    isRead: feedManager.isRead(article),
                    style: style
                )
            } else {
                ContentGridItem(
                    article: article,
                    feedTitle: feedManager.feedsByID[article.feedID]?.title,
                    isRead: feedManager.isRead(article),
                    style: style
                )
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            ContentContextMenu(article: article, feedManager: feedManager, actions: actions)
        }
        .markReadOnScroll(article: article)
        .onAppear { loadMoreIfLast(article) }
    }

    private var minimumWidth: CGFloat {
        switch style {
        case .photos: 150
        case .grid, .podcast: 170
        case .video: 260
        case .magazine: 280
        case .cards: 260
        default: 340
        }
    }

    private var spacing: CGFloat {
        switch style {
        case .photos: 3
        case .cards: 24
        default: 18
        }
    }
}
