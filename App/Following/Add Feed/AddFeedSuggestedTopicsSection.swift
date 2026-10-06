import SwiftUI
import Hanami

struct AddFeedSuggestedTopicsSection: View {

    let topics: [SuggestedTopic]
    let addedURLs: Set<String>
    let addingURLs: Set<String>
    let subscribedURLs: Set<String>
    let onAdd: (SuggestedSite) -> Void

    var body: some View {
        ForEach(topics, id: \.title) { topic in
            Section {
                ForEach(topic.sites, id: \.feedUrl) { site in
                    AddFeedSuggestedSiteRow(
                        site: site,
                        isAdded: addedURLs.contains(site.feedUrl)
                            || subscribedURLs.contains(site.feedUrl),
                        isAdding: addingURLs.contains(site.feedUrl),
                        onAdd: { onAdd(site) }
                    )
                }
            } header: {
                Text(topic.localizedTitle)
            }
        }
    }
}

private struct AddFeedSuggestedSiteRow: View {

    let site: SuggestedSite
    let isAdded: Bool
    let isAdding: Bool
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
}
