import SwiftUI

struct DiscoverArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.zoomNamespace) private var zoomNamespace
    let article: Article
    @State private var favicon: UIImage?
    @State private var shouldCenterImage = false

    private let cardWidth: CGFloat = 200
    private let imageHeight: CGFloat = 112

    private var feedName: String {
        feedManager.feedsByID[article.feedID]?.title ?? ""
    }

    var body: some View {
        ArticleLink(article: article, label: {
            VStack(alignment: .leading, spacing: 8) {
                cardVisual
                    .frame(width: cardWidth, height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.quaternary, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .zoomSource(id: article.id, namespace: zoomNamespace)

                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Text(feedName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: cardWidth, alignment: .leading)
            }
        })
        .buttonStyle(.plain)
        .task {
            guard let feed = feedManager.feedsByID[article.feedID] else { return }
            shouldCenterImage = CenteredImageDomains.shouldCenterImage(feedDomain: feed.domain)
            favicon = await FaviconCache.shared.favicon(for: feed)
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

    @ViewBuilder
    private var thumbnailBackground: some View {
        let isDark = colorScheme == .dark
        let bgColor = favicon?.cardBackgroundColor(isDarkMode: isDark)
            ?? (isDark ? Color(white: 0.15) : Color(white: 0.9))

        ZStack {
            Rectangle()
                .fill(bgColor)

            if let favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageHeight * 0.5, height: imageHeight * 0.5)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: imageHeight * 0.35, weight: .light))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
