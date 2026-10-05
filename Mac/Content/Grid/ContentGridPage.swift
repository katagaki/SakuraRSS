import Hanami
import SwiftUI

/// The grid styles, which fill the page instead of sitting beside the reader;
/// content opens full width, as it does from Today.
struct ContentGridPage: View {

    let location: BrowserLocation
    let style: FeedDisplayStyle
    let feedManager: FeedManager
    let actions: TodayActions
    @State private var articles: [Article] = []

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
        .task(id: "\(location.persistenceToken)|\(feedManager.dataRevision)") {
            articles = ContentQuery(feedManager: feedManager).articles(for: location)
        }
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: spacing)], spacing: spacing) {
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
