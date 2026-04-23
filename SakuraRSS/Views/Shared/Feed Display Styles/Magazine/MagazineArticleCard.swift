import SwiftUI

struct MagazineArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipFaviconInset = false
    @State private var isVideoFeed = false
    @State private var isSocialFeed = false
    @State private var shouldCenterImage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    Color.clear
                        .frame(height: 120)
                        .overlay {
                            CachedAsyncImage(url: url, alignment: shouldCenterImage ? .center : .top) {
                                Rectangle()
                                    .fill(.secondary.opacity(0.15))
                            }
                        }
                        .clipped()
                        .clipShape(.rect(cornerRadius: 12))
                } else {
                    magazineFallbackBackground
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
                    .fontWeight(article.isRead ? .regular : .semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(article.isRead ? .secondary : .primary)

                Spacer(minLength: 0)
            }

            if let date = article.publishedDate {
                RelativeTimeText(date: date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
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
                shouldCenterImage = CenteredImageDomains.shouldCenterImage(feedDomain: feed.domain)
                favicon = await FaviconCache.shared.favicon(for: feed)
            }
        }
    }

    private var magazineFallbackBackground: some View {
        FeedIconPlaceholder(
            favicon: favicon,
            acronymIcon: acronymIcon,
            feedName: feedName,
            isSocialFeed: isSocialFeed,
            iconSize: 40,
            cornerRadius: 12,
            fallback: .symbol("doc.text")
        )
        .frame(height: 120)
    }
}
