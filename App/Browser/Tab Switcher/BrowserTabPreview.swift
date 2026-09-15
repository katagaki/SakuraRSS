import SwiftUI
import Hanami

/// The tab's last snapshot. Tabs that have not been left yet have none, so
/// they fall back to a stand-in: the headlines the tab would show, or its
/// label when it is not a list of content.
struct BrowserTabPreview: View {

    private static let headlineLimit = 4

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserFavourites.self) private var favourites
    let tab: BrowserTab

    var body: some View {
        if let snapshot = store.snapshots[tab.id] {
            // Matched to the card's width with the overflow falling off the
            // bottom. Filling would scale by height instead and crop the sides,
            // because cropping the navigation bar leaves the snapshot shorter
            // in ratio than the screen.
            GeometryReader { proxy in
                Image(uiImage: snapshot)
                    .resizable()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.width / snapshotAspectRatio(snapshot)
                    )
            }
        } else {
            standIn
                .padding(12)
        }
    }

    private func snapshotAspectRatio(_ snapshot: UIImage) -> CGFloat {
        guard snapshot.size.height > 0 else { return 1 }
        return snapshot.size.width / snapshot.size.height
    }

    @ViewBuilder
    private var standIn: some View {
        // Navigating pushes rather than replacing the root, so the tab's
        // location is no longer what it is showing: prefer the page it last
        // reported.
        if let feedID = tab.pageIdentity?.feedID, let feed = feedManager.feedsByID[feedID] {
            headlines(feedManager.articles(for: feed, limit: BrowserTabPreview.headlineLimit))
        } else {
            rootPreview
        }
    }

    @ViewBuilder
    private var rootPreview: some View {
        switch tab.location {
        case .startPage:
            favouriteIcons
        case .feed(let feedID):
            headlines(feedManager.feedsByID[feedID].map {
                feedManager.articles(for: $0, limit: BrowserTabPreview.headlineLimit)
            } ?? [])
        case .list(let listID):
            headlines(feedManager.lists.first { $0.id == listID }.map {
                feedManager.articles(for: $0, limit: BrowserTabPreview.headlineLimit)
            } ?? [])
        case .allContent:
            headlines(feedManager.articles(limit: BrowserTabPreview.headlineLimit))
        case .search:
            symbolPlaceholder
        }
    }

    private var favouriteIcons: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(favourites.resolvedFeeds(feedManager: feedManager).prefix(8)) { feed in
                FeedIcon(feed: feed, size: 26, cornerRadius: BrowserIconMetrics.cornerRadius(for: 26))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func headlines(_ articles: [Article]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if articles.isEmpty {
                symbolPlaceholder
            } else {
                ForEach(articles) { article in
                    Text(article.title)
                        .font(.caption2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var symbolPlaceholder: some View {
        Image(systemName: BrowserLocationDescription.describe(tab, feedManager: feedManager).symbolName)
            .font(.system(size: 28))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
