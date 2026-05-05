import SwiftUI

struct FeedIcon: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed
    var size: CGFloat = 32
    var cornerRadius: CGFloat = 4
    var showsRefreshProgress: Bool = false
    @State private var icon: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let icon {
                IconImage(
                    icon,
                    size: size,
                    cornerRadius: cornerRadius,
                    circle: feed.isCircleIcon,
                    skipInset: feed.isCircleIcon || feed.isXFeed || feed.isInstagramFeed
                )
            } else if let data = feed.acronymIcon, let acronym = UIImage(data: data) {
                IconImage(
                    acronym,
                    size: size,
                    cornerRadius: cornerRadius,
                    circle: feed.isCircleIcon,
                    skipInset: true
                )
            } else {
                InitialsAvatarView(
                    feed.title,
                    size: size,
                    circle: feed.isCircleIcon,
                    cornerRadius: cornerRadius
                )
            }

            if showsRefreshProgress,
               let cooldown = RefreshTimeoutDomains.refreshTimeout(
                   for: feed.domain, jittered: false
               ) {
                IconProgressBadge(
                    lastFetched: feed.lastFetched,
                    cooldown: cooldown,
                    size: size,
                    isCircle: feed.isCircleIcon,
                    cornerRadius: cornerRadius
                )
            }
        }
        .frame(width: size, height: size)
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
