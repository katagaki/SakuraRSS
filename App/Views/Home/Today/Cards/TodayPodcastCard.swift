import SwiftUI

/// Square podcast artwork card used by the Today "Listen Now" carousel.
struct TodayPodcastCard: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let article: Article
    @State private var icon: UIImage?
    @State private var isSocialFeed = false
    @State private var shouldCenterImage = false

    private let cardSize: CGFloat = 160

    private var feedName: String {
        feedManager.feedsByID[article.feedID]?.title ?? ""
    }

    var body: some View {
        ArticleLink(article: article, label: {
            VStack(alignment: .leading, spacing: 8) {
                cardVisual
                    .frame(width: cardSize, height: cardSize)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .zoomSource(id: article.id, namespace: zoomNamespace)

                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(feedName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: cardSize, alignment: .leading)
            }
        })
        .buttonStyle(.plain)
        .task {
            guard let feed = feedManager.feedsByID[article.feedID] else { return }
            isSocialFeed = feed.isSocialFeed
            shouldCenterImage = CenteredImageDomains.shouldCenterImage(feedDomain: feed.domain)
            icon = await IconCache.shared.icon(for: feed)
        }
    }

    @ViewBuilder
    private var cardVisual: some View {
        if let imageURL = article.imageURL, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url, alignment: shouldCenterImage ? .center : .top) {
                thumbnailBackground
            }
        } else {
            thumbnailBackground
        }
    }

    private var thumbnailBackground: some View {
        FeedIconPlaceholder(
            icon: icon,
            acronymIcon: nil,
            feedName: feedName,
            isSocialFeed: isSocialFeed,
            iconSize: cardSize * 0.5,
            fallback: .symbol("waveform")
        )
    }
}
