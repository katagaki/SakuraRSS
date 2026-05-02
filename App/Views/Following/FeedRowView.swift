import SwiftUI

struct FeedRowView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed
    @State private var favicon: UIImage?

    private var iconCornerRadius: CGFloat { 4 }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let favicon = favicon {
                    FaviconImage(
                        favicon,
                        size: 32,
                        cornerRadius: iconCornerRadius,
                        circle: feed.isCircleIcon,
                        skipInset: feed.isCircleIcon || feed.isXFeed || feed.isInstagramFeed
                        || FaviconNoInsetDomains.shouldUseFullImage(feedDomain: feed.domain)
                    )
                } else if let data = feed.acronymIcon, let acronym = UIImage(data: data) {
                    FaviconImage(
                        acronym,
                        size: 32,
                        cornerRadius: iconCornerRadius,
                        circle: feed.isCircleIcon,
                        skipInset: true
                    )
                } else {
                    InitialsAvatarView(
                        feed.title,
                        size: 32,
                        circle: feed.isCircleIcon,
                        cornerRadius: iconCornerRadius
                    )
                }

                if let cooldown = RefreshTimeoutDomains.refreshTimeout(
                    for: feed.domain, jittered: false
                ) {
                    FaviconProgressBadge(
                        lastFetched: feed.lastFetched,
                        cooldown: cooldown,
                        size: 32,
                        isCircle: feed.isCircleIcon,
                        cornerRadius: iconCornerRadius
                    )
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(feed.title)
                        .font(.body)
                        .lineLimit(1)
                    if feed.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(feed.domain.hasPrefix("www.") ? String(feed.domain.dropFirst(4)) : feed.domain)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            let count = feedManager.unreadCount(for: feed)
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.tertiary)
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
        }
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
        let currentFeed = feedManager.feedsByID[feed.id] ?? feed
        return await FaviconCache.shared.favicon(for: currentFeed)
    }
}
