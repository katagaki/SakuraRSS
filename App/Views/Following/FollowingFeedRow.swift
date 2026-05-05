import SwiftUI

struct FollowingFeedRow: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed
    var showsDomain: Bool = true

    private var iconSize: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 28
        #else
        return 32
        #endif
    }

    var body: some View {
        HStack(spacing: 12) {
            FeedIcon(feed: feed, size: iconSize, showsRefreshProgress: true)

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
    }
}
