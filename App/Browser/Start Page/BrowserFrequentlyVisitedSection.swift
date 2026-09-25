import EnhancedNavigation
import SwiftUI
import Hanami

struct BrowserFrequentlyVisitedSection: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store

    private var feeds: [Feed] {
        store.frequentlyVisitedFeedIDs.compactMap { feedManager.feedsByID[$0] }
    }

    var body: some View {
        if !feeds.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                BrowserStartPageSectionHeader(
                    title: String(localized: "StartPage.FrequentlyVisited", table: "Browser")
                )
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(feeds) { feed in
                            chip(feed)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    private func chip(_ feed: Feed) -> some View {
        Button {
            store.navigate(to: .feed(feed.id))
        } label: {
            HStack(spacing: 7) {
                FeedIcon(feed: feed, size: 20, cornerRadius: BrowserIconMetrics.cornerRadius(for: 20))
                Text(feed.title)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .compatibleGlassEffect(in: .capsule, interactive: true)
    }
}
