import SwiftUI

struct DisplayStyleContentView: View {

    let style: FeedDisplayStyle
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var onRefresh: (() async -> Void)?

    var body: some View {
        switch style {
        case .inbox:
            InboxStyleView(articles: articles, onLoadMore: onLoadMore)
        case .feed:
            FeedStyleView(articles: articles, variant: .full, onLoadMore: onLoadMore)
        case .feedCompact:
            FeedStyleView(articles: articles, variant: .compact, onLoadMore: onLoadMore)
        case .magazine:
            MagazineStyleView(articles: articles, onLoadMore: onLoadMore)
        case .compact:
            CompactStyleView(articles: articles, onLoadMore: onLoadMore)
        case .video:
            VideoStyleView(articles: articles, onLoadMore: onLoadMore)
        case .photos:
            PhotosStyleView(articles: articles, onLoadMore: onLoadMore)
        case .podcast:
            PodcastStyleView(articles: articles, onLoadMore: onLoadMore)
        case .timeline:
            TimelineStyleView(articles: articles, onLoadMore: onLoadMore)
        case .cards:
            CardsStyleView(articles: articles, onRefresh: onRefresh)
        case .grid:
            GridStyleView(articles: articles, onLoadMore: onLoadMore)
        case .scroll:
            ScrollStyleView(articles: articles, onLoadMore: onLoadMore)
        }
    }
}
