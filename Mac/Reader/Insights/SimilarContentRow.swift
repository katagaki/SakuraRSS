import Hanami
import SwiftUI

struct SimilarContentRow: View {

    let items: [ContentInsights.SimilarContent]
    let onOpen: (Int64) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(items, id: \.article.id) { item in
                    Button { onOpen(item.article.id) } label: {
                        card(for: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func card(for item: ContentInsights.SimilarContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let feed = item.feed {
                    FeedIconView(feed: feed, size: 16)
                }
                Text(item.feedName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(item.article.displayTitle)
                .font(.callout.weight(.semibold))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 220, height: 110, alignment: .topLeading)
        .background(.quinary, in: .rect(cornerRadius: 10))
        .contentShape(.rect(cornerRadius: 10))
    }
}
