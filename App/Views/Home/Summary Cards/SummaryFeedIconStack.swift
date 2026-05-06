import SwiftUI

/// Stack of up to three overlapping feed icons.
struct SummaryFeedIconStack: View {

    @Environment(FeedManager.self) var feedManager
    let feedIDs: [Int64]
    var size: CGFloat = 26

    private static let maxIcons = 3

    private var visibleFeeds: [Feed] {
        var seen = Set<Int64>()
        var ordered: [Feed] = []
        for feedID in feedIDs {
            guard !seen.contains(feedID) else { continue }
            seen.insert(feedID)
            if let feed = feedManager.feedsByID[feedID] {
                ordered.append(feed)
            }
            if ordered.count >= Self.maxIcons { break }
        }
        return ordered
    }

    var body: some View {
        HStack(spacing: -size * 0.35) {
            ForEach(Array(visibleFeeds.enumerated()), id: \.element.id) { index, feed in
                FeedIcon(feed: feed, size: size, cornerRadius: size * 0.2)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.2)
                            .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .zIndex(Double(Self.maxIcons - index))
            }
        }
    }
}
