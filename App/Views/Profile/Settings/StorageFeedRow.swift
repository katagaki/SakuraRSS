import SwiftUI

struct StorageFeedRow: View {

    let feed: Feed
    let bytes: Int64

    var body: some View {
        HStack(spacing: 12) {
            FeedIcon(feed: feed, size: 28, cornerRadius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title)
                    .font(.body)
                    .lineLimit(1)
                if !feed.domain.isEmpty {
                    Text(feed.domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
