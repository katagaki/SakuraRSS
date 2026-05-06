import SwiftUI

struct AddFeedDiscoveredSection: View {

    let feeds: [DiscoveredFeed]
    let addedURLs: Set<String>
    let addingURLs: Set<String>
    let subscribedURLs: Set<String>
    let onAdd: (DiscoveredFeed) -> Void

    var body: some View {
        Section {
            ForEach(feeds) { feed in
                AddFeedDiscoveredRow(
                    feed: feed,
                    isAdded: addedURLs.contains(feed.url)
                        || subscribedURLs.contains(feed.url),
                    isAdding: addingURLs.contains(feed.url),
                    onAdd: { onAdd(feed) }
                )
            }
        } header: {
            Text(String(localized: "AddFeed.Section.Discovered", table: "Feeds"))
        }
    }
}

private struct AddFeedDiscoveredRow: View {

    let feed: DiscoveredFeed
    let isAdded: Bool
    let isAdding: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title)
                    .lineLimit(1)
                Text(displayURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else if isAdding {
                ProgressView()
            } else {
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var displayURL: String {
        if XProvider.isFeedURL(feed.url)
            || InstagramProvider.isFeedURL(feed.url)
            || YouTubePlaylistProvider.isFeedURL(feed.url) {
            return feed.siteURL
        }
        return feed.url
    }
}
