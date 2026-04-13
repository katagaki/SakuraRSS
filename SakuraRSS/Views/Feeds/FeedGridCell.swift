import SwiftUI

struct FeedGridCell: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed
    @State private var favicon: UIImage?

    private let iconSize: CGFloat = 48

    private var iconCornerRadius: CGFloat {
        if feed.isPodcast { return 12 }
        return 8
    }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .frame(width: iconSize, height: iconSize)

                ZStack(alignment: .bottomTrailing) {
                    if let favicon = favicon {
                        FaviconImage(favicon, size: iconSize,
                                     cornerRadius: iconCornerRadius,
                                     circle: feed.isCircleIcon,
                                     skipInset: feed.isCircleIcon || feed.isXFeed || feed.isInstagramFeed
                                        || FaviconNoInsetDomains.shouldUseFullImage(feedDomain: feed.domain))
                    } else if let data = feed.acronymIcon, let acronym = UIImage(data: data) {
                        FaviconImage(acronym, size: iconSize,
                                     cornerRadius: iconCornerRadius,
                                     circle: feed.isCircleIcon,
                                     skipInset: true)
                    } else {
                        InitialsAvatarView(
                            feed.title,
                            size: iconSize,
                            circle: feed.isCircleIcon,
                            cornerRadius: iconCornerRadius
                        )
                    }

                    if feed.isXFeed {
                        FaviconProgressBadge(
                            lastFetched: feed.lastFetched,
                            cooldown: FeedManager.xRefreshInterval,
                            size: 15
                        )
                        .offset(x: 3, y: 3)
                    } else if feed.isInstagramFeed {
                        FaviconProgressBadge(
                            lastFetched: feed.lastFetched,
                            cooldown: FeedManager.instagramRefreshInterval,
                            size: 15
                        )
                        .offset(x: 3, y: 3)
                    }
                }
                .frame(width: iconSize, height: iconSize)

            }

            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    if feedManager.unreadCount(for: feed) > 0 {
                        Circle()
                            .fill(.blue)
                            .frame(width: 6, height: 6)
                    }
                    Text(feed.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if feed.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(feed.domain.hasPrefix("www.") ? String(feed.domain.dropFirst(4)) : feed.domain)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity)
        .task {
            favicon = await loadFavicon()
        }
        .onChange(of: feedManager.faviconRevision) {
            Task {
                favicon = await loadFavicon()
            }
        }
    }

    private func loadFavicon() async -> UIImage? {
        await FaviconCache.shared.favicon(for: feed)
    }
}
