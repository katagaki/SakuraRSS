import SwiftUI
import Hanami

struct BrowserOmniboxSuggestedFeeds: View {

    @Environment(FeedManager.self) private var feedManager
    @State private var topics: [SuggestedTopic] = []
    @State private var addingURLs: Set<String> = []

    private var subscribedURLs: Set<String> {
        Set(feedManager.feeds.map(\.url))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Suggestions.SuggestedFeeds", table: "Browser"))
                .font(.title3.bold())
                .padding(.horizontal, 20)
                .padding(.top, 16)
            ForEach(topics, id: \.title) { topic in
                Text(topic.localizedTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
                ForEach(topic.sites, id: \.feedUrl) { site in
                    BrowserSuggestedFeedRow(
                        site: site,
                        isAdded: subscribedURLs.contains(site.feedUrl),
                        isAdding: addingURLs.contains(site.feedUrl)
                    ) {
                        add(site)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 12)
        .onAppear {
            if topics.isEmpty {
                topics = SuggestedFeedsLoader.topicsForCurrentRegion()
            }
        }
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
