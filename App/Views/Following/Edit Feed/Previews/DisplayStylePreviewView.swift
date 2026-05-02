import SwiftUI

/// Read-only preview rendering the latest 10 feed items with the feed's display style.
/// Disables hit testing so taps cannot escape into viewers.
struct DisplayStylePreviewView: View {

    @Environment(FeedManager.self) var feedManager
    let feedID: Int64
    let pendingOverride: ContentOverride?

    var feed: Feed? {
        feedManager.feedsByID[feedID]
    }

    var body: some View {
        Group {
            if let feed {
                DisplayStyleContentView(
                    style: resolvedStyle(for: feed),
                    articles: previewArticles(for: feed),
                    onLoadMore: nil,
                    onRefresh: nil
                )
                .disabled(true)
                .allowsHitTesting(false)
            } else {
                Color.clear
            }
        }
        .sakuraBackground()
        .navigationTitle(String(localized: "FeedEdit.Preview.Title", table: "Feeds"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func previewArticles(for feed: Feed) -> [Article] {
        let latest = feedManager.articles(for: feed, limit: 10)
        guard let pendingOverride, pendingOverride.isActive else { return latest }
        return latest.map { ContentOverrideApplier.applying(to: $0, override: pendingOverride) }
    }

    private func resolvedStyle(for feed: Feed) -> FeedDisplayStyle {
        let feedKey = String(feed.id)
        let raw = UserDefaults.standard.string(forKey: "Display.Style.\(feedKey)")
        let defaultRaw = UserDefaults.standard.string(forKey: "Display.DefaultStyle")
            ?? FeedDisplayStyle.inbox.rawValue
        let fallback: FeedDisplayStyle
        if feed.isPodcast {
            fallback = .podcast
        } else if feed.isVideoFeed {
            fallback = .video
        } else if feed.isInstagramFeed {
            fallback = .photos
        } else if let domainStyle = DisplayStyleSetDomains.style(for: feed.domain) {
            fallback = domainStyle
        } else {
            fallback = FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox
        }
        return raw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? fallback
    }
}
