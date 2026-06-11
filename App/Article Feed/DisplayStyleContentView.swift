import SwiftUI
import Hanami

struct DisplayStyleContentView: View {

    let style: FeedDisplayStyle
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var onRefresh: (() async -> Void)?
    var headerView: AnyView?
    /// Renders List-based styles as a ScrollView with a LazyVStack instead,
    /// used by the Bookmarks tab so the folder grid and articles share one
    /// plain scroll container. Swipe actions are unavailable in this layout.
    var usesStackLayout: Bool = false

    var body: some View {
        switch style {
        case .inbox:
            InboxStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView,
                           usesStackLayout: usesStackLayout)
        case .feed:
            FeedStyleView(articles: articles, variant: .full,
                          onLoadMore: onLoadMore, headerView: headerView,
                          usesStackLayout: usesStackLayout)
        case .feedCompact:
            FeedStyleView(articles: articles, variant: .compact,
                          onLoadMore: onLoadMore, headerView: headerView,
                          usesStackLayout: usesStackLayout)
        case .magazine:
            MagazineStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .masonry:
            MasonryStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .compact:
            CompactStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView,
                             usesStackLayout: usesStackLayout)
        case .video:
            VideoStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .photos:
            PhotosStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .podcast:
            PodcastStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .timeline:
            TimelineStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView,
                              usesStackLayout: usesStackLayout)
        case .cards:
            CardsStyleView(articles: articles, onRefresh: onRefresh)
        case .grid:
            GridStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .scroll:
            ScrollStyleView(articles: articles, onLoadMore: onLoadMore)
        }
    }
}
