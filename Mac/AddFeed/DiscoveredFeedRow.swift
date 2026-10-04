import Hanami
import SwiftUI

struct DiscoveredFeedRow: View {

    let feed: DiscoveredFeed
    let isSubscribed: Bool
    let isAdding: Bool
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title)
                    .lineLimit(1)
                Text(feed.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if isSubscribed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else if isAdding {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(String(localized: "FeedRules.Add", table: "Feeds"), action: onAdd)
                    .disabled(!canAdd)
            }
        }
        .padding(.vertical, 4)
    }
}
