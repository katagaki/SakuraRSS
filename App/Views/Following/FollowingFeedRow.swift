import SwiftUI

struct FollowingFeedRow: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed
    var showsDomain: Bool = true
    @State private var icon: UIImage?

    private var iconCornerRadius: CGFloat { 4 }
    private var iconSize: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 28
        #else
        return 32
        #endif
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let icon = icon {
                    IconImage(
                        icon,
                        size: iconSize,
                        cornerRadius: iconCornerRadius,
                        circle: feed.isCircleIcon,
                        skipInset: feed.isCircleIcon || feed.isXFeed || feed.isInstagramFeed
                    )
                } else if let data = feed.acronymIcon, let acronym = UIImage(data: data) {
                    IconImage(
                        acronym,
                        size: iconSize,
                        cornerRadius: iconCornerRadius,
                        circle: feed.isCircleIcon,
                        skipInset: true
                    )
                } else {
                    InitialsAvatarView(
                        feed.title,
                        size: iconSize,
                        circle: feed.isCircleIcon,
                        cornerRadius: iconCornerRadius
                    )
                }

                if let cooldown = RefreshTimeoutDomains.refreshTimeout(
                    for: feed.domain, jittered: false
                ) {
                    IconProgressBadge(
                        lastFetched: feed.lastFetched,
                        cooldown: cooldown,
                        size: iconSize,
                        isCircle: feed.isCircleIcon,
                        cornerRadius: iconCornerRadius
                    )
                }
            }
            .frame(width: iconSize, height: iconSize)

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
                if showsDomain {
                    Text(feed.domain.hasPrefix("www.") ? String(feed.domain.dropFirst(4)) : feed.domain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
            icon = await loadIcon()
        }
        .onChange(of: feedManager.iconRevision) {
            Task {
                icon = await loadIcon()
            }
        }
    }

    private func loadIcon() async -> UIImage? {
        let currentFeed = feedManager.feedsByID[feed.id] ?? feed
        return await IconCache.shared.icon(for: currentFeed)
    }
}
