import SwiftUI

struct AddFeedSuggestedTopicsSection: View {

    let topics: [SuggestedTopic]
    let addedURLs: Set<String>
    let onAdd: (SuggestedSite) -> Void

    var body: some View {
        ForEach(topics, id: \.title) { topic in
            Section {
                ForEach(topic.sites, id: \.feedUrl) { site in
                    AddFeedSuggestedSiteRow(
                        site: site,
                        isAdded: addedURLs.contains(site.feedUrl),
                        onAdd: { onAdd(site) }
                    )
                }
            } header: {
                Text(localizedTopicTitle(topic.title))
            }
        }
    }

    private func localizedTopicTitle(_ title: String) -> String {
        switch title {
        case "Headlines": String(localized: "SuggestedFeeds.Topic.Headlines", table: "Feeds")
        case "Technology": String(localized: "SuggestedFeeds.Topic.Technology", table: "Feeds")
        case "Science": String(localized: "SuggestedFeeds.Topic.Science", table: "Feeds")
        case "Economics": String(localized: "SuggestedFeeds.Topic.Economics", table: "Feeds")
        case "Business": String(localized: "SuggestedFeeds.Topic.Business", table: "Feeds")
        case "Sports": String(localized: "SuggestedFeeds.Topic.Sports", table: "Feeds")
        case "Politics": String(localized: "SuggestedFeeds.Topic.Politics", table: "Feeds")
        case "Weather": String(localized: "SuggestedFeeds.Topic.Weather", table: "Feeds")
        default: title
        }
    }
}

private struct AddFeedSuggestedSiteRow: View {

    let site: SuggestedSite
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(site.title)
                    .lineLimit(1)
                Text(site.feedUrl)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
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
}
