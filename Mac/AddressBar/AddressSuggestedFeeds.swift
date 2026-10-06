import Hanami
import SwiftUI

struct AddressSuggestedFeeds: View {

    let feedManager: FeedManager
    @State private var topics = SuggestedFeedsLoader.topicsForCurrentRegion()
    @State private var addingURLs: Set<String> = []

    private var subscribedURLs: Set<String> {
        Set(feedManager.feeds.map(\.url))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Suggestions.SuggestedFeeds", table: "Browser"))
                .font(.headline)
                .padding(.horizontal, 8)
            ForEach(topics, id: \.title) { topic in
                Text(topic.localizedTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 10)
                ForEach(topic.sites, id: \.feedUrl) { site in
                    AddressSuggestedFeedRow(
                        site: site,
                        isAdded: subscribedURLs.contains(site.feedUrl),
                        isAdding: addingURLs.contains(site.feedUrl)
                    ) {
                        add(site)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }

    private func add(_ site: SuggestedSite) {
        guard !addingURLs.contains(site.feedUrl),
              !subscribedURLs.contains(site.feedUrl) else { return }
        addingURLs.insert(site.feedUrl)
        Task {
            defer { addingURLs.remove(site.feedUrl) }
            _ = try? await feedManager.addFeedFetchingMetadata(
                url: site.feedUrl,
                title: site.title,
                siteURL: ""
            )
        }
    }
}
