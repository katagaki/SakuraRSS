import SwiftUI

struct MasonryArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipFaviconInset = false
    @State private var isVideoFeed = false
    @State private var isSocialFeed = false
    @State private var imageAspectRatio: CGFloat?

    /// Caps to keep the column flow predictable while still varying card heights.
    private static let minAspectRatio: CGFloat = 0.55
    private static let maxAspectRatio: CGFloat = 1.6
    private static let fallbackAspectRatio: CGFloat = 1.0

    private var effectiveAspectRatio: CGFloat {
        let ratio = imageAspectRatio ?? Self.fallbackAspectRatio
        return min(max(ratio, Self.minAspectRatio), Self.maxAspectRatio)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    Color.clear
                        .aspectRatio(effectiveAspectRatio, contentMode: .fit)
                        .overlay {
                            CachedAsyncImage(
                                url: url,
                                onImageLoaded: { image in
                                    guard image.size.height > 0 else { return }
                                    imageAspectRatio = image.size.width / image.size.height
                                },
                                placeholder: {
                                    Rectangle()
                                        .fill(.secondary.opacity(0.15))
                                }
                            )
                        }
                        .clipped()
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.quaternary, lineWidth: 0.5)
                        }
                } else {
                    masonryFallbackBackground
                }

                if let favicon = favicon {
                    FaviconImage(favicon, size: 20, cornerRadius: 4,
                                 circle: isVideoFeed, skipInset: skipFaviconInset)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(6)
                } else if let acronymIcon {
                    FaviconImage(acronymIcon, size: 20, cornerRadius: 4,
                                 circle: isVideoFeed, skipInset: true)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(6)
                } else if let feedName {
                    InitialsAvatarView(feedName, size: 20, circle: isVideoFeed, cornerRadius: 4)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(6)
                }
            }

            HStack(spacing: 4) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(feedManager.isRead(article) ? .regular : .semibold)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(feedManager.isRead(article) ? .secondary : .primary)

                Spacer(minLength: 0)
            }

            if let date = article.publishedDate {
                RelativeTimeText(date: date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(.rect)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                feedName = feed.title
                if let data = feed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                isVideoFeed = feed.isVideoFeed || feed.isXFeed || feed.isInstagramFeed
                isSocialFeed = feed.isSocialFeed
                skipFaviconInset = feed.isVideoFeed || feed.isXFeed || feed.isInstagramFeed
                    || FaviconNoInsetDomains.shouldUseFullImage(feedDomain: feed.domain)
                favicon = await FaviconCache.shared.favicon(for: feed)
            }
        }
    }

    private var masonryFallbackBackground: some View {
        FeedIconPlaceholder(
            favicon: favicon,
            acronymIcon: acronymIcon,
            feedName: feedName,
            isSocialFeed: isSocialFeed,
            iconSize: 40,
            cornerRadius: 12,
            fallback: .symbol("doc.text")
        )
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
    }
}
