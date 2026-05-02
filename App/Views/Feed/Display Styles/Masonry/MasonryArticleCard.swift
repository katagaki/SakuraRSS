import SwiftUI

struct MasonryArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var icon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipIconInset = false
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
                                .strokeBorder(.primary.opacity(0.5), lineWidth: 0.5)
                        }
                } else {
                    masonryFallbackBackground
                }

                if let icon = icon {
                    IconImage(icon, size: 20, cornerRadius: 4,
                                 circle: isVideoFeed, skipInset: skipIconInset)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(6)
                } else if let acronymIcon {
                    IconImage(acronymIcon, size: 20, cornerRadius: 4,
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
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(feedManager.isRead(article) ? .secondary : .primary)

                Spacer(minLength: 0)
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
                skipIconInset = feed.isVideoFeed || feed.isXFeed || feed.isInstagramFeed
                icon = await IconCache.shared.icon(for: feed)
            }
        }
    }

    private var masonryFallbackBackground: some View {
        FeedIconPlaceholder(
            icon: icon,
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
