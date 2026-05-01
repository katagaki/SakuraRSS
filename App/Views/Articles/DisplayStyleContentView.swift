import SwiftUI

struct DisplayStyleContentView: View {

    let style: FeedDisplayStyle
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var onRefresh: (() async -> Void)?
    var headerView: AnyView?

    var body: some View {
        switch style {
        case .inbox:
            InboxStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .feed:
            FeedStyleView(articles: articles, variant: .full,
                          onLoadMore: onLoadMore, headerView: headerView)
        case .feedCompact:
            FeedStyleView(articles: articles, variant: .compact,
                          onLoadMore: onLoadMore, headerView: headerView)
        case .magazine:
            MagazineStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .compact:
            CompactStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .video:
            VideoStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .photos:
            PhotosStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .podcast:
            PodcastStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .timeline:
            TimelineStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .cards:
            CardsStyleView(articles: articles, onRefresh: onRefresh)
        case .grid:
            GridStyleView(articles: articles, onLoadMore: onLoadMore, headerView: headerView)
        case .scroll:
            ScrollStyleView(articles: articles, onLoadMore: onLoadMore)
        }
    }
}
